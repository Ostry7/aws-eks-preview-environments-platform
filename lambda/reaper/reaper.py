import base64, json, os, re, ssl, urllib.request, urllib.parse
from datetime import datetime, timezone, timedelta

import boto3
from botocore.signers import RequestSigner

CLUSTER = os.environ["CLUSTER_NAME"]
REGION = os.environ["REGION"]
TTL = timedelta(hours=int(os.environ.get("TTL_HOURS", "24")))
DRY_RUN = os.environ.get("DRY_RUN", "true").lower() == "true"
NS_RE = re.compile(r"^pr-[a-z0-9-]+$")


def eks_token():
    session = boto3.session.Session()
    sts = session.client("sts", region_name=REGION)
    signer = RequestSigner(sts.meta.service_model.service_id, REGION, "sts",
                           "v4", session.get_credentials(), session.events)
    url = signer.generate_presigned_url(
        {"method": "GET",
         "url": f"https://sts.{REGION}.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15",
         "body": {}, "headers": {"x-k8s-aws-id": CLUSTER}, "context": {}},
        region_name=REGION, expires_in=60, operation_name="")
    return "k8s-aws-v1." + base64.urlsafe_b64encode(url.encode()).decode().rstrip("=")


def setup():
    c = boto3.client("eks", region_name=REGION).describe_cluster(name=CLUSTER)["cluster"]
    with open("/tmp/ca.crt", "wb") as f:
        f.write(base64.b64decode(c["certificateAuthority"]["data"]))
    ctx = ssl.create_default_context(cafile="/tmp/ca.crt")
    return c["endpoint"], eks_token(), ctx


def k8s(endpoint, token, ctx, method, path):
    req = urllib.request.Request(endpoint + path, method=method,
                                 headers={"Authorization": f"Bearer {token}",
                                          "Accept": "application/json"})
    with urllib.request.urlopen(req, context=ctx, timeout=20) as r:
        return json.loads(r.read() or "{}")


def handler(event, context):
    endpoint, token, ctx = setup()
    now = datetime.now(timezone.utc)
    reaped = []

    for ns in k8s(endpoint, token, ctx, "GET", "/api/v1/namespaces")["items"]:
        name = ns["metadata"]["name"]
        if not NS_RE.match(name):
            continue
        created = datetime.fromisoformat(ns["metadata"]["creationTimestamp"].replace("Z", "+00:00"))
        if now - created < TTL:
            continue
        print(f"{'DRY-RUN ' if DRY_RUN else ''}reaping {name} (age {now - created})")
        reaped.append(name)
        if DRY_RUN:
            continue
   
        k8s(endpoint, token, ctx, "DELETE", f"/api/v1/namespaces/{name}")
        sel = urllib.parse.quote(f"owner=helm,name=app-{name}")
        k8s(endpoint, token, ctx, "DELETE",
            f"/api/v1/namespaces/default/secrets?labelSelector={sel}")

    return {"dry_run": DRY_RUN, "reaped": reaped}
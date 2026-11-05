import base64
import os
import boto3
from botocore.signers import RequestSigner
from kubernetes import client

CLUSTER = os.environ["CLUSTER_NAME"]
REGION = os.environ.get("AWS_REGION", "eu-central-1")


def get_token(cluster_name, region):
    session = boto3.session.Session()
    sts = session.client("sts", region_name=region)
    signer = RequestSigner(
        sts.meta.service_model.service_id,
        region, "sts", "v4",
        session.get_credentials(),
        session.events,
    )
    params = {
        "method": "GET",
        "url": f"https://sts.{region}.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15",
        "body": {},
        "headers": {"x-k8s-aws-id": cluster_name},
        "context": {},
    }
    url = signer.generate_presigned_url(
        params, region_name=region, expires_in=60, operation_name=""
    )
    return "k8s-aws-v1." + base64.urlsafe_b64encode(url.encode()).decode().rstrip("=")


def get_api_client(cluster_name, region):
    eks = boto3.client("eks", region_name=region)
    cluster = eks.describe_cluster(name=cluster_name)["cluster"]

    ca_path = "/tmp/ca.crt"
    with open(ca_path, "wb") as f:
        f.write(base64.b64decode(cluster["certificateAuthority"]["data"]))

    cfg = client.Configuration()
    cfg.host = cluster["endpoint"]
    cfg.ssl_ca_cert = ca_path
    cfg.api_key = {"authorization": "Bearer " + get_token(cluster_name, region)}
    return client.ApiClient(cfg)


def lambda_handler(event, context):
    v1 = client.CoreV1Api(get_api_client(CLUSTER, REGION))
    for p in v1.list_pod_for_all_namespaces().items:
        print(p.status.pod_ip, p.metadata.namespace, p.metadata.name)
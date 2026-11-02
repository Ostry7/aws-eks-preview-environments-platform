terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

resource "helm_release" "argocd" {
  name = "argocd"  
  repository = "https://argoproj.github.io/argo-helm"
  chart = "argo-cd"
  version = "10.9.6"
  namespace = "argocd"
  create_namespace = true

  values = [ 
    file("${path.module}/values/argocd.yaml")
   ]
}

resource "kubernetes_secret_v1" "github_token" {
  metadata {
    name      = "github-token"
    namespace = "argocd"
  }
  data = {
    token = var.github_pat
  }
  depends_on = [helm_release.argocd]
}
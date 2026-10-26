terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
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
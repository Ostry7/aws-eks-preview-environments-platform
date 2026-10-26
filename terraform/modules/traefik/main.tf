terraform {
  required_providers {
    helm = {
      source                = "hashicorp/helm"
      configuration_aliases = [helm]
    }
  }
}


# Install Traefik using Helm
resource "helm_release" "traefik" {
    name = "traefik"
    namespace = "traefik"
    create_namespace = true
    repository = "https://traefik.github.io/charts"
    chart = "traefik"
    version = "42.1.3"

    values = [yamlencode({
      deployment = { replicas = 1 }

      ingressClass = {
        enabled        = true
        isDefaultClass = true
        name           = "traefik"
      }

      providers = {
        kubernetesIngress = {
          publishedService = { enabled = true }
        }
      }

      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-subnets"                           = var.public_subnet_id
          "service.beta.kubernetes.io/aws-load-balancer-eip-allocations"                   = var.eip_allocation_id
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
        }
      }

      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "200m", memory = "128Mi" }
      }
    })]
}
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.5.0"
    }
  }
}

# Solo el clúster de este entorno: nunca el contexto actual del usuario.
provider "kubernetes" {
  config_path = "${path.module}/../../.local/kubeconfig"
}

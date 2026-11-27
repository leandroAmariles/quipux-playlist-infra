# Opcional: Argo CD despliega la rama main de GitHub en lugar de los manifiestos locales.

locals {
  argocd_manifest = "https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.9/manifests/install.yaml"
}

resource "terraform_data" "argocd" {
  count = local.config.argocd_enabled ? 1 : 0

  # Al destruir solo se puede leer el propio recurso: la dirección del manifiesto queda guardada en él.
  input            = local.argocd_manifest
  triggers_replace = [var.cluster_instance, local.argocd_manifest]

  provisioner "local-exec" {
    command     = "kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -"
    working_dir = local.repository_dir
    environment = local.kubectl_env
  }

  provisioner "local-exec" {
    command     = "kubectl apply -n argocd --server-side --force-conflicts -f ${local.argocd_manifest}"
    working_dir = local.repository_dir
    environment = local.kubectl_env
  }

  provisioner "local-exec" {
    command     = "kubectl -n argocd rollout status deployment/argocd-server --timeout=300s"
    working_dir = local.repository_dir
    environment = local.kubectl_env
  }

  # La Application se borra primero y no tiene finalizador: lo desplegado permanece.
  provisioner "local-exec" {
    when        = destroy
    command     = "kubectl -n argocd delete application quipux-playlist --ignore-not-found"
    working_dir = "${path.module}/../.."
    environment = { KUBECONFIG = ".local/kubeconfig" }
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "kubectl delete -n argocd --ignore-not-found -f ${self.input}"
    working_dir = "${path.module}/../.."
    environment = { KUBECONFIG = ".local/kubeconfig" }
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "kubectl delete namespace argocd --ignore-not-found"
    working_dir = "${path.module}/../.."
    environment = { KUBECONFIG = ".local/kubeconfig" }
  }
}

resource "terraform_data" "argocd_application" {
  count = local.config.argocd_enabled ? 1 : 0

  triggers_replace = [terraform_data.argocd[0].id, filesha256("${path.module}/../../argocd/application.yaml")]

  provisioner "local-exec" {
    command     = "kubectl apply -f argocd/application.yaml"
    working_dir = local.repository_dir
    environment = local.kubectl_env
  }

  depends_on = [kubernetes_secret_v1.playlist]
}

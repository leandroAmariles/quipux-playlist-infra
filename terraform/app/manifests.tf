# El Deployment lee el Secret al arrancar: si cambia, se elimina el pod para que se cree de nuevo. No modifica el
# manifiesto que compara Argo CD.
resource "terraform_data" "api_reload" {
  triggers_replace = [var.cluster_instance, nonsensitive(sha256(jsonencode(local.secret_data)))]

  provisioner "local-exec" {
    command     = "kubectl -n ${local.namespace} delete pod -l app.kubernetes.io/name=api --ignore-not-found"
    working_dir = local.repository_dir
    environment = local.kubectl_env
  }

  depends_on = [kubernetes_secret_v1.playlist]
}

# Manifiestos locales, incluidos los cambios sin fusionar. No elimina los recursos retirados de k8s/.
# Con Argo CD no se aplican. La dependencia hace que, al desactivarlo, se desinstale antes de aplicar lo local.
resource "terraform_data" "manifests" {
  count = local.config.argocd_enabled ? 0 : 1

  triggers_replace = [
    var.cluster_instance,
    sha256(join("\n", [
      for file in sort(fileset("${path.module}/../../k8s", "**")) :
      "${file} ${filesha256("${path.module}/../../k8s/${file}")}"
    ])),
  ]

  provisioner "local-exec" {
    command     = "kubectl apply -k k8s"
    working_dir = local.repository_dir
    environment = local.kubectl_env
  }

  depends_on = [terraform_data.api_reload, terraform_data.argocd]
}

moved {
  from = terraform_data.manifests
  to   = terraform_data.manifests[0]
}

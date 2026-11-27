data "terraform_remote_state" "config" {
  backend = "local"

  config = {
    path = "${path.module}/../config/terraform.tfstate"
  }
}

locals {
  config    = data.terraform_remote_state.config.outputs
  namespace = "quipux-playlist"

  # Los comandos de local-exec se ejecutan desde la raíz del repositorio: así no hay que citar rutas con espacios.
  repository_dir = "${path.module}/../.."
  kubectl_env    = { KUBECONFIG = ".local/kubeconfig" }

  base_secret_data = {
    JWT_SECRET            = local.config.jwt_secret
    DEMO_USER_PASSWORD    = local.config.demo_user_password
    DEMO_ADMIN_PASSWORD   = local.config.demo_admin_password
    SPOTIFY_CLIENT_ID     = local.config.spotify_client_id
    SPOTIFY_CLIENT_SECRET = local.config.spotify_client_secret
  }

  # La conexión con la IA va en el Secret, y no en el ConfigMap, para que Argo CD no la revierta. Los nombres son los
  # alias de compose/compose.cluster.yaml en la red de kind.
  ai_secret_data = {
    AI_PROVIDER         = "openai"
    AI_BASE_URL         = "http://quipux-litellm:4000/v1"
    AI_API_KEY          = local.config.ai_api_key
    AI_TIMEOUT          = local.config.ai_timeout
    CATALOG_DB_URL      = "jdbc:postgresql://quipux-catalog-db:5432/catalog"
    CATALOG_DB_PASSWORD = local.config.catalog_db_password
  }

  secret_data = merge(
    local.base_secret_data,
    { for key, value in local.ai_secret_data : key => value if local.config.ai_enabled },
  )
}

resource "terraform_data" "namespace" {
  triggers_replace = [var.cluster_instance, filesha256("${path.module}/../../k8s/namespace.yaml")]

  provisioner "local-exec" {
    command     = "kubectl apply -f k8s/namespace.yaml"
    working_dir = local.repository_dir
    environment = local.kubectl_env
  }
}

# Fuera de kustomization.yaml: Argo CD no lo gestiona ni lo revierte.
resource "kubernetes_secret_v1" "playlist" {
  metadata {
    name      = "playlist-secrets"
    namespace = local.namespace
  }

  type = "Opaque"
  data = local.secret_data

  depends_on = [terraform_data.namespace]
}

# Acceso desde el equipo: los NodePort que kind publica en 127.0.0.1. Los Service de k8s/ siguen siendo ClusterIP.
resource "kubernetes_service_v1" "web_local" {
  metadata {
    name      = "web-local"
    namespace = local.namespace
  }

  spec {
    type     = "NodePort"
    selector = { "app.kubernetes.io/name" = "web" }

    port {
      name        = "http"
      port        = 8080
      target_port = "http"
      node_port   = 30080
    }
  }

  depends_on = [terraform_data.namespace]
}

resource "kubernetes_service_v1" "api_local" {
  metadata {
    name      = "api-local"
    namespace = local.namespace
  }

  spec {
    type     = "NodePort"
    selector = { "app.kubernetes.io/name" = "api" }

    port {
      name        = "http"
      port        = 8080
      target_port = "http"
      node_port   = 30081
    }
  }

  depends_on = [terraform_data.namespace]
}

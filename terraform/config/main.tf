# Secretos del entorno. Esta raíz sobrevive a `make down`: PostgreSQL solo toma la contraseña al crear su volumen.

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "random_password" "demo_user" {
  length  = 20
  special = false
}

resource "random_password" "demo_admin" {
  length  = 20
  special = false
}

# 64 caracteres hexadecimales. random_id no sirve: su identificador, visible en la salida, revela el valor.
resource "random_password" "ai_api_key" {
  length           = 64
  lower            = false
  upper            = false
  numeric          = false
  special          = true
  override_special = "0123456789abcdef"
}

resource "random_password" "catalog_db" {
  length  = 32
  special = false
}

locals {
  jwt_secret          = coalesce(var.jwt_secret, random_password.jwt_secret.result)
  demo_user_password  = coalesce(var.demo_user_password, random_password.demo_user.result)
  demo_admin_password = coalesce(var.demo_admin_password, random_password.demo_admin.result)
  ai_api_key          = coalesce(var.ai_api_key, "sk-${random_password.ai_api_key.result}")
  catalog_db_password = coalesce(var.catalog_db_password, random_password.catalog_db.result)

  # La indexación del catálogo usa la misma versión del backend que despliega Kubernetes.
  backend_image = "ghcr.io/leandroamariles/quipux-playlist-backend"
  backend_tag = one([
    for image in yamldecode(file("${path.module}/../../k8s/kustomization.yaml")).images :
    image.newTag if image.name == local.backend_image
  ])
}

resource "local_sensitive_file" "compose_env" {
  filename        = "${path.module}/../../.local/compose.env"
  file_permission = "0600"
  content         = <<-EOT
    AI_API_KEY=${local.ai_api_key}
    CATALOG_DB_PASSWORD=${local.catalog_db_password}
    OLLAMA_CHAT_MODEL=${var.ollama_chat_model}
    OLLAMA_EMBEDDING_MODEL=${var.ollama_embedding_model}
    BACKEND_TAG=${local.backend_tag}
  EOT

  lifecycle {
    precondition {
      condition     = var.web_port != var.api_port
      error_message = "web_port y api_port deben ser distintos."
    }
  }
}

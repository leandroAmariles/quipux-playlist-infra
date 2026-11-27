output "ai_enabled" {
  value = var.ai_enabled
}

output "gpu" {
  value = var.gpu
}

output "argocd_enabled" {
  value = var.argocd_enabled
}

output "web_port" {
  value = var.web_port
}

output "api_port" {
  value = var.api_port
}

output "ai_timeout" {
  value = var.ai_timeout
}

output "ollama_chat_model" {
  value = var.ollama_chat_model
}

output "ollama_embedding_model" {
  value = var.ollama_embedding_model
}

output "backend_tag" {
  value = local.backend_tag
}

output "jwt_secret" {
  value     = local.jwt_secret
  sensitive = true
}

output "demo_user_password" {
  value     = local.demo_user_password
  sensitive = true
}

output "demo_admin_password" {
  value     = local.demo_admin_password
  sensitive = true
}

output "ai_api_key" {
  value     = local.ai_api_key
  sensitive = true
}

output "catalog_db_password" {
  value     = local.catalog_db_password
  sensitive = true
}

output "spotify_client_id" {
  value     = var.spotify_client_id
  sensitive = true
}

output "spotify_client_secret" {
  value     = var.spotify_client_secret
  sensitive = true
}

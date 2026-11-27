output "web_url" {
  value = "http://localhost:${local.config.web_port}"
}

output "api_url" {
  value = "http://localhost:${local.config.api_port}"
}

output "swagger_url" {
  value = "http://localhost:${local.config.api_port}/swagger-ui.html"
}

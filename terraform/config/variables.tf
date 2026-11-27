# Interruptores y puertos.

variable "ai_enabled" {
  description = "IA en Docker y su conexión con la API."
  type        = bool
  default     = true
  nullable    = false
}

variable "gpu" {
  description = "Uso de GPU NVIDIA: auto, on u off."
  type        = string
  default     = "auto"
  nullable    = false

  validation {
    condition     = contains(["auto", "on", "off"], var.gpu)
    error_message = "gpu debe ser \"auto\", \"on\" u \"off\"."
  }
}

variable "argocd_enabled" {
  description = "Desplegar la rama main de GitHub con Argo CD en lugar de los manifiestos locales."
  type        = bool
  default     = false
  nullable    = false
}

variable "web_port" {
  description = "Puerto de la web en 127.0.0.1."
  type        = number
  default     = 4200
  nullable    = false

  validation {
    condition     = var.web_port >= 1 && var.web_port <= 65535 && floor(var.web_port) == var.web_port
    error_message = "web_port debe ser un puerto entre 1 y 65535."
  }
}

variable "api_port" {
  description = "Puerto de la API en 127.0.0.1."
  type        = number
  default     = 8080
  nullable    = false

  validation {
    condition     = var.api_port >= 1 && var.api_port <= 65535 && floor(var.api_port) == var.api_port
    error_message = "api_port debe ser un puerto entre 1 y 65535."
  }
}

# Secretos. Sin definir (null) se generan. Los errores nombran la variable y nunca muestran su valor.
# Longitud en bytes: tres cuartos de la codificación en base64 sin relleno, redondeando hacia abajo.

variable "jwt_secret" {
  type      = string
  default   = null
  sensitive = true

  validation {
    condition     = var.jwt_secret == null ? true : floor(length(replace(base64encode(var.jwt_secret), "=", "")) * 3 / 4) >= 32
    error_message = "jwt_secret necesita 32 bytes como mínimo."
  }
}

variable "demo_user_password" {
  type      = string
  default   = null
  sensitive = true

  validation {
    condition = var.demo_user_password == null ? true : (
      length(var.demo_user_password) > 0 &&
      floor(length(replace(base64encode(var.demo_user_password), "=", "")) * 3 / 4) <= 72
    )
    error_message = "demo_user_password debe tener de 1 a 72 bytes."
  }
}

variable "demo_admin_password" {
  type      = string
  default   = null
  sensitive = true

  validation {
    condition = var.demo_admin_password == null ? true : (
      length(var.demo_admin_password) > 0 &&
      floor(length(replace(base64encode(var.demo_admin_password), "=", "")) * 3 / 4) <= 72
    )
    error_message = "demo_admin_password debe tener de 1 a 72 bytes."
  }
}

variable "ai_api_key" {
  type      = string
  default   = null
  sensitive = true

  validation {
    condition     = var.ai_api_key == null ? true : can(regex("^sk-[A-Za-z0-9_-]+$", var.ai_api_key))
    error_message = "ai_api_key debe empezar por sk- y usar solo letras, números, - y _."
  }
}

variable "catalog_db_password" {
  type      = string
  default   = null
  sensitive = true

  validation {
    condition     = var.catalog_db_password == null ? true : can(regex("^[A-Za-z0-9]+$", var.catalog_db_password))
    error_message = "catalog_db_password admite solo letras y números."
  }
}

variable "spotify_client_id" {
  type      = string
  default   = ""
  sensitive = true
  nullable  = false
}

variable "spotify_client_secret" {
  type      = string
  default   = ""
  sensitive = true
  nullable  = false
}

# Modelos y tiempos.

variable "ollama_chat_model" {
  description = "Modelo de Ollama detrás del alias recomendador-chat."
  type        = string
  default     = "llama3.2:3b"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9._:/-]+$", var.ollama_chat_model))
    error_message = "ollama_chat_model no es un nombre de modelo válido."
  }
}

variable "ollama_embedding_model" {
  description = "Modelo de Ollama detrás del alias recomendador-embeddings."
  type        = string
  default     = "nomic-embed-text"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9._:/-]+$", var.ollama_embedding_model))
    error_message = "ollama_embedding_model no es un nombre de modelo válido."
  }
}

variable "ai_timeout" {
  description = "Tiempo máximo de la búsqueda y la llamada al modelo."
  type        = string
  default     = "30s"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+(ms|s|m)$", var.ai_timeout))
    error_message = "ai_timeout debe ser una duración como 30s, 500ms o 1m."
  }
}

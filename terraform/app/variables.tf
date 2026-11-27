variable "cluster_instance" {
  description = "Identifica al clúster actual (salida de la raíz cluster); si cambia, se vuelve a aplicar todo."
  type        = string
  nullable    = false
}

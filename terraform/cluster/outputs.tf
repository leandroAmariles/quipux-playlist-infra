output "name" {
  value = kind_cluster.this.name
}

# Cambia cuando el clúster es otro, aunque conserve el nombre: la raíz app vuelve a aplicar todo.
output "cluster_instance" {
  value = sha256(kind_cluster.this.cluster_ca_certificate)
}

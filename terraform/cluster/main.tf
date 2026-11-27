data "terraform_remote_state" "config" {
  backend = "local"

  config = {
    path = "${path.module}/../config/terraform.tfstate"
  }
}

# El proveedor no marca client_key ni kubeconfig como sensibles: scripts/lib/terraform.sh filtra la salida.
resource "kind_cluster" "this" {
  name            = "quipux-playlist"
  node_image      = "kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f"
  kubeconfig_path = "${path.module}/../../.local/kubeconfig"
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # Web: NodePort del Service web-local.
      extra_port_mappings {
        container_port = 30080
        host_port      = data.terraform_remote_state.config.outputs.web_port
        listen_address = "127.0.0.1"
        protocol       = "TCP"
      }

      # API: NodePort del Service api-local.
      extra_port_mappings {
        container_port = 30081
        host_port      = data.terraform_remote_state.config.outputs.api_port
        listen_address = "127.0.0.1"
        protocol       = "TCP"
      }
    }
  }
}

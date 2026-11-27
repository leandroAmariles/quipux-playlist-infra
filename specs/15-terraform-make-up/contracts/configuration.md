# Contrato: configuración local

`terraform/local.tfvars` es opcional. La plantilla es `terraform/local.tfvars.example`.

## Variables

| Variable | Por defecto | Para qué |
|---|---|---|
| `ai_enabled` | `true` | IA en Docker y su conexión con la API |
| `gpu` | `"auto"` | `auto`, `on` u `off` |
| `argocd_enabled` | `false` | desplegar `main` con Argo CD |
| `web_port` | `4200` | puerto de la web en `127.0.0.1` |
| `api_port` | `8080` | puerto de la API en `127.0.0.1` |
| `jwt_secret` | generado | firma de los tokens |
| `demo_user_password` | generado | usuario `user` |
| `demo_admin_password` | generado | usuario `admin` |
| `spotify_client_id` | vacío | credencial opcional |
| `spotify_client_secret` | vacío | credencial opcional |
| `ai_api_key` | generado | clave de LiteLLM |
| `catalog_db_password` | generado | PostgreSQL del catálogo |
| `ollama_chat_model` | `llama3.2:3b` | modelo de `recomendador-chat` |
| `ollama_embedding_model` | `nomic-embed-text` | modelo de `recomendador-embeddings` |
| `ai_timeout` | `30s` | tiempo máximo de la recomendación |

## `Secret` `playlist-secrets`

Siempre: `JWT_SECRET`, `DEMO_USER_PASSWORD`, `DEMO_ADMIN_PASSWORD`, `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`.

Solo con `ai_enabled`:

| Clave | Valor |
|---|---|
| `AI_PROVIDER` | `openai` |
| `AI_BASE_URL` | `http://quipux-litellm:4000/v1` |
| `AI_API_KEY` | clave de LiteLLM |
| `AI_TIMEOUT` | `ai_timeout` |
| `CATALOG_DB_URL` | `jdbc:postgresql://quipux-catalog-db:5432/catalog` |
| `CATALOG_DB_PASSWORD` | contraseña del catálogo |

## `.local/compose.env`

`AI_API_KEY`, `CATALOG_DB_PASSWORD`, `OLLAMA_CHAT_MODEL`, `OLLAMA_EMBEDDING_MODEL` y `BACKEND_TAG` (el `newTag` del
backend en `k8s/kustomization.yaml`). Lo genera Terraform; no se edita a mano.

Las variables de entorno de la terminal tienen prioridad en Compose: el script borra estas cinco antes de invocarlo.

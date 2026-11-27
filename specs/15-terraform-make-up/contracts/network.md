# Contrato: red y puertos

```text
equipo (127.0.0.1)
  :4200 ─> nodo kind :30080 ─> Service web-local ─> pod web :8080 ─> Service api
  :8080 ─> nodo kind :30081 ─> Service api-local ─> pod api :8080
                                                       │
red Docker "kind"                                      ├─> quipux-litellm:4000
                                                       └─> quipux-catalog-db:5432
red Docker "quipux-cluster_default"
  litellm ─> ollama:11434
  catalog-index ─> litellm:4000, catalog-db:5432
```

| Elemento | Publicado en el equipo | Redes Docker |
|---|---|---|
| nodo `kind` | `4200`, `8080` y el API server, solo en `127.0.0.1` | `kind` |
| `litellm` | no | `kind`, `quipux-cluster_default` |
| `catalog-db` | no | `kind`, `quipux-cluster_default` |
| `ollama` | no | `quipux-cluster_default` |
| `ollama-init`, `catalog-index` | no | `quipux-cluster_default` |

- `redis` y `kafka` siguen como `ClusterIP`.
- Al no publicar `4000` ni `5433`, la pila convive con la composición `quipux-ia`.
- La red `kind` la crea el clúster y Compose la usa como externa; `make down` no la elimina.
- Comprobación de `make up` con IA: desde el pod `api`, `nc -z` a `quipux-litellm 4000` y `quipux-catalog-db 5432`.

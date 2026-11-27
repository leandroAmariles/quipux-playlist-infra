# Contrato: comandos `make`

Se ejecutan desde la raíz de `quipux-playlist-infra`.

| Comando | Efecto | Muestra secretos |
|---|---|---|
| `make` / `make help` | lista los comandos | no |
| `make up` | crea o actualiza el entorno y espera a que esté listo | no |
| `make status` | clúster, pods, contenedores de IA y direcciones; no modifica nada | no |
| `make down` | elimina clúster y contenedores; conserva secretos y volúmenes | no |
| `make clean` | pide confirmación; además borra volúmenes, secretos, estado y `.local/` | no |
| `make credentials` | muestra usuarios y contraseñas de demostración | **sí**, solo las dos contraseñas |
| `make smoke` | inicia sesión, crea una lista temporal, pide recomendaciones y la borra | no |
| `make validate` | `terraform fmt -check`, `validate` y `shellcheck` si está instalado | no |

## Parámetros

Sustituyen a `local.tfvars` solo en esa ejecución.

| Parámetro | Valores | Ejemplo |
|---|---|---|
| `AI` | `true`, `false` | `make up AI=false` |
| `GPU` | `auto`, `on`, `off` | `make up GPU=off` |
| `ARGOCD` | `true`, `false` | `make up ARGOCD=true` |
| `CONFIRM` | `yes` (solo `clean`, para uso sin terminal interactiva) | `make clean CONFIRM=yes` |

## Resultados

- Código `0`: la operación terminó y, en `up`, el entorno está listo.
- Código distinto de `0`: una línea `ERROR:` con el paso, la causa y qué hacer. Con fallo de Terraform, la ruta del
  registro en `.local/logs/`.
- `make smoke` exige origen `IA` o `SIMILITUD` con la IA activa y `RESPALDO` sin ella. La lista temporal se borra también
  si la comprobación falla.
- `make down` y `make clean` terminan con éxito si ya no queda nada que borrar.

## Salida final de `make up`

```text
Entorno listo (IA: GPU, Argo CD: no)
  Web      http://localhost:4200
  API      http://localhost:8080
  Swagger  http://localhost:8080/swagger-ui.html
  Credenciales: make credentials
  kubectl:      kubectl --kubeconfig .local/kubeconfig -n quipux-playlist get pods
```

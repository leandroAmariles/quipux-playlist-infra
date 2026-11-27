# Contrato: servidor web (nginx)

Escucha en el puerto 8080 del contenedor.

## Rutas

| Petición | Destino |
|---|---|
| `/api/<resto>` | `${API_URL}/<resto>`, con `<resto>` y la consulta tal como llegaron |
| archivo que existe en la web compilada | ese archivo |
| cualquier otra | `index.html`, para que Angular resuelva la ruta |

Ejemplos:

| Entra | Sale hacia la API |
|---|---|
| `POST /api/auth/login` | `POST /auth/login` |
| `GET /api/lists/Mis%20favoritas` | `GET /lists/Mis%20favoritas` |
| `DELETE /api/lists/a%3Bb%25c` | `DELETE /lists/a%3Bb%25c` |
| `GET /playlists/detail?name=x` | no sale: entrega `index.html` |

## Lo que no cambia en el reenvío

Método, cuerpo, `Authorization`, código de estado, cuerpo de respuesta y cabeceras (incluida `Location`, que sigue
siendo la de la API, sin `/api`, como con el proxy de desarrollo). `Host` es el que envió el cliente.

## Respuestas propias del servidor web

| Situación | Respuesta |
|---|---|
| `/api` sin barra final | `301` a `/api/`, relativo |
| API no disponible | `502` |
| Cuerpo de más de 1 MB | `413` |

"""Warms up both models through the gateway, the same path the API uses.

The first requests after creating the Ollama container take much longer than the backend waits (5 s for the catalog
search, 30 s for the whole recommendation). It runs inside the litellm container: scripts/lib/ai.sh pipes it to Python.
"""

import json
import os
import sys
import time
import urllib.request

BASE_URL = "http://127.0.0.1:4000/v1"
MAX_ATTEMPTS = 5
# Margins below the time limits of the backend.
EMBEDDING_LIMIT_SECONDS = 3.0
CHAT_LIMIT_SECONDS = 20.0
SONGS = "\n".join(f"- Song number {index} by Artist {index}, genre rock, year 1999" for index in range(1, 41))


def call(path, body):
    request = urllib.request.Request(
        BASE_URL + path,
        data=json.dumps(body).encode(),
        headers={
            "Authorization": "Bearer " + os.environ["LITELLM_MASTER_KEY"],
            "Content-Type": "application/json",
        },
    )
    start = time.monotonic()
    with urllib.request.urlopen(request, timeout=150) as response:
        response.read()
    return time.monotonic() - start


def main():
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            embedding = call("/embeddings", {"model": "recomendador-embeddings", "input": [SONGS[:600]]})
            chat = call(
                "/chat/completions",
                {
                    "model": "recomendador-chat",
                    "messages": [{"role": "user", "content": "Pick one song of this list:\n" + SONGS}],
                    "max_tokens": 64,
                },
            )
        except OSError as error:
            print(f"    intento {attempt}: los modelos aún no responden ({type(error).__name__})", flush=True)
            time.sleep(3)
            continue
        print(f"    intento {attempt}: embeddings {embedding:.1f} s, chat {chat:.1f} s", flush=True)
        if embedding <= EMBEDDING_LIMIT_SECONDS and chat <= CHAT_LIMIT_SECONDS:
            return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())

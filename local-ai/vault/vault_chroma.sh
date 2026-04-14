#!/usr/bin/env bash
# vault-chroma: Manage ChromaDB container for LE local-le-chromadb
# Container: le-chroma (chromadb/chroma:latest)
# Volume: le-chroma-data
# Port: 8100 (host) -> 8000 (container)

set -euo pipefail

CONTAINER_NAME="le-chroma"
CHROMA_PORT=8100
CHROMA_IMAGE="chromadb/chroma:latest"
VOLUME_NAME="le-chroma-data"
CHROMA_VENV="$HOME/.local/share/le-vault-chroma/venv"

start() {
  # Check if container exists
  if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
      echo "ChromaDB already running (container: ${CONTAINER_NAME})"
      return 0
    fi
    echo "Starting existing container..."
    docker start "$CONTAINER_NAME" > /dev/null
  else
    echo "Creating ChromaDB container..."
    docker run -d \
      --name "$CONTAINER_NAME" \
      --restart unless-stopped \
      -p "${CHROMA_PORT}:8000" \
      -v "${VOLUME_NAME}:/chroma/chroma" \
      -e ANONYMIZED_TELEMETRY=false \
      "$CHROMA_IMAGE" > /dev/null
  fi

  sleep 2
  if curl -sf "http://localhost:${CHROMA_PORT}/api/v2/heartbeat" > /dev/null 2>&1; then
    echo "ChromaDB running (container: ${CONTAINER_NAME}, port: ${CHROMA_PORT})"
  else
    echo "ChromaDB started but not responding yet. Check: docker logs ${CONTAINER_NAME}"
  fi
}

stop() {
  if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    docker stop "$CONTAINER_NAME" > /dev/null
    echo "ChromaDB stopped"
  else
    echo "ChromaDB is not running"
  fi
}

status() {
  if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    local hb
    hb=$(curl -sf "http://localhost:${CHROMA_PORT}/api/v2/heartbeat" 2>/dev/null || echo "not responding")
    echo "ChromaDB: running (container: ${CONTAINER_NAME}, port: ${CHROMA_PORT})"
    echo "Heartbeat: ${hb}"
    echo "Volume: ${VOLUME_NAME}"

    # Show collection stats via Python client
    "${CHROMA_VENV}/bin/python3" -c "
import chromadb
c = chromadb.HttpClient(host='localhost', port=${CHROMA_PORT})
cols = c.list_collections()
if cols:
    for name in cols:
        col = c.get_collection(name)
        print(f'  Collection: {name} ({col.count()} chunks)')
else:
    print('  No collections')
" 2>/dev/null || echo "  Could not fetch collections"
  else
    echo "ChromaDB: not running"
    if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
      echo "  Container exists but is stopped. Run: vault-chroma start"
    else
      echo "  No container found. Run: vault-chroma start"
    fi
  fi
}

destroy() {
  echo "This will delete the container AND all indexed data."
  read -p "Are you sure? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    docker volume rm "$VOLUME_NAME" 2>/dev/null || true
    echo "Container and volume removed. Run: vault-chroma start && vault-index --full"
  fi
}

ui() {
  if docker ps --format '{{.Names}}' | grep -qx "chroma-admin-ui"; then
    echo "Chromadb Admin UI: http://localhost:9990"
    echo "  Connection string: http://host.docker.internal:8100"
  else
    echo "Starting Chromadb Admin UI..."
    docker run -d \
      --name chroma-admin-ui \
      --restart unless-stopped \
      -p 9990:3001 \
      fengzhichao/chromadb-admin > /dev/null
    sleep 3
    echo "Chromadb Admin UI: http://localhost:9990"
    echo "  Connection string: http://host.docker.internal:8100"
    open "http://localhost:9990" 2>/dev/null || true
  fi
}

case "${1:-status}" in
  start) start ;;
  stop) stop ;;
  restart) stop; sleep 1; start ;;
  status) status ;;
  log) docker logs -f --tail 50 "$CONTAINER_NAME" 2>&1 ;;
  ui) ui ;;
  destroy) destroy ;;
  *) echo "Usage: vault-chroma {start|stop|restart|status|log|ui|destroy}" ;;
esac

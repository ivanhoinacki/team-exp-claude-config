#!/usr/bin/env bash
# vault-query: CLI wrapper for ChromaDB local-le-chromadb
# Usage: vault-query "boolean validation zod" [--type review-learning] [--service svc-search] [--n 5]
#
# Used by: Claude Code (local-le-chromadb MCP), manual queries

set -euo pipefail

CHROMA_PORT="${CHROMA_PORT:-8100}"
CHROMA_VENV="$HOME/.local/share/le-vault-chroma/venv"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"

QUERY=""
TYPE_FILTER=""
SERVICE_FILTER=""
N_RESULTS=5

while [ $# -gt 0 ]; do
  case "$1" in
    --type) TYPE_FILTER="$2"; shift 2 ;;
    --service) SERVICE_FILTER="$2"; shift 2 ;;
    --n) N_RESULTS="$2"; shift 2 ;;
    --help|-h) echo "Usage: vault-query \"query\" [--type TYPE] [--service SERVICE] [--n NUM]"; exit 0 ;;
    *) QUERY="$1"; shift ;;
  esac
done

[ -z "$QUERY" ] && { echo "Usage: vault-query \"query\" [--type TYPE] [--service SERVICE] [--n NUM]"; exit 1; }

# Check ChromaDB
if ! curl -sf "http://localhost:${CHROMA_PORT}/api/v2/heartbeat" > /dev/null 2>&1; then
  echo "ChromaDB not running. Start with: vault-chroma start" >&2
  exit 1
fi

exec "${CHROMA_VENV}/bin/python3" -c "
import chromadb, requests, os, sys, json

client = chromadb.HttpClient(host='localhost', port=${CHROMA_PORT})
col = client.get_collection('le-vault')

query = '''${QUERY}'''
n_results = ${N_RESULTS}
type_filter = '${TYPE_FILTER}'.split(',') if '${TYPE_FILTER}' else []
service_filter = '${SERVICE_FILTER}'

# Embed query via Ollama
headers = {'Content-Type': 'application/json'}

try:
    emb = requests.post(
        'http://localhost:${OLLAMA_PORT}/api/embed',
        headers=headers,
        json={'model': 'nomic-embed-text', 'input': query},
        timeout=15
    ).json()['embeddings'][0]
except Exception as e:
    print(f'Error getting embedding: {e}', file=sys.stderr)
    sys.exit(1)

# Build where filter
where = None
conditions = []
if type_filter:
    conditions.append({'type': {'\$in': type_filter}})
if service_filter:
    conditions.append({'services': {'\$contains': service_filter}})
if len(conditions) == 1:
    where = conditions[0]
elif len(conditions) > 1:
    where = {'\$and': conditions}

kwargs = {
    'query_embeddings': [emb],
    'n_results': n_results,
    'include': ['documents', 'metadatas', 'distances'],
}
if where:
    kwargs['where'] = where

results = col.query(**kwargs)

for doc, meta, dist in zip(results['documents'][0], results['metadatas'][0], results['distances'][0]):
    if dist > 0.85:
        continue
    source = meta.get('source_name', '?')
    section = meta.get('section', '')
    dtype = meta.get('type', '')
    services = meta.get('services', '')
    text = doc[:500].strip() if doc else ''
    print(f'## [{dtype}] {source}' + (f' > {section}' if section and section != 'full' else '') + f' (dist: {dist:.3f})')
    if services:
        print(f'Services: {services}')
    print()
    print(text)
    print()
    print('---')
    print()
"

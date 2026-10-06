#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --config-only) CONFIG_ONLY=1 ;;
    -h|--help) echo 'Usage: bash scripts/setup-ubuntu.sh [--config-only]'; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done
if [[ "$CONFIG_ONLY" = 1 ]]; then
  bash "$ROOT/dotfiles/ubuntu/bootstrap.sh" --config-only
else
  bash "$ROOT/dotfiles/ubuntu/bootstrap.sh"
  if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
    if [[ "$EUID" = 0 ]]; then PRIVILEGE=(); else PRIVILEGE=(sudo); fi
    "${PRIVILEGE[@]}" apt-get install -y nodejs npm
  fi
  if ! command -v codex >/dev/null; then
    npm install --global --prefix "$HOME/.local" @openai/codex@0.159.3
  else
    echo "Preserving installed Codex: $(codex --version)"
  fi
fi
python3 "$ROOT/scripts/install-config.py"
python3 "$ROOT/scripts/install-codex.py"
python3 "$ROOT/scripts/install-config.py" --verify
python3 "$ROOT/scripts/install-codex.py" --verify
export PATH="$HOME/.local/bin:$PATH"
if command -v codex >/dev/null; then
  codex --version
  codex doctor --summary || echo 'Doctor reported pending checks. Review its output; login is configured separately.'
else
  echo 'Codex CLI missing; config-only does not install it.'
fi
echo 'Open codex --profile company, run codex login on this machine, then review /hooks.'

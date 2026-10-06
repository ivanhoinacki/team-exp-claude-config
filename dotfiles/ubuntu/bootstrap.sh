#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${HOME}"
CONFIG_ONLY=0
VERIFY=0
INSTALL_NODE=0
for arg in "$@"; do
  case "$arg" in
    --config-only) CONFIG_ONLY=1 ;;
    --verify) VERIFY=1 ;;
    --node) INSTALL_NODE=1 ;;
    --target-home=*) TARGET_HOME="${arg#*=}" ;;
    -h|--help)
      echo 'Usage: bash dotfiles/ubuntu/bootstrap.sh [--config-only] [--verify] [--node] [--target-home=/path]'
      exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done
[[ "$TARGET_HOME" = /* ]] || { echo 'Target home must be an absolute path.' >&2; exit 2; }
for file in zshrc zshrc.local.example tmux.conf ghostty.conf git-ui.conf repos.lock; do
  [[ -f "$SCRIPT_DIR/$file" ]] || { echo "Missing package file: $file" >&2; exit 1; }
done
BACKUP="$TARGET_HOME/.local/state/team-config/backups/$(date +%Y%m%d-%H%M%S)-$$"

install_file() {
  local source="$1" relative="$2" dest="$TARGET_HOME/$2"
  if [[ "$VERIFY" = 1 ]]; then
    cmp -s "$SCRIPT_DIR/$source" "$dest" || { echo "Different or missing: $relative" >&2; return 1; }
    return
  fi
  if cmp -s "$SCRIPT_DIR/$source" "$dest"; then return; fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    [[ -f "$dest" && ! -L "$dest" ]] || { echo "Refusing to replace non-regular file: $relative" >&2; return 1; }
    mkdir -p "$(dirname "$BACKUP/$relative")"
    chmod 700 "$BACKUP"
    cp -p "$dest" "$BACKUP/$relative"
  fi
  mkdir -p "$(dirname "$dest")"
  install -m 600 "$SCRIPT_DIR/$source" "$dest"
}

clone_pinned() {
  local url="$1" relative="$2" ref="$3" dest="$TARGET_HOME/$2"
  if [[ -e "$dest" ]]; then
    [[ -d "$dest/.git" ]] || { echo "Existing non-repository path: $relative" >&2; return 1; }
    git -C "$dest" rev-parse --verify HEAD >/dev/null 2>&1 || { echo "Incomplete repository: $relative. Repair it before retrying." >&2; return 1; }
    echo "Preserved existing repository: $relative"
    return
  fi
  mkdir -p "$dest"
  git -C "$dest" init -q
  git -C "$dest" remote add origin "$url"
  git -C "$dest" fetch -q --depth=1 origin "$ref"
  git -C "$dest" checkout -q --detach FETCH_HEAD
  [[ "$(git -C "$dest" rev-parse HEAD)" = "$ref" ]] || return 1
}

if [[ "$CONFIG_ONLY" = 0 && "$VERIFY" = 0 ]]; then
  [[ -r /etc/os-release ]] || { echo 'Use --config-only outside Ubuntu.' >&2; exit 1; }
  . /etc/os-release
  [[ "${ID:-}" = ubuntu ]] || { echo 'This dependency installer targets Ubuntu. Use --config-only.' >&2; exit 1; }
  if [[ "$EUID" = 0 ]]; then PRIVILEGE=(); else PRIVILEGE=(sudo); fi
  "${PRIVILEGE[@]}" apt-get update
  "${PRIVILEGE[@]}" apt-get install -y zsh git curl ca-certificates python3 jq fzf ripgrep \
    bat fd-find zoxide tmux unzip fontconfig lsof procps util-linux iproute2 xclip wl-clipboard
  OPTIONAL=()
  for pkg in eza git-delta duf dust gping lazygit lazydocker; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      OPTIONAL+=("$pkg")
    else
      echo "Optional package unavailable in configured Ubuntu repositories: $pkg"
    fi
  done
  if [[ ${#OPTIONAL[@]} -gt 0 ]]; then
    "${PRIVILEGE[@]}" apt-get install -y "${OPTIONAL[@]}"
  fi
  while IFS='|' read -r url relative ref; do
    [[ -n "$url" && "$url" != \#* ]] || continue
    clone_pinned "$url" "$relative" "$ref"
  done < "$SCRIPT_DIR/repos.lock"
  THEME_LINK="$TARGET_HOME/.oh-my-zsh/custom/themes/spaceship.zsh-theme"
  if [[ ! -e "$THEME_LINK" && ! -L "$THEME_LINK" ]]; then
    ln -s spaceship-prompt/spaceship.zsh-theme "$THEME_LINK"
  fi
  if [[ "$INSTALL_NODE" = 1 ]]; then
    [[ "$TARGET_HOME" = "$HOME" ]] || { echo '--node requires the actual user home.' >&2; exit 2; }
    export NVM_DIR="$TARGET_HOME/.nvm"
    set +u
    . "$NVM_DIR/nvm.sh"
    nvm install --lts
    set -u
  fi
fi

install_file zshrc .zshrc
install_file zshrc.local.example .zshrc.local.example
install_file tmux.conf .tmux.conf
install_file ghostty.conf .config/ghostty/config
install_file git-ui.conf .config/git/team-ui.conf

# Link only the UI settings. Never copy the source machine's Git identity or helpers.
if [[ "$VERIFY" = 0 ]] && command -v delta >/dev/null 2>&1; then
  GIT_FILE="$TARGET_HOME/.gitconfig"
  INCLUDE_FILE="$TARGET_HOME/.config/git/team-ui.conf"
  if ! git config --file "$GIT_FILE" --get-all include.path 2>/dev/null | grep -Fxq "$INCLUDE_FILE"; then
    if [[ -e "$GIT_FILE" || -L "$GIT_FILE" ]]; then
      [[ -f "$GIT_FILE" && ! -L "$GIT_FILE" ]] || { echo 'Refusing to edit non-regular .gitconfig.' >&2; exit 1; }
      mkdir -p "$BACKUP"
      chmod 700 "$BACKUP"
      cp -p "$GIT_FILE" "$BACKUP/.gitconfig"
    fi
    git config --file "$GIT_FILE" --add include.path "$INCLUDE_FILE"
  fi
fi

if command -v zsh >/dev/null 2>&1; then
  zsh -n "$TARGET_HOME/.zshrc"
else
  echo 'zsh is missing. File installation completed; shell startup is not validated.'
fi
if [[ "$VERIFY" = 1 ]]; then
  echo 'Verified 5 Ubuntu configuration files; runtime availability is listed below.'
else
  echo 'Installed 5 Ubuntu configuration files. Existing local secrets were untouched.'
  [[ ! -d "$BACKUP" ]] || echo "Backup: $BACKUP"
  echo 'Open zsh to test. Default login shell and Node version were not changed unless --node was selected.'
fi
for tool in zsh git fzf zoxide eza batcat delta tmux jq dust duf gping lazygit lazydocker ghostty; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'AVAILABLE %s\n' "$tool"
  else
    printf 'OPTIONAL/MISSING %s\n' "$tool"
  fi
done

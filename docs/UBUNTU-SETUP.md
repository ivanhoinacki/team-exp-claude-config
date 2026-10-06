# Ubuntu: replicating the macOS terminal setup

Goal: a Ubuntu machine with the same shell, prompt, aliases and dev helpers as the Mac, without copying credentials or anything tied to one machine.

## What is in `dotfiles/ubuntu/`

| File | Owner | Purpose |
|---|---|---|
| `zshrc` | shell | oh-my-zsh + Spaceship prompt, zinit plugins, history, completion and key bindings, modern CLI aliases, git aliases, port/docker/clipboard helpers, optional Ollama helpers |
| `zshrc.local.example` | per machine | Template for tokens, company paths and aliases. Copy to `~/.zshrc.local`. |
| `bootstrap.sh` | installer | Installs zsh and the CLI tools the zshrc uses (apt where available, pinned upstream otherwise), pre-installs the zinit plugins pinned in `repos.lock`, backs up existing files and never touches `~/.zshrc.local`. It does NOT install fonts or Ghostty. |
| `ghostty.conf`, `tmux.conf`, `git-ui.conf` | terminal and git | Terminal, multiplexer and git/delta settings |

## Install

```bash
git clone --branch transfer/company-config-20261005 https://github.com/ivanhoinacki/team-exp-claude-config.git
cd team-exp-claude-config/dotfiles/ubuntu

bash bootstrap.sh                      # tools, plugins, and installs ~/.zshrc (backs up the old one)
cp -n zshrc.local.example ~/.zshrc.local  # never overwrites an existing one; edit it on this machine
chsh -s "$(command -v zsh)"            # log out and back in
```

The zinit plugins (autosuggestions, completions, fast-syntax-highlighting, spaceship-vi-mode) come pre-installed by the bootstrap at the commits pinned in `repos.lock`. Without the bootstrap, the first zsh start clones them.

### Fonts and Ghostty (manual)

The bootstrap does not install these, because both depend on the desktop:

- **Font:** JetBrainsMono Nerd Font, used by the prompt icons and `eza --icons`. Install it from the Nerd Fonts releases into `~/.local/share/fonts`, then run `fc-cache -f`.
- **Ghostty:** install it with the method its docs list for Ubuntu, then copy `ghostty.conf` to `~/.config/ghostty/config`.

Without the font, the prompt still works, but icons show as boxes.

For the Claude Code part (rules, skills, agents), follow `docs/COMPANY-MACHINE.md`.

## What changes between macOS and Ubuntu

| On the Mac | On Ubuntu | How the zshrc handles it |
|---|---|---|
| `pbcopy` / `pbpaste` | `wl-copy` / `wl-paste` (Wayland) or `xclip` (X11) | Chosen by `WAYLAND_DISPLAY` / `DISPLAY`; none over plain SSH |
| `bat`, `fd` | `batcat`, `fdfind` (apt names) | Aliased to the usual names |
| `date -r <ts>` | `date -d @<ts>` | `ts` uses the GNU form |
| `uuidgen` | `/proc/sys/kernel/random/uuid` | `uuid` reads the kernel |
| `lsof -iTCP -sTCP:LISTEN` | `ss -ltnp` | `ports` uses `ss` |
| `dscacheutil` / `mDNSResponder` | `resolvectl flush-caches` | `flushdns` |
| `vm_stat`, `memory_pressure` | `free -h`, `swapon --show` | `mem`, `swap` |
| Homebrew `shellenv` | not used | removed |
| Alt+arrow word jump | Ctrl+arrow on most Linux terminals | both bound |

## Left out on purpose

- **Credentials.** `NPM_TOKEN` and `NOTION_TOKEN` sit in the Mac zshrc in plain text. On Ubuntu they belong in a secret store (`secret-tool`, `pass`), loaded from `~/.zshrc.local`. The example file shows how.
- **Hardware tuning.** `NODE_OPTIONS=10GB`, the thread counts and the Ollama limits were sized for a 36 GB M3 Max. Set them per machine.
- **Personal services.** Aliases for personal dashboards and notes, launchd jobs, cloud-drive paths and other personal tooling. They depend on services that do not exist on a company machine.
- **SSH agent and `.zshenv`.** Machine-specific; set up fresh on each machine.
- **Pinned Claude model alias** (`copilot`). Model choice changes over time; set it locally if needed.

## Check it worked

```bash
zsh -i -c 'echo ok; type kp ts uuid jsonf; alias gs'
```

You should see `ok`, the four functions and `gs='git status'`. A zsh prompt with the Spaceship `❯` means the theme loaded.

# Dotfiles

Shell configuration templates for the engineering team.

## Files

| File | Purpose |
|---|---|
| `zshrc.template` | Full `.zshrc` with oh-my-zsh, Spaceship prompt, Zinit plugins, modern CLI aliases, and dev helper functions |

## What the template includes

- **oh-my-zsh** + Spaceship theme + Zinit plugin manager
- **Homebrew / Linuxbrew** path detection (macOS + Linux/WSL2)
- **NVM** setup for Node.js version management
- **Modern CLI aliases**: `eza` (ls), `bat` (cat), `dust` (du), `delta` (diff), `lazygit`, `lazydocker`
- **Git shortcuts**: `gs`, `gd`, `gl`, `gp`
- **Dev helper functions**:
  - `kp <port>` — kill process on port
  - `wp <port>` — check what runs on port
  - `ports` — list all active dev ports
  - `ts [epoch]` — timestamp converter
  - `uuid` — generate lowercase UUID
  - `status <url>` — quick HTTP status check
  - `dlogs`, `dsh`, `dps` — Docker shortcuts
  - `rlocal [port]` — Redis connect (prefers iredis)
- **Clipboard functions** (macOS: pbpaste, Linux/WSL2: xclip/xsel/powershell.exe):
  - `jsonf` — format JSON from clipboard
  - `jwtd` / `jwta` — decode JWT from clipboard
  - `b64e` / `b64d` — base64 encode/decode
  - `urle` / `urld` — URL encode/decode
  - `flushdns` — flush DNS cache (cross-platform)

## Usage

The template is not installed automatically. To use it:

```bash
# Review and customize first
cp dotfiles/zshrc.template ~/.zshrc.new
# Edit ~/.zshrc.new to your preferences
# Then replace your current .zshrc (backup first!)
cp ~/.zshrc ~/.zshrc.bak
mv ~/.zshrc.new ~/.zshrc
source ~/.zshrc
```

## Cross-platform support

The template detects the platform at shell startup:
- **macOS**: uses `pbpaste`/`pbcopy` for clipboard, Homebrew paths
- **WSL2**: uses `powershell.exe`/`clip.exe` as primary clipboard, falls back to `xclip`/`xsel`
- **Linux**: uses `xclip`, `xsel`, or `wl-clipboard` depending on what is installed

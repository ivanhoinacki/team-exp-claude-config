# Ubuntu transfer validation

The temporary branch includes a portable version of the Mac terminal configuration.
The source `.zshrc` had 893 lines. It was adapted rather than copied verbatim.
No live Mac shell configuration was changed by this export.

## Included

- Oh My Zsh, Spaceship, Zinit, suggestions, completions and syntax highlighting.
- Shared history, completion, keyboard bindings, fzf and zoxide.
- Git aliases, development helpers and optional Docker/Ollama helpers.
- Git/delta presentation without Git identity or credential helpers.
- tmux layout, shortcuts and colors without private agent status scripts.
- Ghostty appearance with Linux shortcuts, without macOS-only options or private paths.
- Eight upstream repositories pinned in `dotfiles/ubuntu/repos.lock`.

`bootstrap.sh` installs dependencies from the configured Ubuntu repositories. Existing
plugin repositories are preserved, not reset to the pinned commits. The maintained
`zdharma-continuum/fast-syntax-highlighting` replaces the removed upstream used by
an old local clone. `--config-only` copies configuration without installing dependencies;
opening zsh without installed Zinit/plugins can still trigger their upstream downloads.

## Validation

The full bootstrap was executed in an isolated Ubuntu 24.04 ARM64 container. It installed
its packages and all eight pinned repositories. Its `--verify` command compared the five
installed configuration files. Interactive zsh loaded Spaceship; its fzf Ctrl+R binding
was checked in a terminal. Git read the included delta configuration. tmux started from
the installed file and reported `mouse on` and `prefix C-a`.

The test image excluded documentation through dpkg. That image-only exclusion was
removed inside the test container and fzf was reinstalled before checking the legacy
completion scripts. No such change was made on the host machine.

Eight automated installation tests passed, including backups, targets containing spaces,
local override preservation, Git identity preservation, idempotent includes, drift
recognition and refusing symlink replacement.

Ghostty 1.3.1 validated `ghostty.conf` on macOS. Ubuntu GUI rendering, fonts, clipboard
integration, desktop shortcuts and x86_64 hardware were not measured. Node LTS installation
with `--node`, company SSO, SSH authentication and Docker services were not exercised.

Ubuntu repositories in this run provided eza, git-delta, duf and gping. They did not
provide dust, lazygit or lazydocker. Missing optional tools are reported by the bootstrap;
the shell keeps standard fallbacks instead of creating broken aliases.

## Remaining machine setup

1. Install JetBrainsMono Nerd Font and select it in the terminal. Ghostty is separate
   from the shell bootstrap. Run `ghostty +list-fonts` and `ghostty +validate-config`.
2. Use `bash dotfiles/ubuntu/bootstrap.sh --node` if Node LTS is appropriate for the
   company projects. Check each project's pinned runtime before choosing a version.
3. Configure fresh Git identity, company Git credentials and SSH keys on Ubuntu.
   Existing credentials are preserved; none are copied from the Mac.
4. Install Docker Engine only if projects need it. Docker aliases do not install or
   start a daemon. Install optional TUI tools separately if useful.
5. Keep machine paths and hardware-specific tuning in `~/.zshrc.local`. Existing local
   overrides are preserved. Do not apply the Mac's memory/thread limits to unknown hardware.
6. Change the login shell only after testing `zsh`; the bootstrap does not run `chsh`.

## Recovery

Existing replaced files are copied under
`~/.local/state/team-config/backups/<timestamp>-<pid>/`, preserving relative paths.
Restore individual files from that directory. The bootstrap refuses non-regular files.
It does not remove existing plugin repositories, Node versions or user overrides.

## Official references

- [Spaceship installation](https://spaceship-prompt.sh/getting-started/)
- [fzf installation and shell integration](https://github.com/junegunn/fzf#installation)
- [bat Ubuntu binary name](https://github.com/sharkdp/bat#on-ubuntu-using-apt)
- [Maintained syntax highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting)
- [NVM installation and usage](https://github.com/nvm-sh/nvm#installing-and-updating)
- [Ghostty Linux installation](https://ghostty.org/docs/install/binary)
- [Ghostty configuration](https://ghostty.org/docs/config/reference)
- [Nerd Fonts releases](https://github.com/ryanoasis/nerd-fonts/releases)
- [Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [lazygit installation](https://github.com/jesseduffield/lazygit#installation)
- [lazydocker installation](https://github.com/jesseduffield/lazydocker#installation)
- [dust installation](https://github.com/bootandy/dust#install)

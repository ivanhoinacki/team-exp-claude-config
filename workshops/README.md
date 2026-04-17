# Workshops

Presentation decks for the LE engineering team workshops on Claude Code.

| # | Title | Date | Links |
| --- | --- | --- | --- |
| 02 | Claude Code Ecosystem | Apr 2026 | [slides](https://ivanhoinacki.github.io/team-exp-claude-config/workshop-02/) · [PDF](https://ivanhoinacki.github.io/team-exp-claude-config/workshop-02.pdf) · [source](./workshop-02/) |

## Stack

Each workshop is built with [Slidev](https://sli.dev) (markdown-based presentations on Vue + Vite). Source lives under `workshop-XX/slidev/` and the live version is auto-deployed to GitHub Pages on every push to `main`.

## Deploy

The `.github/workflows/deploy-workshops.yml` workflow builds all workshops and publishes them under `https://ivanhoinacki.github.io/team-exp-claude-config/workshop-XX/`.

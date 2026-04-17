# Workshop 02: Claude Code Ecosystem

Hands-on workshop covering Claude Code rules, skills, hooks, MCP servers, agents, and CLAUDE.md for the LE engineering team.

**Date**: April 2026
**Duration**: ~2h45
**Audience**: LE engineering team

## Links

- **Live slides**: https://ivanhoinacki.github.io/team-exp-claude-config/workshop-02/
- **PDF**: https://ivanhoinacki.github.io/team-exp-claude-config/workshop-02.pdf
- **Source**: [`slidev/slides.md`](./slidev/slides.md)

Both are rebuilt automatically on every push to `main`.

## Agenda

| Block | Topic | Duration |
| --- | --- | --- |
| 0 | Recap + Delta (W1 to W2) | 10 min |
| 1 | Setup: 1 command install | 25 min |
| 2 | Hooks: invisible guard rails | 15 min |
| 3 | MCP servers: connecting systems | 15 min |
| 3.5 | Cursor integration | 10 min |
| - | Break | 10 min |
| 4 | CLAUDE.md: service dossier | 15 min |
| 5 | Agents + new skills | 20 min |
| 6 | Full workflow hands-on | 25 min |
| 7 | Learning cycle | 10 min |
| 8 | Q&A + next steps | 10 min |

## Run locally

```bash
cd slidev
npm install
npm run dev        # opens at http://localhost:3030
```

## Build

```bash
npm run build         # static site for GH Pages (base path included)
npm run build:local   # same but without base path (for local preview of dist)
npm run export        # PDF export
```

## Structure

```
slidev/
├── slides.md              # the deck (markdown)
├── style.css              # custom CSS (animations, layout)
├── global-bottom.vue      # autoplay v-clicks component
├── components/
│   └── ZoomImage.vue      # click-to-zoom diagram viewer
├── public/                # static assets (SVGs, PNGs, fonts)
└── package.json
```

# Discovery Checklist (Feature Development)

> Parent skill: [feature-dev/SKILL.md](../SKILL.md) — Phases 2 & 3

## Phase 2: Knowledge Base & Context Search

Search the company knowledge base BEFORE any planning. This includes local KB mirror, Confluence (via MCP), Slack, and GitHub PRs.

### 2.0 LE Vault RAG (MCP `local-le-chromadb`) — FIRST

Indexed semantic store (Chroma collection `le-vault`): review learnings, business rules, service dossiers, runbooks, pitfalls, troubleshooting.

**Always run this before 2.1–2.4** when the MCP is available:

1. **`query_vault`** — Natural language query using feature keywords, ticket id, and domain terms. Set **`service_filter`** when the repo or service is known (e.g. `svc-experiences`, `svc-order`). Optionally set **`type_filter`** (e.g. `business-rule`, `review-learning`, `runbook`) to narrow results.
2. **`list_vault_sources`** — If unsure which filters apply, list indexed types and top services, then refine `query_vault`.

**Zero useful hits?** Broaden the query or retry with terminology aliases (see 2.1) before relying only on grep or Confluence.

### 2.1 Service Chain & Terminology

Before searching, understand the data flow and terminology:

1. **Read ecosystem maps**: `Runbooks/Experiences-Ecosystem.md` and `Runbooks/Luxury-Escapes-Ecosystem.md`
2. **Build service chain**: list ALL services the feature touches (e.g., `www-le-customer -> svc-experiences -> svc-ee-offer`)
3. **Build terminology expansion**: the same concept has multiple names. Map aliases BEFORE searching:

```
Example: "LED" = "Lux Everyday", "svc-ee-offer", "Salesforce Connect"
Example: "complimentary" = "bundle" (used in Slack), "included experience"
Example: "experiences" = "things to do", "TTD", "tours", "activities"
```

Use ALL aliases in every search below.

### 2.2 Local KB Mirror

```
__VAULT_ROOT__/Knowledge-Base/Confluence/
├── PE-Experiences/              # 343 docs
└── ENGX-Engineering-Excellency/ # 204 docs
```

**Search by domain:**

| Domain       | Search terms                                                      |
| ------------ | ----------------------------------------------------------------- |
| Experiences  | experiences, rezdy, klook, derbysoft, provider, booking, musement |
| Car Hire     | car hire, cartrawler, vehicle, rental                             |
| Whitelabels  | whitelabel, WL, LED, brand                                        |
| Integrations | integration, API, provider, sync                                  |
| Infra        | AWS, ECS, RDS, Redis, Pulumi                                      |
| Auth         | auth, authentication, OTP, service-to-service                     |

Also check: `Processing/Technical-Knowledge-Collection.md`

**How to search:**

Use Grep tool with pattern `TERM` (replace with each alias), path `__VAULT_ROOT__/Knowledge-Base/Confluence/`, output mode `files_with_matches`.

### 2.3 Confluence (via MCP, beyond local mirror)

Search across ALL relevant Confluence spaces, not just PE. Use the tiered space list from `investigation-case/SKILL.md` Phase 0.5:

- **Tier 1 (ALWAYS)**: PE, TEC, ENGX
- **Tier 2 (when feature crosses teams)**: OE, HOT, WHI, LOYAL, TOUR
- **Tier 3 (broader context)**: GX, BMP, PROD, SO, DH, CS, DATA

**Minimum**: 3 queries across Tier 1 spaces using terminology aliases. For every relevant result, read the full page (not just the search snippet). Follow links to related pages.

**MCP tools to use:**

- `mcp__mcp-atlassian__confluence_search` with query including space key
- `mcp__mcp-atlassian__confluence_get_page` to read full pages from search results

### 2.4 Slack Context

Search for prior discussions about this feature area. Use channel tiers from `investigation-case/SKILL.md` Phase 0.5:

- **Tier 1 (ALWAYS)**: `#team-experiences-pt-br`, `#svc-experiences`, `#007-exp`
- **Tier 2 (when crossing teams)**: `#team-customer-payments`, `#team-bundles`, service-specific channels

**Minimum**: 2 keyword queries using terminology aliases. Read any relevant threads fully (not just snippets).

**MCP tools to use:**

- `mcp__claude_ai_Slack__slack_search_public_and_private` with each alias term
- `mcp__claude_ai_Slack__slack_read_thread` to read full threads from search results

### 2.5 GitHub PRs

Search for merged PRs that implemented similar features in the service chain repos:

```bash
# Search merged PRs (replace REPO and KEYWORD)
gh pr list --repo lux-group/REPO --search "KEYWORD" --state merged --limit 5

# Read PR body for rationale and trade-offs
gh pr view NUMBER --repo lux-group/REPO --json body,title
```

**Minimum**: 2 keyword variations per repo. Always read the PR body for rationale and trade-offs.

**Output:** list relevant docs found, context extracted, gaps to investigate.

## Phase 3: Codebase Discovery

Analyze the actual codebase to understand existing patterns.

### 3.1 Identify target service(s)

| Service         | Path                                       | Architecture                                           |
| --------------- | ------------------------------------------ | ------------------------------------------------------ |
| svc-experiences | ~/Documents/LuxuryEscapes/svc-experiences/ | API -> Context -> Providers -> Queries (TypeORM, PostGIS) |
| svc-car-hire    | ~/Documents/LuxuryEscapes/svc-car-hire/    | API -> Context -> Services (Prisma, BullMQ)              |
| svc-ee-offer    | ~/Documents/LuxuryEscapes/svc-ee-offer/    | API -> Operations -> Models (Sequelize, Salesforce)      |
| svc-occasions   | ~/Documents/LuxuryEscapes/svc-occasions/   | API -> Contexts -> Clients (Prisma, Express 5)           |
| www-le-customer | ~/Documents/LuxuryEscapes/www-le-customer/ | React 19, Redux, styled-components                     |

### 3.2 Discover patterns (run for each target service)

1. **Project structure:** Bash `ls ~/Documents/LuxuryEscapes/SERVICE/src/`

2. **Similar features:** Grep tool — pattern `DOMAIN_TERM`, path `~/Documents/LuxuryEscapes/SERVICE/src/`, glob `*.ts`, output `files_with_matches`

3. **Test patterns:** Glob tool — pattern `**/*.test.ts` in `SERVICE/src/`, filter for FEATURE_AREA. Read 1-2 files

4. **Validation patterns:** Grep tool — pattern `joi|zod|strummer|schema`, path `SERVICE/src/`, output `files_with_matches`, head_limit 5

5. **Error handling:** Grep tool — pattern `throw|AppError|HttpError|createError`, path `SERVICE/src/`, glob `*.ts`, output `files_with_matches`, head_limit 5

6. **Config patterns:** Glob tool — patterns `**/config*` and `**/schema.ts` in `SERVICE/src/`

7. **Existing CLAUDE.md or .cursorrules:** Read tool — `~/Documents/LuxuryEscapes/SERVICE/CLAUDE.md` (auto-loaded, but read manually if in agent context)

### 3.3 Discovery Checklist

After completing Phases 2 and 3, present this checklist showing what was analyzed. A row is only "checked" if the minimum search depth was met (see Phase 2 subsections for minimums).

```markdown
## Discovery Checklist

| Source                                  | Checked   | Findings                                       |
| --------------------------------------- | --------- | ---------------------------------------------- |
| LE Vault RAG (`query_vault` / `list_vault_sources`) | [x] / [ ] | [relevant chunks or "none after retries"]      |
| Service chain identified                | [x] / [ ] | [services in data flow]                        |
| Terminology aliases mapped              | [x] / [ ] | [key terms and their aliases]                  |
| Jira ticket (description, comments, AC) | [x] / [ ] | [summary or N/A]                               |
| Knowledge Base (PE-Experiences)         | [x] / [ ] | [docs found or "no relevant docs"]             |
| Knowledge Base (ENGX)                   | [x] / [ ] | [docs found or "no relevant docs"]             |
| Technical-Knowledge-Collection.md       | [x] / [ ] | [relevant entries or "none"]                   |
| Confluence (Tier 1: PE, TEC, ENGX)      | [x] / [ ] | [docs found, full pages read]                  |
| Confluence (Tier 2/3 if cross-team)     | [x] / [ ] | [docs found or N/A]                            |
| Codebase: similar features              | [x] / [ ] | [files referenced]                             |
| Codebase: test patterns                 | [x] / [ ] | [framework, mocking approach]                  |
| Codebase: validation patterns           | [x] / [ ] | [library, location]                            |
| Codebase: config/env var patterns       | [x] / [ ] | [pattern found]                                |
| Codebase: error handling patterns       | [x] / [ ] | [pattern found]                                |
| Datadog/NR: existing errors/metrics     | [x] / [ ] | [query + result or N/A]                        |
| Git history: recent changes             | [x] / [ ] | [relevant commits or "none"]                   |
| GitHub PR bodies: related merged PRs    | [x] / [ ] | [PR links + key rationale from body or "none"] |
| Slack: team discussions on this area    | [x] / [ ] | [key decisions found or "none"]                |
| Memory files: known pitfalls            | [x] / [ ] | [relevant entries or "none"]                   |
```

Every row must be checked. If a source is not applicable, mark it and explain why. Zero-result searches must be retried with a different alias or wording before accepting "none".

### 3.4 Pattern Summary

```
Patterns found:
- Architecture: [layers, direction of dependencies]
- Validation: [library, where it happens]
- Error handling: [pattern, custom errors]
- Testing: [framework, mocking approach, naming convention]
- Config: [how env vars are managed]
- Similar code: [files that do something similar to this feature]
```

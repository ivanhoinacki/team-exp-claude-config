---
name: capture-knowledge
model: haiku
description: |
  Capture business knowledge from Slack into the Knowledge Base. Two modes:
  (1) Single thread: pass a Slack URL to capture one discussion
  (2) Sweep: scan entire channels for Q&A threads, launch parallel agents per channel, catalog all findings
  Use when the user says "capture this", "salva esse conhecimento", "captura essa thread", "sweep channels", "varrer canais", "catalog knowledge", or shares a Slack URL with business context.
argument-hint: |
  [Slack URL for single thread, OR "sweep" to scan all channels, OR "sweep tier1" / "sweep tier2" for specific tiers]
compatibility: Requires git, Slack MCP, mcp-atlassian (Jira/Confluence)
allowed-tools: Bash(git *), Read, Write, Edit, Grep, Glob, Agent, mcp__claude_ai_Slack__slack_read_thread, mcp__claude_ai_Slack__slack_read_channel, mcp__claude_ai_Slack__slack_search_public_and_private, mcp__mcp-atlassian__jira_get_issue, mcp__mcp-atlassian__confluence_search, mcp__mcp-atlassian__confluence_get_page
---

# Capture Knowledge from Discussions

## Phase 0: Vault RAG (MANDATORY)

Before ANY file reads, grep, or codebase exploration, call `query_vault` with relevant keywords and service_filter. This is non-negotiable. The vault contains pitfalls, business rules, review learnings, and patterns that prevent rework. Skip = rework.


Extract business rules, technical flows, and domain knowledge from Slack. Save as structured knowledge that informs future development decisions.

## Two Modes

### Mode 1: Single Thread (`/capture-knowledge <URL>`)

Captures one specific Slack thread. Use when someone shares a URL or you spot an interesting discussion.

### Mode 2: Channel Sweep (`/capture-knowledge sweep`)

Scans entire channels for Q&A threads with valuable knowledge. Launches parallel agents per channel. Use weekly to keep the KB updated.

Arguments:
- `sweep` or `sweep all` = scan Tier 1 + Tier 2 channels
- `sweep tier1` = scan only Tier 1 (Team & Core)
- `sweep tier2` = scan only Tier 2 (Adjacent Teams)
- `sweep tier3` = scan only Tier 3 (Provider Integrations)
- `sweep #channel-name` = scan one specific channel

---

## Vertical Context (applies to ALL modes)

Our team (__TEAM_VERTICALS__) owns:
- **Backend**: svc-experiences, svc-ee-offer, svc-car-hire, svc-addons, svc-tag, svc-occasions, svc-fx, svc-traveller
- **Frontend**: www-ee-admin, www-ee-customer, www-ee-vendor
- **Providers**: LED/Salesforce (svc-ee-offer), Rezdy, Klook, Derbysoft, Collinson, CustomLinc/South Sea Cruises
- **Key flows**: experience booking, complimentary experiences (bundled with hotels), refunds, promo distribution, provider sync, availability, checkout traveller forms, search indexing
- **Terminology**: "LED" = "Lux Everyday" = svc-ee-offer = Salesforce Connect. "Complimentary" = "bundle" (in Slack). "TTD" = "things to do" = experiences

When capturing knowledge, always evaluate through the lens of our vertical. Even in other team's channels, only capture what is relevant to __TEAM_VERTICALS__.

---

## Mode 1: Single Thread

### Phase 1: Extract

Parse Slack URL to extract channel_id and message_ts:
- Format: `https://luxgroup-hq.slack.com/archives/{CHANNEL_ID}/p{TIMESTAMP}`
- Convert: remove `p` prefix, insert `.` before last 6 digits

Read full thread with `slack_read_thread`. If the thread references other threads, read those too.

### Phase 2: Classify

Determine if the thread contains capturable knowledge relevant to our vertical:

| Thread type | Capture? |
|---|---|
| Question with confirmed answer | Yes (High confidence) |
| Question with partial answer | Yes (Pending confidence) |
| Question unanswered | No (nothing to capture yet) |
| Decision discussion with outcome | Yes (High) |
| Bug report with root cause | Yes (High, route to `/learn` instead) |
| Status update / FYI | No (not a business rule) |
| Social / off-topic | No |

### Phase 3: Structure

Format as Business Rule entry (see Output Format below).

### Phase 4: Save

Route to domain file and save (see Routing below).

---

## Mode 2: Channel Sweep

### Phase 1: Select Channels

Based on the sweep argument, select channels from the tier map:

**Tier 1: Team & Core (ALWAYS in full sweep)**

| Channel | ID | Focus |
|---|---|---|
| #team-experiences-pt-br | C036ALHDG79 | Team internal, sprint, priorities |
| #team-experiences_white-label_car-hire | C08BDGHRHFV | Primary team channel (EN), decisions, cross-vertical |
| #svc-experiences | C0344V8000M | Service discussions, Q&A |
| #svc-ee-offer | C06CQ53CKEE | LED/Salesforce discussions |
| #007-exp | C04N4941MDE | Bug reports, experience issues |
| #experience-failed-bookings | C063YC78ZGC | Failed booking patterns |
| #experiences-alerts | C04LRU3RNH5 | Production alerts with human context |
| #experiences-issues-manual-intervention | C06U7SCH0EA | Manual intervention cases with root cause |

**Tier 2: Adjacent Teams**

| Channel | ID | Focus |
|---|---|---|
| #team-customer-payments | C01SXP59LGG | Order, checkout, refund rules |
| #team-bundles | C09CKS61ARY | Bundle/complimentary rules |
| #svc-order | CFKU42FD4 | Order service behavior |
| #svc-promo | CG0HDQ162 | Promo/discount logic |
| #svc-traveller | CFY31PLEP | Checkout form fields, traveller data |
| #svc-search | C01930V1GPL | Search indexing, discovery |

**Tier 3: Provider Integrations**

| Channel | ID | Focus |
|---|---|---|
| #klook-integration-external | C097FPR77SB | Klook API behavior |
| #collinson-integration-internal | C09R8BLUWMT | Collinson/lounge rules |
| #south-sea-integration-internal | C0AF41S6U15 | South Sea / CustomLinc |
| #exp-rezdy-new-ticket-alerts | C066L3Q61E2 | Rezdy ticket patterns |

### Phase 2: Launch Parallel Agents

For each selected channel, launch a background agent:

```
Agent(
  description: "Sweep #{channel_name} for knowledge",
  run_in_background: true,
  prompt: <channel sweep prompt below>
)
```

**Maximum**: 5 agents in parallel (to avoid rate limits).
If more channels, batch in groups of 5.

### Channel Sweep Agent Prompt

```
You are scanning Slack for business knowledge relevant to the Luxury Escapes Experiences vertical.

VERTICAL CONTEXT:
Our team owns: svc-experiences, svc-ee-offer, svc-car-hire, svc-addons, svc-tag, svc-occasions, svc-fx, svc-traveller, www-ee-admin, www-ee-customer, www-ee-vendor.
We consume: svc-order (payments team), svc-cart (CRO), svc-search (search team), svc-payment (payments), svc-auth (engx), svc-promo (marketing).
Providers: LED/Salesforce (svc-ee-offer), Rezdy, Klook, Derbysoft, Collinson, CustomLinc/South Sea Cruises.
Key flows: experience booking, complimentary experiences (bundled with hotels), refunds, promo distribution, provider sync, availability, checkout traveller forms, search indexing.
Terminology: "LED" = "Lux Everyday" = svc-ee-offer = Salesforce Connect. "Complimentary" = "bundle" (in Slack). "TTD" = "things to do" = experiences.

SCAN INSTRUCTIONS:
Scan Slack channel {CHANNEL_ID} (#{channel_name}) for the last 7 days (or since last sweep).

Read the channel using slack_read_channel. For each message that has thread replies (reply_count > 0):

1. Read the full thread with slack_read_thread
2. Classify: does this reveal how something works in the Experiences ecosystem?

CAPTURE if the thread contains:
- How a flow works (booking, refund, sync, availability, checkout, search indexing)
- Why something behaves a certain way (business rule, provider limitation, legacy decision)
- Provider-specific behavior (Rezdy availability gaps, Klook API quirks, LED Salesforce patterns)
- Cross-service interaction rules (svc-order calling svc-experiences, currency handling, promo distribution)
- Checkout field logic (dynamic fields per provider, required vs optional)
- Complimentary/bundle rules (how hotel+experience packaging works)
- Workarounds or exceptions to normal behavior
- Error patterns with root cause identified (booking failures, price validation, timeout patterns)
- Decisions made by the team about architecture, approach, or priority
- Answers to "how does X work?" or "why does X happen?" with confirmed explanation

SKIP if the thread is:
- Pure status update ("deployed X to staging")
- Social/off-topic
- Question with no answer yet (capture as "pending" ONLY if the question itself reveals a knowledge gap)
- CI/deploy alerts or bot notifications without human discussion
- Simple "thanks", acknowledgment, or emoji-only threads
- Hotels-only, flights-only, cruises-only topics with zero experience context
- Individual customer order issues without generalizable root cause

RELEVANCE FILTER:
Even in non-experience channels (#team-customer-payments, #svc-order, #svc-search), ONLY capture threads that touch the experience vertical. For example:
- In #svc-order: capture "complimentary experience rebook logic" but skip "hotel room upgrade refund"
- In #team-customer-payments: capture "experience item in payment plan" but skip "flight deposit retry"
- In #svc-search: capture "experience offer indexing" but skip "hotel typeahead dedup"

For each captured thread, extract:
- title: short description of the rule/knowledge (max 10 words)
- domain: one of [checkout, providers, refunds, promos, orders, search, whitelabel, operations, general]
- rule: the business rule as a clear, factual statement (NOT a conversation summary)
- context: why this matters for the Experiences team
- source_person: who confirmed/explained (name + role if known)
- confidence: high (confirmed by domain expert) / medium (discussed, not fully confirmed) / pending (question asked, not answered)
- services: affected services as array (use exact service names: svc-experiences, svc-order, etc.)
- channel: "#{channel_name}"
- date: YYYY-MM-DD

Return a JSON array of captured items. If nothing worth capturing, return [].
Do NOT include PII (customer IDs, order numbers, booking IDs, emails).
```

### Phase 3: Collect Results

After all agents complete, merge their findings. Deduplicate by checking:
1. Same rule already in `Knowledge-Base/Business-Rules/`
2. Same pitfall already in `pitfalls.md`
3. Similar knowledge across different channels (take the most complete version)

### Phase 4: Save All

For each unique finding, save to the appropriate domain file (see Routing below).

### Phase 5: Report

```
Channel Sweep Complete:
  Channels scanned: N
  Threads analyzed: N
  Knowledge captured: N new rules
  Updated: N existing rules
  Skipped: N (duplicates or no new info)

  New entries by domain:
  - Providers: X rules (Business-Rules/Providers.md)
  - Checkout: X rules (Business-Rules/Checkout.md)
  - Refunds: X rules (Business-Rules/Refunds.md)
  ...

  Last sweep: YYYY-MM-DD (saved to Business-Rules/.last-sweep)
```

Save the sweep date to `Knowledge-Base/Business-Rules/.last-sweep` so next sweep only looks at messages after this date.

---

## Output Format (both modes)

### File header (frontmatter + callout)

Each Business Rules file starts with:

```markdown
---
domain: providers
tags:
  - business-rules
  - providers
updated: YYYY-MM-DD
rule_count: N
---

# Business Rules: Providers

> [!abstract] Source
> Captured from team discussions, Slack threads, and operational knowledge.
> Each rule uses callouts to indicate confidence level.
> Used by Claude Code as context before implementing features in this domain.
```

### Per-rule format

```markdown
---

## [Short title describing the rule]

> [!tip] High Confidence
> Confirmed by [person] ([team]) in #{channel}, YYYY-MM-DD

**Services**: `svc-experiences`, `svc-order`
**Tags**: #business-rules/providers #provider/rezdy

### Rule

[Clear, factual statement. NOT a conversation summary.]

### Context

[Why this matters. What goes wrong if you don't know this.]

### Technical Detail

[How it works in code, if known. File paths, endpoints.]
```

### Confidence level callouts

Use these callouts based on confidence:

- **High**: `> [!tip] High Confidence` (green, confirmed by domain expert)
- **Medium**: `> [!warning] Medium Confidence` (orange, discussed but not fully confirmed)
- **Pending**: `> [!question] Pending` (yellow, question asked, awaiting answer)

## Routing

Each rule is saved as an individual file inside the domain folder:

| Domain | Folder |
|---|---|
| Checkout/booking flow | `Knowledge-Base/Business-Rules/Checkout/` |
| Provider behavior | `Knowledge-Base/Business-Rules/Providers/` |
| Refund/cancellation | `Knowledge-Base/Business-Rules/Refunds/` |
| Promo/discount | `Knowledge-Base/Business-Rules/Promos/` |
| Order lifecycle | `Knowledge-Base/Business-Rules/Orders/` |
| Search/discovery | `Knowledge-Base/Business-Rules/Search/` |
| White Label/LED | `Knowledge-Base/Business-Rules/WhiteLabel/` |
| Admin/ops processes | `Knowledge-Base/Business-Rules/Operations/` |
| General/other | `Knowledge-Base/Business-Rules/General/` |

**File naming**: kebab-case of the rule title, max 60 chars. Example: `checkout-fields-dynamic-per-offer.md`

**One rule per file**. Never append multiple rules to the same file. If a rule already exists (grep by title), update it instead of creating a duplicate.

## Integration with Development Workflow

Business Rules are checked automatically:
- `04-study-before-starting.md` Phase 1.5 reads `Business-Rules/` before any implementation
- `/feature-dev` Phase 2 includes Business Rules in the discovery checklist
- `/code-review` D7 (Consistency) checks if implementation violates known business rules

## Rules

- Read the FULL thread before extracting (answers may come later in the thread)
- Write rules as facts, not conversation summaries
- Attribute to the person who CONFIRMED, not who asked
- Never save PII (customer IDs, order amounts, emails)
- Pending items are valuable: they flag knowledge gaps
- Sweep deduplicates against existing KB: no duplicate entries
- Sweep uses `.last-sweep` timestamp to only process new messages
- Maximum 5 parallel agents per sweep batch

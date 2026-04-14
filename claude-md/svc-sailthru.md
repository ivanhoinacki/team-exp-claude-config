# Service Dossier: svc-sailthru

## Purpose
Email delivery service. API wrapper over email providers (Sailthru/SendGrid/Salesforce Marketing Cloud) for composing and sending transactional emails across LE platform.

## Architecture
- Layers: routes (domain-based) → controllers/ → lib/ (template rendering, formatters) → models/
- Validation: Strummer v2.10 + Zod v4.1 (via @luxuryescapes/router abstraction)
- ORM: Sequelize 6 (single model: Notification, stores template params as JSONB)
- DB: PostgreSQL (optional, for notification tracking)
- Email rendering: React Email v19 + Handlebars templates
- Auth: lib-auth-middleware v3 (role-based: admin, employee, service)
- APM: Datadog (dd-trace)
- Node: 22.20.0 | Scripts: yarn dev, yarn build, yarn test, yarn db:migrate

## Route Domains
- /travel: package/booking emails, cancellations, payment notifications
- /agentHub: agent commissions, applications, order confirmations
- /experiences: experience bookings, reminders, vendor communications
- /vendor: vendor-facing notifications
- /logging: logging webhooks
- /reactEmail: React Email template previews
- /views: server-rendered HTML views

## Pre-flight (verify BEFORE implementing)
- [ ] Email template: React Email or Handlebars? (new templates should use React Email)
- [ ] Notification suppression: filter with === true before sending (undefined/null = do not send)
- [ ] Correct role middleware on route? (requires-admin vs requires-service)
- [ ] CORS headers include necessary headers?
- [ ] Template preview works via react-email:dev?

## Knowledge Base & Tools (check BEFORE coding)
**MANDATORY**: Call `query_vault` BEFORE reading code, attempting fixes, or starting any investigation.

- **Vault RAG (ALWAYS FIRST)**: `query_vault(query="<keywords>", service_filter="svc-sailthru")`, pitfalls, review-learnings, business rules, runbooks indexed from the team vault
- **Ext. library docs**: Context7 MCP, `resolve-library-id("sequelize")` then `query-docs` for up-to-date API docs
- **Slack**: `slack_search_public_and_private(query="<error or topic>")`, past team discussions, incident threads
- **Jira**: `jira_get_issue(issue_key="EXP-XXXX")`, ticket context, acceptance criteria, linked issues
- **Confluence**: `confluence_search(query="<topic>")`, internal docs, architecture, runbooks
- **Datadog**: `search_datadog_logs(query="service:svc-sailthru <error>")`, prod logs, traces
- **GitHub**: `gh pr list --search "<query>" --repo user/repo` via Bash, past PRs, review discussions

## Pitfalls
- Notification suppression: === true guard (common pitfall, undefined/null must NOT send)
- React Email templates: use yarn react-email:dev for local preview
- Handlebars templates: copied on build (yarn build includes template copy step)
- Dual validation: Strummer (legacy routes) + Zod (newer routes via router)
- Health check at /api/notify (includes Postgres adapter check)
- Debug mode on port 7086 (yarn dev:inspect)

## Email Template Layout Validation (MANDATORY when touching HTML/React Email templates)

When ANY change touches email templates (React Email in src/reactEmail/, Handlebars in templates/, or inline HTML), use frontend layout MCP tools to validate rendering:

### Workflow
```
1. Start template preview: yarn react-email:dev (React Email) or render via /views route (Handlebars)
2. Playwright: browser_navigate → preview URL
3. Playwright: browser_take_screenshot at 3 widths:
   - Mobile email: browser_resize(375, 812)
   - Desktop email: browser_resize(600, 900)  (standard email max-width)
   - Wide client: browser_resize(1440, 900)   (Gmail/Outlook desktop)
4. chrome-devtools: get_computed_styles on key elements (spacing, fonts, colors)
5. If Figma/design exists: imugi_compare for pixel-perfect check
```

### Email-specific rules
- Email HTML uses `<table>` layout (not flexbox/grid). Validate table structure, not CSS layout
- Inline styles only (no external stylesheets in email). Check `style=` attributes
- Test with dark mode consideration: background colors, text contrast
- Sailthru variables `{*var*}` must not break layout when empty or very long
- Max-width 600px is standard. Content must not overflow on mobile (375px)

## Patterns
- New email template: React Email (src/reactEmail/) preferred over Handlebars
- Template with data: controller fetches data → formats via lib/ utils → renders template
- Multi-tenant: region mapping in lib/ determines locale/brand-specific content
- Background sending: jobs/ for async email delivery

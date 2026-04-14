# Service Dossier: www-le-customer

> **Code conventions, i18n workflow, testing, PR guidelines**: see AGENTS.md (team-maintained)

## Architecture
- Stack: React 19, TypeScript 5.9, Redux Toolkit + XState, React Query v4, styled-components
- Build: Webpack 5, SSR (Express server), i18n via react-intl/formatjs
- UI: LuxKit (internal design system in src/LuxKit/, 72+ components)
- Routing: React Router v5, Checkout: src/checkout/ per-vertical cart utils
- Node: 24.14.0 (Yarn 4.9) | Scripts: yarn dev, yarn build, yarn test

## Pre-flight (verify BEFORE implementing)
- [ ] transactionKey stable? (do not regenerate on each cart update, use cartItem?.transactionKey || uuidV4())
- [ ] ICU FormattedMessage with optional fields? (compute greeting first, not inline placeholder)
- [ ] Cart utils per vertical correct? (src/checkout/lib/utils/{vertical}/cart.ts)
- [ ] reCAPTCHA bypass configured for local tests? (3-layer: window mock, script intercept, fetch intercept)
- [ ] Test email uses @luxuryescapes.com? (ZeroBounce rejects others in staging)
- [ ] i18n: ran eslint --fix (generates hashes) + yarn i18n:extract before committing?
- [ ] LuxKit changes? Requires approval from Design System team (#team-luxkit)

## Pitfalls (condensed, full detail: pitfalls-frontend.md + pitfalls-orders.md)
- transactionKey: uuidV4() volatile in generateExperienceCheckoutItem (cart.ts L64). Fix: reuse existing
- flights/cart.ts:246 same issue: generateFlightCheckoutItem always generates new transactionKey
- F5 (refresh) clears promo from Redux state. NOT a valid trigger for testing BUG-2
- Valid triggers for transactionKey mismatch: change date or quantity (regenerates cart item without clearing promo)
- "Invalid email" on signup is ZeroBounce, not reCAPTCHA. Fix: use @luxuryescapes.com
- reCAPTCHA localhost: 3 layers (window.grecaptcha mock + script intercept + fetch intercept)
- iCloud Passwords extension blocks Chrome browser automation. Disable before testing
- ICU FormattedMessage: {firstName} empty = ", we've sent you...". Compute greeting separately
- Cold-start: yarn dev returns 500 until Webpack client build generates browser-stats.json. Restart server after first build

## Knowledge Base & Tools (check BEFORE coding)
**MANDATORY**: Call `query_vault` BEFORE reading code, attempting fixes, or starting any investigation.

- **Vault RAG (ALWAYS FIRST)**: `query_vault(query="<keywords>", service_filter="www-le-customer")` — pitfalls, review-learnings, business rules, runbooks indexed from the team vault
- **Ext. library docs**: Context7 MCP — `resolve-library-id("react")` then `query-docs` for up-to-date API docs
- **Slack**: `slack_search_public_and_private(query="<error or topic>")` — past team discussions, incident threads
- **Jira**: `jira_get_issue(issue_key="EXP-XXXX")` — ticket context, acceptance criteria, linked issues
- **Confluence**: `confluence_search(query="<topic>")` — internal docs, architecture, runbooks
- **Datadog**: `search_datadog_logs(query="service:www-le-customer <error>")` — prod logs, traces
- **GitHub**: `gh pr list --search "<query>" --repo user/repo` via Bash — past PRs, review discussions

## Business Rules
- MyEscapes "Add an experience" creates SEPARATE order (does not use appendItems API)
- Promo code: F5 clears from Redux, but cart update preserves. Vertical-specific cart utils regenerate items
- ZeroBounce whitelist staging: @luxgroup.com, @luxuryescapes.com, @luxuryescapesautomatede2edomain.com
- transactionKey must be stable across entire chain: svc-promo → frontend → svc-order → DB
- LuxKit changes require approval from Design System team via #team-luxkit on Slack
- CurrencyContext to access currency info (not prop drilling)

## Patterns
- Cart item generation: always preserve transactionKey from existing cartItem
- i18n: compute optional fields before passing to FormattedMessage. Run eslint --fix + yarn i18n:extract
- Testing auth: header-based mock (x-test-user-id, x-test-roles) after lib-auth-middleware v3
- Checkout flow: modular per-vertical cart utils in src/checkout/lib/utils/

## Frontend Layout Validation (MANDATORY when touching CSS/HTML/styled-components)

When ANY change touches visual layout (CSS, styled-components, HTML structure, LuxKit components, responsive breakpoints), use the frontend layout MCP tools to validate:

### Tool chain

| Tool | Purpose | When to use |
|---|---|---|
| **Playwright MCP** | Screenshots at multiple viewports (mobile 375px, tablet 768px, desktop 1440px) | ALWAYS for layout changes |
| **chrome-devtools MCP** | Inspect computed styles, box model, matched CSS rules, media queries | When debugging CSS issues or reviewing layout correctness |
| **imugi MCP** | Compare Figma design vs actual output (SSIM + heatmap + spec diff) | When a Figma link exists in the ticket |

### Validation workflow

```
1. Start dev server (yarn dev, wait for browser-stats.json)
2. Playwright: browser_navigate → page URL
3. Playwright: browser_take_screenshot at 3 viewports (375, 768, 1440)
4. If Figma link exists:
   a. imugi: imugi_figma_export → export design frame as PNG
   b. imugi: imugi_compare → design vs screenshot → heatmap + score
   c. If score < 95%: imugi_iterate (auto-correct loop)
5. chrome-devtools: get_computed_styles + get_element_box_model on key elements
6. Verify: spacing, font sizes, colors, responsive breakpoints match design
```

### LuxKit-specific rules
- LuxKit components (src/LuxKit/) have their own styles. Check LuxKit source before overriding
- styled-components: prefer extending LuxKit components over raw HTML + styled
- Responsive: LuxKit uses breakpoint mixins. Use them instead of raw media queries
- CurrencyContext for currency formatting (not manual formatting in styled-components)

## Setup (non-obvious)
- Node 24.14.0 via nvm (different from other services)
- Yarn 4.9 (not Yarn 1.x). Use corepack enable && corepack prepare
- NPM_TOKEN required for @lux-group/* private packages
- SSR enabled by default, disable with REACT_APP_SSR_DISABLED
- LuxKit is internal: src/LuxKit/ (not an npm package)

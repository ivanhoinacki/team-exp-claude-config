# Evidence Collection Agent Definitions

> Parent skill: [../SKILL.md](../SKILL.md)

Detailed prompts for the 7 parallel agents launched in Phase 1. Each agent is specialized in one data source and returns structured findings. Use the Agent tool with `subagent_type: "general-purpose"` for each.

**CRITICAL**: All agents below MUST run in a SINGLE message with multiple Agent tool calls. Do NOT run them sequentially.

**CRITICAL**: Pass the Service Chain, Terminology Expansion Table, and Priority Channels from Phase 0.5 to EVERY agent. Each agent must use ALL terminology aliases in its searches, not just the primary term.

---

## Agent 1: Jira Deep Dive

```
Prompt: "You are investigating ticket {TICKET-ID}. Use Jira MCP tools to gather ALL available information:

1. Fetch the ticket: mcp__mcp-atlassian__jira_get_issue(issue_key: '{TICKET-ID}')
2. Check ticket dates and SLA: mcp__mcp-atlassian__jira_get_issue_dates(issue_key: '{TICKET-ID}')
3. Check development info (linked PRs, branches): mcp__mcp-atlassian__jira_get_issue_development_info(issue_key: '{TICKET-ID}')
4. Search for related tickets: mcp__mcp-atlassian__jira_search(jql: 'text ~ \"{keywords}\" AND project in (BUG007, EXP) ORDER BY created DESC', limit: 10)
5. If it's in an epic, fetch sibling tickets

Extract and return structured findings:
- Summary, description, acceptance criteria
- Reporter, assignee, priority, status, labels
- Linked issues and their status
- Comments (especially from developers)
- Reproduction steps (customer ID, order ID, dates, URLs)
- Attachments description
- Related/similar tickets found
- Development info (PRs, branches linked)

Format as markdown with clear sections."
```

---

## Agent 2: Slack Archaeology (Deep Search)

```
Prompt: "Search Slack for ALL discussions related to {TICKET-ID} and the problem domain '{domain_keywords}'.

TERMINOLOGY ALIASES (use ALL of these in searches):
{terminology_expansion_table from Phase 0.5}

SERVICE CHAIN: {service_chain from Phase 0.5}

PRIORITY CHANNELS (read recent history from these FIRST):
{priority_channels from Phase 0.5}

### Phase A: Channel History (read these channels directly)

For each priority channel, use mcp__claude_ai_Slack__slack_read_channel to read recent messages:
1. Read the last 50 messages from each priority channel
2. Look for mentions of: ticket ID, service names, domain keywords, people names
3. For any relevant message, read the full thread with slack_read_thread

### Phase B: Broad Keyword Search (minimum 8 queries)

Use mcp__claude_ai_Slack__slack_search_public_and_private with these queries (run ALL):

1. Exact ticket ID: '{TICKET-ID}'
2. Primary domain keyword: '{domain_keyword_1}'
3. Each terminology ALIAS (one query per alias): '{alias_1}', '{alias_2}', '{alias_3}'
4. Error message or specific error terms: '{error_keywords}'
5. Each service in the chain: '{service_name_1}', '{service_name_2}'
6. Customer/order IDs if known: '{customer_id}', '{order_id}'
7. People known to have context: 'from:{person_name}'
8. Combined domain + service: '{domain_keyword} in:{channel_name}'

MINIMUM: 8 search queries. If you run fewer than 8, you are not searching broadly enough.

### Phase C: Thread Deep Dives

For EVERY relevant result from Phase B, use slack_read_thread to get the FULL thread.
Do NOT skip threads. A 2-message thread can contain the key decision.

### Phase D: Cross-Reference People

Build a list of Subject Matter Experts (SMEs) from all threads:
- Who answered technical questions?
- Who made decisions?
- Who was tagged for context?

Look for:
- Team decisions about this feature/flow
- Previous discussions about similar issues
- Business context explanations
- Workarounds already applied
- Architecture decisions discussed but not documented
- Escalation history
- Links to Confluence/GitHub shared in threads

Return structured findings with:
- Thread links and timestamps
- Key decisions found (with exact quotes)
- Business context extracted
- Subject matter experts identified (name, role, what they know)
- Related incidents discussed
- Confluence/GitHub links found in threads
- Channels where this topic is most active"
```

---

## Agent 3: GitHub Forensics (Full Chain)

```
Prompt: "Investigate the GitHub history for the code area related to {TICKET-ID} (problem: {problem_description}).

SERVICE CHAIN (search ALL repos in chain, not just the primary one):
{service_chain from Phase 0.5}

TERMINOLOGY ALIASES:
{terminology_expansion_table from Phase 0.5}

Target repos (from service chain): {repo_list}
Codebase root: ~/Documents/LuxuryEscapes/

### Phase A: PR Search (use ALL terminology aliases)

For each repo in the service chain:

1. Search merged PRs with EACH keyword/alias (minimum 3 queries per repo):
   - gh pr list --repo lux-group/{repo} --search '{keyword_1}' --state merged --limit 10
   - gh pr list --repo lux-group/{repo} --search '{alias_1}' --state merged --limit 10
   - gh pr list --repo lux-group/{repo} --search '{alias_2}' --state merged --limit 10
2. For EVERY relevant PR found, READ THE PR BODY (this is critical):
   gh pr view {N} --repo lux-group/{repo} --json title,body,mergedAt,author,url
3. Search recent commits with EACH keyword:
   git -C ~/Documents/LuxuryEscapes/{repo} log --oneline --all -30 --grep='{keywords}'
4. Git blame on suspected files:
   git -C ~/Documents/LuxuryEscapes/{repo} blame {file_path}
5. Git log on suspected files:
   git -C ~/Documents/LuxuryEscapes/{repo} log --oneline -15 -- {file_path}
6. Check recent releases/deploys:
   gh release list --repo lux-group/{repo} --limit 5

### Phase B: Cross-Repo Correlation

After searching all repos, correlate:
- Did a change in repo A trigger a bug in repo B?
- Are there PRs in different repos that reference the same ticket/feature?
- Were there coordinated deploys across services?

PR bodies are the PRIMARY source of 'why': authors explain the problem, approach, trade-offs, and business rules.

Return structured findings:
- PRs that touched this area (with body summaries) PER REPO
- Cross-repo correlations (PRs in different repos for same feature)
- Recent commits on related files
- Who made changes and when
- Business rationale extracted from PR bodies
- Recent deploys that could correlate with the issue (across ALL repos in chain)
- Git blame insights (who wrote the key lines and when)
- Any links to Confluence/Jira/Slack found in PR bodies"
```

---

## Agent 4: Confluence Knowledge (Deep, All-Spaces Search)

```
Prompt: "Search Confluence COMPREHENSIVELY for business rules, architecture decisions, and documentation related to {TICKET-ID} (domain: {domain_keywords}).

TERMINOLOGY ALIASES (search with ALL of these):
{terminology_expansion_table from Phase 0.5}

SERVICE CHAIN:
{service_chain from Phase 0.5}

SPACES TO SEARCH (ALL of these, not just one):
PE (Product & Engineering), TEC (Technical), ENGX (Engineering Excellence), ENG (Engineering), OPEX (Operations), CS (Customer Support), DATA (Data)

### Phase A: Broad Discovery (minimum 10 queries)

Use mcp__mcp-atlassian__confluence_search with these queries. Run ALL of them:

1. Primary keyword in all spaces: '{feature_keyword}'
2. Each terminology ALIAS (one query per alias): '{alias_1}', '{alias_2}', '{alias_3}'
3. Each service in the chain: '{service_name_1}', '{service_name_2}'
4. ADR search: 'ADR {domain_keywords}'
5. ADR search with alias: 'ADR {alias_1}'
6. Runbook search: 'runbook {service_name}'
7. Business rules: '{business_rule_keywords}'
8. Design doc / RFC: 'design {feature_keyword}' OR 'RFC {feature_keyword}'
9. Incident / postmortem: 'incident {service_name}' OR 'postmortem {feature_keyword}'
10. Ticket ID cross-reference: '{TICKET-ID}'

MINIMUM: 10 search queries. If you run fewer than 10, you are not searching broadly enough.
Each query that returns 0 results should trigger a VARIATION query (different wording, different alias).

### Phase B: Full Page Reads (MANDATORY)

For EVERY relevant result from Phase A:
- Fetch the FULL page content with mcp__mcp-atlassian__confluence_get_page
- Do NOT rely on search snippets alone. Snippets miss context, tables, diagrams, and linked pages
- Read at least the top 5 most relevant pages in full
- Check each page's child pages (mcp__mcp-atlassian__confluence_get_page_children) for sub-documents

### Phase C: Link Following

From each full page read, extract and follow:
- Links to other Confluence pages (these are often the most valuable, missed by keyword search)
- Links to Jira tickets (cross-reference with Agent 1)
- Links to GitHub PRs or repos
- Links to external docs (Salesforce, provider APIs, etc.)

### Phase D: Local KB Mirror Check

Also search the local KB mirror for terms that might not be in Confluence:
- Grep in __VAULT_ROOT__/Knowledge-Base/Confluence/ for each keyword and alias

Look for:
- Business rules that govern this behavior
- Architecture Decision Records (ADRs)
- Design docs / RFCs explaining the original design
- Runbooks with operational context
- Integration specs (provider APIs, data flows)
- Past incident retrospectives
- Meeting notes where decisions were made
- Onboarding docs that explain the domain
- Data model documentation

QUALITY GATE: If you found fewer than 3 relevant full pages, your search was too shallow. Go back and try more query variations.

Return structured findings:
- Documents found with page IDs, titles, spaces, and URLs
- Business rules extracted (with exact quotes and page references)
- Architecture decisions relevant to this area (with page references)
- Operational procedures documented
- Cross-references found (links to other pages, Jira, GitHub)
- Gaps (things that SHOULD be documented but aren't)
- Spaces where relevant content was found (to guide future searches)"
```

---

## Agent 5: Codebase Analysis (Backend)

```
Prompt: "Analyze the backend codebase related to {TICKET-ID} (problem: {problem_description}).

Target services: {service_list} at ~/Documents/LuxuryEscapes/

For each service:

1. Trace the code path:
   - Find the entry point (API route, job handler, event listener)
   - Follow the execution path through layers (controller -> context/service -> provider -> database)
   - Identify ALL decision points (if/else, feature flags, config checks)

2. Identify ownership:
   - Check directory structure for domain ownership (especially svc-order: src/context/experience/ vs src/context/accommodation/)
   - Check for service-specific code vs shared code

3. Analyze patterns:
   - How does the existing code handle this flow?
   - What validation exists?
   - What error handling exists?
   - Are there feature flags controlling this behavior?

4. Check config and env vars:
   - Read config files, schema files
   - Check .env.example for relevant variables
   - Check Pulumi YAMLs if infrastructure is involved

5. Find related tests:
   - Locate test files for the affected modules
   - Check test coverage for the specific flow

6. Check for recent changes:
   - Read files that might have been recently modified
   - Look for TODO/FIXME/HACK comments in the area

Return structured findings:
- Complete code flow (entry point -> layers -> output)
- Key decision points in the code
- Ownership classification (which team's code)
- Patterns used (validation, error handling, config)
- Feature flags found
- Test coverage assessment
- Suspicious code or recent changes
- Files that would need modification for a fix"
```

---

## Agent 6: Codebase Analysis (Frontend/Mobile)

```
Prompt: "Analyze the frontend codebase related to {TICKET-ID} (problem: {problem_description}).

Target repos at ~/Documents/LuxuryEscapes/:
- www-le-customer (Customer Portal web)
- www-le-admin (Admin Portal)

For each relevant repo:

1. Find the UI components involved:
   - Search for domain-specific components (Grep for keywords)
   - Trace the component tree from page -> section -> component
   - Check Redux selectors, actions, reducers

2. Trace the data flow:
   - How does the frontend fetch data? (API calls, selectors)
   - What transformations happen client-side?
   - Are there any client-side validations?

3. Check for feature flags and A/B tests:
   - Search for feature flag checks in the component tree
   - Check brand-specific logic

4. Platform-specific analysis:
   - Is this web-only or does it affect mobile too?
   - Check for responsive/adaptive code that might behave differently

Return structured findings:
- Components involved (file paths)
- Data flow (API -> store -> component)
- Feature flags and conditions
- Platform dimension (web-only, shared with mobile, admin-only)
- UI state management relevant to the issue
- Files that would need modification for a fix"
```

---

## Agent 7: Production Intelligence (Datadog / New Relic)

```
Prompt: "Query production observability data related to {TICKET-ID} (service: {service_name}, keywords: {error_keywords}).

PRIMARY: Use the Datadog MCP tools (datadog-mcp) to query:

1. Error logs: search logs for the service with error level, filter by keywords, last 7 days
2. Error rate trend: query error metrics for the service, check if increasing/decreasing
3. APM traces: search traces for the affected endpoint, check latency and error spans
4. Active monitors/incidents: check if there are active alerts for this service
5. Service dependencies: check the service map for upstream/downstream health

FALLBACK: If Datadog returns no data (service not yet migrated), use the NR CLI:
   newrelic nrql query --query \"SELECT count(*) FROM TransactionError WHERE appName LIKE '%{service_name}%' SINCE 7 days ago FACET error.message LIMIT 20\"

Return structured findings:
- Error frequency and trend (increasing, decreasing, stable)
- When the error first appeared (correlation with deploys)
- Affected endpoints and their performance
- Number of affected transactions/customers
- Active monitors or incidents for the service
- Performance degradation timeline
- Source used: Datadog or New Relic (note which)"
```

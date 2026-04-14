# Evidence Collection Patterns

Companion doc for [SKILL.md](../SKILL.md). Patterns for collecting runtime evidence during debugging.

## Datadog Queries (Primary)

### Log Search
Use `mcp__datadog-mcp__search_datadog_logs` with:
- `service:<svc-name>` + `status:error` for error logs
- `@http.status_code:5*` for 5xx responses
- `@error.message:"<error text>"` for specific errors
- Time range: start from last 1h, expand if needed

### Trace Search
Use `mcp__datadog-mcp__search_datadog_spans` with:
- `service:<svc-name>` + `resource_name:<endpoint>`
- `@duration:>1000000000` for slow traces (>1s in nanoseconds)
- `status:error` for error traces

### Metric Query
Use `mcp__datadog-mcp__get_datadog_metric` with:
- `avg:trace.express.request.duration{service:<svc>}` for latency
- `sum:trace.express.request.errors{service:<svc>}` for error rate

## New Relic Queries (Fallback)

### NRQL via CLI
```bash
newrelic nrql query --accountId 2826932 --query "SELECT * FROM TransactionError WHERE appName = '<env>-<svc>-main' SINCE 1 hour ago LIMIT 20"
```

## Browser Console (via debug-server.js)

### Setup
```bash
node ~/.claude/skills/debug-mode/scripts/debug-server.js &
```
Then in browser console: `fetch('http://localhost:9222/log', { method: 'POST', body: JSON.stringify({ level: 'info', message: 'test', data: {} }) })`

### Read Logs
Use `mcp__claude-in-chrome__read_console_messages` or read the debug server output file.

## Codebase Evidence

### Git blame for suspicious code
```bash
git log --oneline --all -10 -- path/to/file
git blame -L start,end path/to/file
```

### Recent changes to area
```bash
git log --oneline --since="2 weeks ago" -- src/path/
```

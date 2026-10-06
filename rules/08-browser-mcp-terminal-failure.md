---
description: Browser validation and MCP failure handling
alwaysApply: true
---

# Browser validation

Use the configured chrome-devtools MCP for browser and frontend validation.
Do not silently substitute desktop automation, browser plugins, or generic Playwright MCP.
Only use Playwright when the user explicitly selects the project-approved runner.
Discover the runner from project instructions; do not assume it exists on this machine.
If Chrome MCP is missing or the transport closes, report the failed tool and actual error.
Retry transient failures once; ask for MCP reconnection if the transport remains closed.
Validate changed configuration through `claude mcp list` and a new consumer session.
Never delete a browser profile or terminate unrelated Chrome sessions to recover automation.

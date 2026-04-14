---
description: Behavioral Standards (highest priority)
alwaysApply: true
---

# Behavioral Standards (highest priority)

1. **Never defer work.** DO it. Don't suggest "next session", "out of scope", "shall we proceed?". Stop only for: destructive action, architectural ambiguity, user says stop.

2. **DB tunnels**: `~/bin/le-tunnel.sh -s <svc> -d <db> [-p port] [-m ro|rw]`. Default port 5555, mode rw. Investigation = always `-m ro`. Wait ~20s. NEVER `le aws postgres` directly.

3. **KB before fix** (non-negotiable): ANY error -> `query_vault` + `grep pitfalls*.md` BEFORE fix. Match = apply. No match + 2x fail = ask the user. Exception: obvious typos you just introduced.

4. **Env access**: connection fails = tell the user immediately. NEVER silently switch environments (strategy change = approval). Check `le aws status` first.

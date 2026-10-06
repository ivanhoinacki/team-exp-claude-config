#!/usr/bin/env python3
"""Portable Codex guards and scoped context without credential dependencies."""
import datetime
import json
import os
from pathlib import Path
import re
import shlex
import sys

ROOT = Path(__file__).resolve().parents[1]


def context(event, text):
    return {'hookSpecificOutput': {'hookEventName': event, 'additionalContext': text}}


def command_guards(command):
    try:
        tokens = shlex.split(command)
    except ValueError:
        return ''
    for index, token in enumerate(tokens):
        if Path(token).name != 'git':
            continue
        args = tokens[index + 1:]
        while args and args[0] in ('-C', '-c', '--git-dir', '--work-tree'):
            args = args[2:]
        if not args:
            continue
        action, rest = args[0], args[1:]
        if action == 'add' and any(x in ('.', '-A', '--all') for x in rest):
            return 'Stage explicit file paths. Broad git add is blocked.'
        if action == 'reset' and '--hard' in rest:
            return 'Destructive reset is blocked. Preserve local work.'
        if action == 'checkout' and rest and rest[0] == '.':
            return 'Discarding all local edits is blocked.'
        if action == 'push' and any(x in ('--force', '-f') for x in rest):
            return 'Bare force push is blocked.'
    return ''


def domain_context(data):
    configs = [ROOT / 'config/domain-context.json']
    cwd = Path(data.get('cwd') or '.').resolve()
    for directory in (cwd, *cwd.parents):
        candidate = directory / '.codex/domain-context.json'
        if candidate.is_file():
            configs.append(candidate)
            break
    prompt = data.get('prompt') or data.get('user_prompt') or ''
    messages = []
    for file in configs:
        if not file.is_file():
            continue
        config = json.loads(file.read_text())
        for key in ('domains', 'prompt_rules', 'cwd_prompt_rules'):
            for rule in config.get(key, []):
                pattern = rule.get('prompt_pattern') or rule.get('pattern')
                cwd_pattern = rule.get('cwd_pattern')
                if pattern and rule.get('message') and re.search(pattern, prompt, re.I):
                    if not cwd_pattern or re.search(cwd_pattern, str(cwd), re.I):
                        messages.append(rule['message'])
    return '\n'.join(messages)


def handle(data):
    event = data.get('hook_event_name', '')
    if event == 'SessionStart':
        return context(event, 'Read global and project AGENTS.md. Use project-scoped context and relevant skills. Preserve existing user changes and report runtime evidence.')
    if event == 'UserPromptSubmit':
        text = domain_context(data)
        return context(event, text) if text else {}
    if event == 'PreToolUse':
        tool = data.get('tool_name', '')
        tool_input = data.get('tool_input') or {}
        if isinstance(tool_input, str):
            try:
                tool_input = json.loads(tool_input)
            except ValueError:
                tool_input = {'command': tool_input}
        command = tool_input.get('command') or tool_input.get('cmd') or ''
        reason = command_guards(command) if tool in ('Bash', 'exec_command') else ''
        if reason:
            return {'hookSpecificOutput': {'hookEventName': event, 'permissionDecision': 'deny', 'permissionDecisionReason': reason}}
        messages = []
        if tool in ('Edit', 'Write', 'apply_patch'):
            messages.append('Preserve unrelated edits. Revalidate ownership in coordinated rooms. Verify changes through the consumer; frontend validation uses chrome-devtools.')
        if 'playwright' in tool.lower() or re.search(r'\bnpx\s+(?:-y\s+)?(?:@playwright/mcp|playwright)\b', command):
            messages.append('Playwright requires explicit user selection and the configured project runner. Chrome DevTools is the default browser path.')
        if tool == 'spawn_agent' or tool == 'Agent':
            messages.append('Respect the selected agent role and inherited model; override only for explicit user instructions or project policy.')
        return context(event, '\n'.join(messages)) if messages else {}
    if event == 'PreCompact':
        return context(event, 'Keep compact state under 40 lines: task, worktree, ownership, modified files, errors, decisions, last handoff sequence and next action. Detailed evidence belongs in the project artifact.')
    if event == 'PostCompact':
        return context(event, 'Resume the same task. Re-read coordinated room messages since the last sequence before edits or decisions.')
    return {}


def log_metadata(data):
    directory = ROOT / 'logs'
    directory.mkdir(mode=0o700, exist_ok=True)
    record = {'time': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'event': data.get('hook_event_name', ''),
              'tool': data.get('tool_name', '')}
    path = directory / 'team-hook-events.jsonl'
    descriptor = os.open(path, os.O_CREAT | os.O_APPEND | os.O_WRONLY, 0o600)
    with os.fdopen(descriptor, 'a') as stream:
        stream.write(json.dumps(record) + '\n')


def main():
    try:
        data = json.load(sys.stdin)
        if not isinstance(data, dict):
            raise ValueError('Hook input must be an object.')
        output = handle(data)
        log_metadata(data)
    except (OSError, ValueError, TypeError, re.error) as error:
        print('Portable hook failed: ' + type(error).__name__, file=sys.stderr)
        raise SystemExit(1)
    print(json.dumps(output))


if __name__ == '__main__':
    main()

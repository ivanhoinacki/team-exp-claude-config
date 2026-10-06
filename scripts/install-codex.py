#!/usr/bin/env python3
"""Install portable Codex settings while preserving authentication and local integrations."""
import argparse
import datetime
import getpass
import json
from pathlib import Path
import shlex
import shutil

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'codex'
BEGIN = '<!-- BEGIN TEAM CODEX CONFIG -->'
END = '<!-- END TEAM CODEX CONFIG -->'
LOCAL_REFERENCES = {'learnings.md', 'known-gotchas.md', 'local-infrastructure.md', 'channel-map.md'}


def render(content, replacements):
    try:
        text = content.decode('utf-8')
    except UnicodeDecodeError:
        return content
    for key, value in replacements.items():
        text = text.replace(key, value)
    return text.encode('utf-8')


def instruction_block(current, instructions):
    if BEGIN in current:
        if current.count(BEGIN) != 1 or current.count(END) != 1:
            raise SystemExit('Malformed managed block in AGENTS.md.')
        before, rest = current.split(BEGIN, 1)
        _, after = rest.split(END, 1)
    else:
        before, after = current.rstrip() + ('\n\n' if current.strip() else ''), ''
    return before + BEGIN + '\n' + instructions.rstrip() + '\n' + END + after + ('\n' if not after.endswith('\n') else '')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target-home', type=Path, default=Path.home())
    parser.add_argument('--codebase-root', type=Path)
    parser.add_argument('--vault-root', type=Path)
    parser.add_argument('--playwright-runner', type=Path)
    parser.add_argument('--user-name')
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    home = args.target_home.expanduser().resolve()
    codex = home / '.codex'
    receipt = codex / '.team-codex-config.json'
    saved = json.loads(receipt.read_text()) if receipt.is_file() else {}
    replacements = saved.get('replacements', {})
    values = {'__HOME__': home, '__CODEX_ROOT__': codex,
              '__CODEBASE_ROOT__': args.codebase_root or replacements.get('__CODEBASE_ROOT__') or home / 'work',
              '__VAULT_ROOT__': args.vault_root or replacements.get('__VAULT_ROOT__') or home / 'Documents/Knowledge',
              '__PLAYWRIGHT_RUNNER__': args.playwright_runner or replacements.get('__PLAYWRIGHT_RUNNER__') or home / 'work/MCPs/playwright-runner'}
    replacements = {key: str(value) for key, value in values.items()}
    replacements['__USER_NAME__'] = args.user_name or saved.get('replacements', {}).get('__USER_NAME__') or getpass.getuser()
    replacements['__HOOK_SCRIPT__'] = shlex.quote(str(codex / 'hooks/team_hooks.py'))
    destinations = {}
    executable = set()
    for source in PACKAGE.rglob('*'):
        if not source.is_file() or any(part in {'__pycache__', 'logs'} for part in source.relative_to(PACKAGE).parts):
            continue
        relative = source.relative_to(PACKAGE)
        if str(relative) in ('manifest.json', 'hooks.json', 'AGENTS.md', 'config.toml'):
            continue
        dest = (home / '.agents' / relative) if relative.parts[0] == 'skills' else codex / relative
        if source.name in LOCAL_REFERENCES and dest.is_file():
            continue
        destinations[dest] = render(source.read_bytes(), replacements)
        if source.stat().st_mode & 0o111 or ('scripts' in relative.parts and source.suffix == '.sh'):
            executable.add(dest)
    instructions = render((PACKAGE / 'AGENTS.md').read_bytes(), replacements).decode()
    agents_path = codex / 'AGENTS.md'
    current = agents_path.read_text() if agents_path.is_file() else ''
    destinations[agents_path] = instruction_block(current, instructions).encode()
    config = render((PACKAGE / 'config.toml').read_bytes(), replacements)
    destinations[codex / 'company.config.toml'] = config
    if not (codex / 'config.toml').exists():
        destinations[codex / 'config.toml'] = config
    hook_path = codex / 'hooks.json'
    existing = json.loads(hook_path.read_text()) if hook_path.is_file() else {'hooks': {}}
    incoming = json.loads(render((PACKAGE / 'hooks.json').read_bytes(), replacements))
    events = existing.setdefault('hooks', {})
    for event, groups in incoming['hooks'].items():
        retained = []
        for group in events.get(event, []):
            handlers = [handler for handler in group.get('hooks', [])
                        if handler.get('command') != incoming['hooks'][event][0]['hooks'][0]['command']]
            if handlers:
                retained.append(dict(group, hooks=handlers))
        events[event] = retained + groups
    destinations[hook_path] = (json.dumps(existing, indent=2) + '\n').encode()
    if not (codex / 'config/domain-context.json').exists():
        destinations[codex / 'config/domain-context.json'] = b'{"domains": [], "prompt_rules": [], "cwd_prompt_rules": []}\n'

    # Check every destination before writing any file.
    for path in [*destinations, receipt]:
        for parent in [path, *path.parents]:
            if parent == home.parent:
                break
            if parent.is_symlink():
                raise SystemExit('Refusing symlink destination: ' + str(parent.relative_to(home)))
        if path.exists() and not path.is_file():
            raise SystemExit('Refusing non-regular destination: ' + str(path.relative_to(home)))
    if args.verify:
        if not receipt.is_file():
            raise SystemExit('No Codex installation receipt. Run the installer first.')
        for path, expected in destinations.items():
            if not path.is_file() or path.read_bytes() != expected:
                raise SystemExit('Different or missing: ' + str(path.relative_to(home)))
        print(f'Verified {len(destinations)} portable Codex files; local integrations preserved.')
        return
    backup = codex / 'backups' / ('team-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    changed = 0
    for path, expected in destinations.items():
        if path.is_file() and path.read_bytes() == expected:
            if path in executable:
                path.chmod(0o700)
            continue
        if path.exists():
            old = backup / path.relative_to(home)
            old.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, old)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(expected)
        path.chmod(0o700 if path in executable else 0o600)
        changed += 1
    manifest = json.loads((PACKAGE / 'manifest.json').read_text())
    receipt.write_text(json.dumps({'replacements': replacements, 'backup': str(backup),
                                 'manifest': manifest, 'files': sorted(str(p.relative_to(home)) for p in destinations)}, indent=2) + '\n')
    receipt.chmod(0o600)
    print(f'Installed {len(manifest["skills"])} skills, {len(manifest["agents"])} agents, {len(manifest["instructions"])} instruction rules; {changed} files changed.')
    if backup.exists():
        print('Backup: ' + str(backup))
    print('Start codex --profile company. Review the installed definitions in /hooks before relying on them.')


if __name__ == '__main__':
    main()

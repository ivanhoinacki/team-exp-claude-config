#!/usr/bin/env python3
"""Install reusable Claude instructions without modifying runtime credentials."""
import argparse
import datetime
import getpass
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent
ACTIVE = ('commit', 'create-pr', 'deslop', 'feature-dev', 'codereview',
          'thinking-partner', 'investigation', 'handoff')
PRIVATE_REFERENCES = {'learnings.md', 'known-gotchas.md'}
RETIRED_RULES = ('03-escalation-protocol.md', '08-behavioral-standards.md')


def payload():
    files = list((ROOT / 'rules').glob('[0-9]*.md'))
    files += [ROOT / 'agents' / (name + '.md')
              for name in ('copilot', 'researcher', 'implementer', 'reviewer')]
    for name in ACTIVE:
        files += [f for f in (ROOT / 'skills' / name).rglob('*.md')
                  if f.name not in PRIVATE_REFERENCES]
    return sorted(files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target-home', type=Path, default=Path.home())
    parser.add_argument('--codebase-root', type=Path)
    parser.add_argument('--vault-root', type=Path)
    parser.add_argument('--user-name')
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    home = args.target_home.expanduser().resolve()
    claude = home / '.claude'
    config_path = claude / '.team-config.json'
    config = json.loads(config_path.read_text()) if config_path.exists() else {}
    codebase = args.codebase_root or config.get('codebase_root') or home / 'Documents/Repositories'
    vault = args.vault_root or config.get('vault_root') or home / 'Documents/Knowledge'
    replacements = {'__HOME__': str(home), '__CODEBASE_ROOT__': str(codebase),
                    '__VAULT_ROOT__': str(vault),
                    '__USER_NAME__': args.user_name or config.get('user_full_name') or getpass.getuser()}
    if args.verify:
        saved = claude / '.portable-config.json'
        if not saved.exists():
            parser.error('No portable installation receipt found.')
        replacements = json.loads(saved.read_text())['replacements']
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup = claude / 'backups' / ('portable-' + stamp)
    installed = 0
    for source in payload():
        rel = source.relative_to(ROOT)
        dest = claude / rel
        text = source.read_text()
        for key, value in replacements.items():
            text = text.replace(key, value)
        if args.verify:
            if not dest.is_file() or dest.read_text() != text:
                raise SystemExit('Verification failed: ' + str(rel))
        elif not dest.is_file() or dest.read_text() != text:
            if dest.exists():
                if not dest.is_file() or dest.is_symlink():
                    raise SystemExit('Refusing to replace non-regular file: ' + str(dest))
                old = backup / rel
                old.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(dest, old)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(text)
        installed += 1
    if not args.verify:
        for name in RETIRED_RULES:
            old = claude / 'rules' / name
            if old.exists():
                archived = backup / 'rules' / name
                archived.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(old), str(archived))
        for name in ACTIVE:
            for filename in PRIVATE_REFERENCES:
                dest = claude / 'skills' / name / 'references' / filename
                if not dest.exists():
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_text('# Local knowledge\n\nAdd client-scoped entries on this machine.\n')
        (claude / 'contexts').mkdir(exist_ok=True)
        (claude / '.portable-config.json').write_text(json.dumps(
            {'replacements': replacements, 'active_skills': ACTIVE,
             'installed_files': installed, 'backup': str(backup)}, indent=2) + '\n')
    print(('Verified' if args.verify else 'Installed') +
          f': 16 rules, {len(ACTIVE)} active skills, 4 agents ({installed} instruction files).')
    if backup.exists():
        print('Backup: ' + str(backup))


if __name__ == '__main__':
    main()

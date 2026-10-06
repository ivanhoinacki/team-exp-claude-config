import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class PortableConfigTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'Company Home'
        self.cli = ['python3', str(ROOT / 'scripts/install-config.py'),
                    '--target-home', str(self.home), '--user-name', 'Company User',
                    '--codebase-root', str(self.home / 'Work Repos'),
                    '--vault-root', str(self.home / 'Company Vault')]

    def run_install(self, *flags):
        return subprocess.run(self.cli + list(flags), check=True,
                              capture_output=True, text=True)

    def test_install_and_verify(self):
        self.run_install()
        self.assertIn('Verified: 16 rules, 8 active skills, 4 agents',
                      self.run_install('--verify').stdout)
        self.assertEqual(16, len(list((self.home / '.claude/rules').glob('*.md'))))
        for file in (self.home / '.claude').rglob('SKILL.md'):
            self.assertNotIn('__VAULT_ROOT__', file.read_text())
            self.assertNotIn('/Users/ivanhoinacki', file.read_text())

    def test_preserves_runtime_and_local_knowledge(self):
        files = {'.claude/settings.json': '{"custom": true}',
                 '.claude.json': '{"mcpServers": {"company": {}}}',
                 '.claude/skills/codereview/references/learnings.md': 'Local findings',
                 '.claude/skills/codereview/references/known-gotchas.md': 'Local gotchas'}
        for rel, text in files.items():
            dest = self.home / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(text)
        self.run_install()
        self.run_install()
        for rel, text in files.items():
            self.assertEqual(text, (self.home / rel).read_text())

    def test_archives_old_rules_and_preserves_custom_rules(self):
        rules = self.home / '.claude/rules'
        rules.mkdir(parents=True)
        (rules / '03-escalation-protocol.md').write_text('Old package rule')
        (rules / 'company.md').write_text('Custom rule')
        self.run_install()
        self.assertFalse((rules / '03-escalation-protocol.md').exists())
        self.assertEqual('Custom rule', (rules / 'company.md').read_text())
        backups = list((self.home / '.claude/backups').glob('*/rules/03-escalation-protocol.md'))
        self.assertEqual('Old package rule', backups[0].read_text())

    def test_verification_detects_drift(self):
        self.run_install()
        (self.home / '.claude/rules/00-global-style.md').write_text('Changed')
        result = subprocess.run(self.cli + ['--verify'], capture_output=True, text=True)
        self.assertNotEqual(0, result.returncode)
        self.assertIn('Verification failed', result.stderr)

    def test_setup_wrappers_config_only(self):
        import os
        for name in ('setup.sh', 'setup-wsl.sh'):
            subprocess.run(['bash', str(ROOT / 'scripts' / name), '--config-only'],
                           env=dict(os.environ, CLAUDE_HOME=str(self.home)),
                           capture_output=True, check=True)
        self.assertFalse((self.home / '.claude/settings.json').exists())
        self.assertFalse((self.home / '.claude.json').exists())


if __name__ == '__main__':
    unittest.main()

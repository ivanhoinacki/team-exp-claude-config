import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/install-codex.py'
spec = importlib.util.spec_from_file_location('team_hooks', ROOT / 'codex/hooks/team_hooks.py')
hooks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hooks)


class CodexInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='codex config ')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home with spaces'
        self.codex = self.home / '.codex'
        self.codex.mkdir(parents=True)

    def run_install(self, *args):
        return subprocess.run(['python3', str(SCRIPT), '--target-home', str(self.home), *args],
                              text=True, capture_output=True)

    def test_preserves_existing_runtime_and_merges_once(self):
        config = 'model = "existing-model"\n[mcp_servers.local]\ncommand = "existing-tool"\n'
        (self.codex / 'config.toml').write_text(config)
        (self.codex / 'auth.json').write_text('{"fixture":"preserve"}')
        (self.codex / 'AGENTS.md').write_text('Existing instructions\n')
        original_hook = {'type': 'command', 'command': 'echo local'}
        (self.codex / 'hooks.json').write_text(json.dumps({'hooks': {'SessionStart': [{'hooks': [original_hook]}]}}))
        self.assertEqual(self.run_install().returncode, 0)
        self.assertEqual(self.run_install().returncode, 0)
        self.assertEqual((self.codex / 'config.toml').read_text(), config)
        self.assertEqual((self.codex / 'auth.json').read_text(), '{"fixture":"preserve"}')
        self.assertEqual((self.codex / 'AGENTS.md').read_text().count('BEGIN TEAM CODEX CONFIG'), 1)
        self.assertTrue((self.codex / 'AGENTS.md').read_text().startswith('Existing instructions'))
        groups = json.loads((self.codex / 'hooks.json').read_text())['hooks']['SessionStart']
        self.assertEqual(len(groups), 2)
        self.assertEqual(groups[0]['hooks'][0], original_hook)
        self.assertEqual(self.run_install('--verify').returncode, 0)
        script = self.home / '.agents/skills/figma-create-design-system-rules/scripts/check_agents_md.sh'
        self.assertTrue(script.stat().st_mode & 0o100)

    def test_backup_and_local_knowledge(self):
        skill = self.home / '.agents/skills/codereview/references/learnings.md'
        skill.parent.mkdir(parents=True)
        skill.write_text('Local knowledge\n')
        old = self.codex / 'company.config.toml'
        old.write_text('old preferences\n')
        self.assertEqual(self.run_install().returncode, 0)
        self.assertEqual(skill.read_text(), 'Local knowledge\n')
        copies = list((self.codex / 'backups').glob('team-*/.codex/company.config.toml'))
        self.assertEqual(len(copies), 1)
        self.assertEqual(copies[0].read_text(), 'old preferences\n')

    def test_verify_detects_drift(self):
        self.assertEqual(self.run_install().returncode, 0)
        file = self.home / '.agents/skills/commit/SKILL.md'
        file.write_text('modified\n')
        self.assertNotEqual(self.run_install('--verify').returncode, 0)
        self.assertEqual(file.read_text(), 'modified\n')

    def test_symlink_rejected_before_writes(self):
        external = Path(self.temp.name) / 'external'
        external.write_text('preserve\n')
        (self.codex / 'company.config.toml').symlink_to(external)
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertFalse((self.codex / 'AGENTS.md').exists())
        self.assertEqual(external.read_text(), 'preserve\n')


class HookTests(unittest.TestCase):
    def test_command_guard(self):
        for cmd in ['git add .', 'git -C "/tmp/with spaces" reset --hard', 'git push -f origin main']:
            self.assertTrue(hooks.command_guards(cmd), cmd)
        for cmd in ['git add file.py', 'git diff', 'echo "git add ."', 'git push --force-with-lease']:
            self.assertFalse(hooks.command_guards(cmd), cmd)

    def test_native_pretool_input(self):
        result = hooks.handle({'hook_event_name': 'PreToolUse', 'tool_name': 'Bash',
                               'tool_input': {'command': 'git add .'}})
        self.assertEqual(result['hookSpecificOutput']['permissionDecision'], 'deny')
        result = hooks.handle({'hook_event_name': 'PreToolUse', 'tool_name': 'apply_patch',
                               'tool_input': {'command': '*** Begin Patch'}})
        self.assertIn('chrome-devtools', result['hookSpecificOutput']['additionalContext'])

    def test_project_scoped_context(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / '.codex/domain-context.json'
            path.parent.mkdir()
            path.write_text(json.dumps({'prompt_rules': [{'pattern': 'project-key', 'message': 'Scoped context'}]}))
            self.assertEqual(hooks.domain_context({'cwd': tmp, 'prompt': 'project-key'}), 'Scoped context')
            self.assertEqual(hooks.domain_context({'cwd': tmp, 'prompt': 'unrelated'}), '')


if __name__ == '__main__':
    unittest.main()

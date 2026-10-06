import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'dotfiles/ubuntu/bootstrap.sh'


class UbuntuBootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ubuntu config ')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home with spaces'
        self.home.mkdir()
        self.bin = Path(self.temp.name) / 'bin'
        self.bin.mkdir()
        delta = self.bin / 'delta'
        delta.write_text('#!/bin/sh\nexit 0\n')
        delta.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'])

    def run_script(self, *args):
        return subprocess.run(['bash', str(SCRIPT), '--config-only',
                               '--target-home=' + str(self.home), *args],
                              env=self.env, text=True, capture_output=True)

    def test_backup_identity_and_local_override_preserved(self):
        (self.home / '.zshrc').write_text('old shell\n')
        (self.home / '.zshrc.local').write_text('export LOCAL_TEST=1\n')
        (self.home / '.gitconfig').write_text('[user]\n name = Existing User\n email = local@example.invalid\n')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / '.zshrc.local').read_text(), 'export LOCAL_TEST=1\n')
        backups = list((self.home / '.local/state/team-config/backups').glob('*/.zshrc'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'old shell\n')
        self.assertIn('Existing User', (self.home / '.gitconfig').read_text())
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual((self.home / '.gitconfig').read_text().count('team-ui.conf'), 1)
        self.assertEqual(self.run_script('--verify').returncode, 0)

    def test_verify_detects_drift_without_repair(self):
        self.assertEqual(self.run_script().returncode, 0)
        target = self.home / '.tmux.conf'
        target.write_text('changed\n')
        result = self.run_script('--verify')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_text(), 'changed\n')

    def test_symlink_is_not_overwritten(self):
        external = Path(self.temp.name) / 'external'
        external.write_text('preserve\n')
        (self.home / '.zshrc').symlink_to(external)
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(external.read_text(), 'preserve\n')


if __name__ == '__main__':
    unittest.main()

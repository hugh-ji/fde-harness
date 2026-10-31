"""Exercise the installer against disposable Git repositories, never exam files."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='harness-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source = self.base / 'source with spaces'
        shutil.copytree(ROOT, self.source, ignore=shutil.ignore_patterns('.git', '__pycache__', '.pytest_cache'))
        self.env = os.environ.copy()
        self.env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
        self.git(self.source, 'init', '-q')
        self.git(self.source, 'add', '.')
        self.git(self.source, '-c', 'user.name=Test Fixture', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture')
        self.ws = self.base / 'workspace with spaces'
        self.ws.mkdir()

    def git(self, path, *args):
        return subprocess.run(['git', '-C', str(path), *args], check=True, capture_output=True, text=True, env=self.env).stdout

    def install(self, target=None, no_target=False):
        args = ['sh', str(self.source / 'setup.sh')]
        if not no_target:
            args.append(str(target or self.ws))
        return subprocess.run(args, capture_output=True, text=True, env=self.env)

    def snapshot(self, root):
        return {str(p.relative_to(root)): ('link', os.readlink(p)) if p.is_symlink() else ('file', p.read_bytes()) if p.is_file() else ('dir',) for p in root.rglob('*')}

    def assert_unchanged_failure(self, target=None):
        before = self.snapshot(self.ws)
        result = self.install(target)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(before, self.snapshot(self.ws))

    def test_success_removes_source_and_records_exact_commit(self):
        (self.ws / 'README.md').write_text('official instructions')
        sha = self.git(self.source, 'rev-parse', 'HEAD').strip()
        plan = (self.source / 'templates/PLAN.md').read_bytes()
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.source.exists(), 'clone should be removed after a successful install')
        self.assertEqual((self.ws / 'README.md').read_text(), 'official instructions')
        self.assertFalse((self.ws / '.git').exists())
        text = (self.ws / 'HARNESS_SOURCE.md').read_text()
        self.assertIn(sha, text)
        self.assertIn('https://github.com/hugh-ji/fde-harness', text)
        self.assertIn('removed', text)
        self.assertEqual((self.ws / 'PLAN.md').read_bytes(), plan)

    def test_keep_source_env_preserves_clone(self):
        before = self.snapshot(self.source)
        self.env['KEEP_SOURCE'] = '1'
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, self.snapshot(self.source))
        self.assertIn('KEEP_SOURCE', (self.ws / 'HARNESS_SOURCE.md').read_text())

    def test_short_command_installs_into_clone_parent(self):
        sha = self.git(self.source, 'rev-parse', 'HEAD').strip()
        result = self.install(no_target=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.source.exists())
        self.assertTrue((self.base / 'AGENTS.md').is_file())
        source_record = (self.base / 'HARNESS_SOURCE.md').read_text()
        self.assertIn(sha, source_record)
        self.assertIn(str(self.base), result.stdout)

    def test_existing_official_instructions_and_documents_are_preserved(self):
        for path in ['AGENTS.md', 'PLAN.md', 'HANDOFF.md', 'HARNESS_SOURCE.md']:
            with self.subTest(path=path):
                p = self.ws / path
                p.write_text('KEEP ORIGINAL')
                self.assert_unchanged_failure()
                p.unlink()

    def test_last_file_collision_does_not_partially_copy(self):
        (self.ws / 'CHECKLIST.md').write_text('official checklist')
        self.assert_unchanged_failure()
        self.assertFalse((self.ws / 'AGENTS.md').exists())

    def test_read_only_target_tells_agent_to_relocate_not_chmod(self):
        self.ws.chmod(0o555)
        try:
            result = self.install()
        finally:
            self.ws.chmod(0o755)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Do NOT change permissions', result.stderr)
        self.assertFalse((self.ws / 'AGENTS.md').exists())

    def test_non_ascii_source_path_installs(self):
        src2 = self.base / '한글 경로 테스트' / 'fde-harness'
        shutil.copytree(self.source, src2)
        ws2 = self.base / '한글 경로 테스트' / 'users'
        ws2.mkdir()
        result = subprocess.run(['sh', str(src2 / 'setup.sh'), str(ws2)], capture_output=True, text=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((ws2 / 'AGENTS.md').is_file())

    def test_dangling_destination_symlink_is_preserved(self):
        (self.ws / 'PLAN.md').symlink_to(self.base / 'missing')
        self.assert_unchanged_failure()

    def test_existing_parent_git_index_head_and_identity_are_preserved(self):
        self.git(self.base, 'init', '-q')
        (self.base / 'tracked.txt').write_text('baseline')
        self.git(self.base, 'add', 'tracked.txt')
        self.git(self.base, '-c', 'user.name=Original', '-c', 'user.email=original@example.invalid', 'commit', '-qm', 'baseline')
        (self.base / 'tracked.txt').write_text('staged existing work')
        self.git(self.base, 'add', 'tracked.txt')
        (self.ws / 'unrelated.txt').write_text('uncommitted work')
        index = (self.base / '.git/index').read_bytes()
        config = (self.base / '.git/config').read_bytes()
        head = self.git(self.base, 'rev-parse', 'HEAD')
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(index, (self.base / '.git/index').read_bytes())
        self.assertEqual(config, (self.base / '.git/config').read_bytes())
        self.assertEqual(head, self.git(self.base, 'rev-parse', 'HEAD'))
        self.assertEqual((self.ws / 'unrelated.txt').read_text(), 'uncommitted work')

    def test_rerun_cannot_overwrite_completed_work(self):
        self.assertEqual(self.install().returncode, 0)
        (self.ws / 'PLAN.md').write_text('completed work')
        self.assert_unchanged_failure()

    def test_explicit_target_must_exist(self):
        self.assert_unchanged_failure(self.base / 'not-created')

    def test_more_than_one_target_is_rejected(self):
        result = subprocess.run(
            ['sh', str(self.source / 'setup.sh'), str(self.ws), str(self.base)],
            capture_output=True,
            text=True,
            env=self.env,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.ws / 'AGENTS.md').exists())

    def test_source_or_its_descendant_cannot_be_target(self):
        before = self.snapshot(self.source)
        self.assertNotEqual(self.install(self.source).returncode, 0)
        self.assertEqual(before, self.snapshot(self.source))
        self.assertNotEqual(self.install(self.source / 'templates').returncode, 0)

    def test_modified_or_untracked_source_is_rejected(self):
        p = self.source / 'AGENTS.md'
        original = p.read_text()
        p.write_text(original + '\nmodified')
        self.assert_unchanged_failure()
        p.write_text(original)
        (self.source / 'unexpected.txt').write_text('not part of reviewed version')
        self.assert_unchanged_failure()

    def test_missing_allowlisted_source_is_rejected_before_writes(self):
        self.git(self.source, 'rm', 'templates/PLAN.md')
        self.git(self.source, '-c', 'user.name=Test Fixture', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'remove fixture')
        self.assert_unchanged_failure()

    def test_source_symlink_is_rejected_before_writes(self):
        p = self.source / 'templates/PLAN.md'
        p.unlink()
        p.symlink_to('../README.md')
        self.git(self.source, 'add', 'templates/PLAN.md')
        self.git(self.source, '-c', 'user.name=Test Fixture', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'link fixture')
        self.assert_unchanged_failure()


if __name__ == '__main__':
    unittest.main()

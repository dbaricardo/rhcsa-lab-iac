"""Subprocess fixtures only; never calls the real workstation dispatcher."""
import paths  # noqa: F401  (põe backend/ai_review no sys.path)
import importlib.util
import json
import os
from pathlib import Path
import pwd
import subprocess
import sys
import tempfile
import unittest

CATALOG = [{'id': 'examsim-user-barry', 'number': 1, 'hosts': ['servera'], 'title': 'Barry'}]


class WrapperTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.original = self.root / 'original'
        self.catalog = self.root / 'catalog.json'
        self.catalog.write_text(json.dumps(CATALOG))
        self.data = self.root / 'data'

    def fixture(self, source):
        self.original.write_text('#!/usr/bin/python3\n' + source)
        self.original.chmod(0o755)

    def command(self, args):
        self.assertIsNotNone(importlib.util.find_spec('lab_wrapper'), 'wrapper missing')
        return [sys.executable, '-c',
                'import sys; sys.path.insert(0, ' + repr(str(paths.FILES)) + '); import lab_wrapper as w; w.exit_with_returncode(w.run_wrapper(' + repr(args) +
                ', original=' + repr(str(self.original)) + ', catalog_path=' + repr(str(self.catalog)) +
                ', data_dir=' + repr(str(self.data)) + ', student_user=' + repr(pwd.getpwuid(os.getuid()).pw_name) + '))']

    def state(self):
        import backend
        return backend.ProgressStore(self.data, CATALOG).state()['tasks'][0]

    def test_untracked_invocations_exec_original_without_database(self):
        self.fixture("import sys\nprint('ARGS=' + repr(sys.argv[1:]), flush=True)\nprint('stderr unchanged', file=sys.stderr)\nsys.exit(7)\n")
        for args in [['list'], ['grade', 'other-lab'], ['grade', CATALOG[0]['id'], 'extra'], ['nonsense'], []]:
            with self.subTest(args=args):
                proc = subprocess.run(self.command(args), capture_output=True, timeout=5)
                self.assertEqual(proc.returncode, 7, proc.stderr)
                self.assertEqual(proc.stdout.decode(), 'ARGS=' + repr(args) + '\n')
                self.assertEqual(proc.stderr, b'stderr unchanged\n')
                self.assertFalse(self.data.exists())

    def test_refused_grade_of_finish_only_exam_is_not_recorded(self):
        catalog = CATALOG + [{'id': 'examsim-full', 'number': 0, 'hosts': ['workstation'],
                              'title': 'Prova', 'grade': False}]
        self.catalog.write_text(json.dumps(catalog))
        self.fixture("import sys\nprint('correcao so no finish', flush=True)\nsys.exit(2)\n")
        proc = subprocess.run(self.command(['grade', 'examsim-full']), capture_output=True, timeout=5)
        self.assertEqual(proc.returncode, 2, proc.stderr)
        self.assertEqual(proc.stdout, b'correcao so no finish\n')
        self.assertFalse(self.data.exists())
        subprocess.run(self.command(['finish', 'examsim-full']), capture_output=True, timeout=5)
        self.assertTrue(self.data.exists())

    def test_stream_combined_output_exit_status_and_grade_persistence(self):
        self.fixture("import sys\nprint('FALHOU: fixture criterion', flush=True)\nprint('RESULTADO: FALHOU', file=sys.stderr, flush=True)\nsys.exit(1)\n")
        proc = subprocess.run(self.command(['grade', CATALOG[0]['id']]), capture_output=True, timeout=5)
        self.assertEqual(proc.returncode, 1, proc.stderr)
        self.assertEqual(proc.stdout, b'FALHOU: fixture criterion\nRESULTADO: FALHOU\n')
        self.assertEqual(proc.stderr, b'')
        self.assertEqual(self.state()['status'], 'failed')

    def test_persistence_failure_never_masks_grader_result(self):
        self.fixture("import sys\nprint('OK: fixture criterion', flush=True)\nprint('RESULTADO: PASSOU', flush=True)\nsys.exit(0)\n")
        blocked = self.root / 'not-a-directory'
        blocked.write_text('blocked')
        # Use a deliberately unusable data path.
        cmd = [sys.executable, '-c',
               'import sys; sys.path.insert(0, ' + repr(str(paths.FILES)) + '); import lab_wrapper as w; w.exit_with_returncode(w.run_wrapper(' + repr(['grade', CATALOG[0]['id']]) +
               ', original=' + repr(str(self.original)) + ', catalog_path=' + repr(str(self.catalog)) +
               ', data_dir=' + repr(str(blocked / 'child')) + ', student_user=' + repr(pwd.getpwuid(os.getuid()).pw_name) + '))']
        proc = subprocess.run(cmd, capture_output=True, timeout=5)
        self.assertEqual(proc.returncode, 0)
        self.assertIn(b'RESULTADO: PASSOU', proc.stdout)
        self.assertIn(b'AVISO: dashboard', proc.stderr)

    def test_production_entrypoint_uses_fixed_paths(self):
        source = (paths.FILES / 'lab_wrapper.py').read_text()
        self.assertIn("'/usr/local/libexec/rhcsa-lab-original'", source)
        self.assertIn("'/opt/rhcsa-lab-dashboard/catalog.json'", source)
        self.assertIn("'/var/lib/rhcsa-lab-dashboard'", source)
        self.assertIn("main(sys.argv[1:])", source)


if __name__ == '__main__':
    unittest.main()

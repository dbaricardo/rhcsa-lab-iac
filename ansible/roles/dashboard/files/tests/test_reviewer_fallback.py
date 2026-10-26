"""Revisor (contrib/ai-reviewer): Claude primeiro; reserva opcional (RHCSA_REVIEW_FALLBACK) quando o Claude falha."""
import paths  # noqa: F401  (põe backend/ai_review no sys.path)
from importlib.machinery import SourceFileLoader
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

SCRIPT = paths.REVIEWER
_loader = SourceFileLoader('rhcsa_reviewer', str(SCRIPT))
_spec = importlib.util.spec_from_loader('rhcsa_reviewer', _loader)
reviewer = importlib.util.module_from_spec(_spec)
_loader.exec_module(reviewer)

PAYLOAD = json.dumps({'task': {'id': 'examsim-swap', 'title': 'Swap'}}).encode()


def done(rc, out=b'', err=b''):
    return subprocess.CompletedProcess([], rc, out, err)


class ReviewerFallbackTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        for name, value in (('WORKDIR', root / 'work'), ('ARCHIVE', root / 'archive')):
            patcher = mock.patch.object(reviewer, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.archive = root / 'archive'
        patcher = mock.patch.object(reviewer, 'CLAUDE', '/usr/bin/claude')
        patcher.start()
        self.addCleanup(patcher.stop)

    def review(self, *results):
        stdin = mock.Mock(buffer=io.BytesIO(PAYLOAD))
        stdout = io.StringIO()
        with mock.patch.object(reviewer.subprocess, 'run', side_effect=list(results)) as run, \
                mock.patch.object(reviewer.sys, 'stdin', stdin), \
                mock.patch.object(reviewer.sys, 'stdout', stdout), \
                mock.patch.object(reviewer.sys, 'stderr', io.StringIO()):
            rc = reviewer.main()
        return rc, stdout.getvalue(), run.call_args_list

    def with_fallback(self, path='/opt/reviewer/fallback'):
        patcher = mock.patch.object(reviewer, 'FALLBACK', path)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_claude_success_does_not_call_fallback(self):
        self.with_fallback()
        rc, out, calls = self.review(done(0, b'## Veredito\nPassou'))
        self.assertEqual(rc, 0)
        self.assertEqual(out, '## Veredito\nPassou\n')
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0].args[0][0], reviewer.CLAUDE)

    def test_without_fallback_claude_error_is_final(self):
        self.with_fallback('')
        rc, out, calls = self.review(done(1, err=b'rate limit'))
        self.assertEqual(rc, 4)
        self.assertEqual(out, '')
        self.assertEqual(len(calls), 1)

    def test_claude_error_falls_back_with_note(self):
        self.with_fallback()
        rc, out, calls = self.review(done(1, err=b'rate limit'), done(0, b'## Veredito\nOk'))
        self.assertEqual(rc, 0)
        self.assertTrue(out.startswith('> Revisão feita pelo revisor de **reserva**'))
        self.assertIn('claude falhou (1): rate limit', out)
        self.assertIn('## Veredito\nOk', out)
        fallback = calls[1]
        self.assertEqual(fallback.args[0], ['/opt/reviewer/fallback'])
        self.assertEqual(fallback.kwargs['input'], calls[0].kwargs['input'])
        self.assertEqual(fallback.kwargs['env']['RHCSA_REVIEW_SYSTEM'], reviewer.SYSTEM)
        self.assertEqual(fallback.kwargs['timeout'], reviewer.FALLBACK_TIMEOUT_S)

    def test_claude_timeout_or_empty_output_also_falls_back(self):
        self.with_fallback()
        for first in (subprocess.TimeoutExpired('claude', 1), done(0, b'  \n')):
            with self.subTest(first=first):
                rc, out, calls = self.review(first, done(0, b'revisao'))
                self.assertEqual(rc, 0)
                self.assertEqual(len(calls), 2)
                self.assertIn('revisao', out)

    def test_both_failing_returns_error_with_both_reasons(self):
        self.with_fallback()
        stderr = io.StringIO()
        stdin = mock.Mock(buffer=io.BytesIO(PAYLOAD))
        with mock.patch.object(reviewer.subprocess, 'run',
                               side_effect=[done(1, err=b'x'), OSError('sem venv')]), \
                mock.patch.object(reviewer.sys, 'stdin', stdin), \
                mock.patch.object(reviewer.sys, 'stderr', stderr):
            rc = reviewer.main()
        self.assertEqual(rc, 4)
        self.assertIn('claude falhou (1): x', stderr.getvalue())
        self.assertIn('reserva não executou: sem venv', stderr.getvalue())
        self.assertEqual(len(list(self.archive.glob('*.md'))), 1)

    def without_claude(self):
        patcher = mock.patch.object(reviewer, 'CLAUDE', None)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_without_claude_fallback_is_the_main_reviewer(self):
        self.with_fallback()
        self.without_claude()
        rc, out, calls = self.review(done(0, b'## Veredito\nOk'))
        self.assertEqual(rc, 0)
        self.assertEqual(out, '## Veredito\nOk\n')  # sem o aviso de "reserva"
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0].args[0], ['/opt/reviewer/fallback'])

    def test_without_claude_and_without_fallback_fails(self):
        self.with_fallback('')
        self.without_claude()
        stderr = io.StringIO()
        stdin = mock.Mock(buffer=io.BytesIO(PAYLOAD))
        with mock.patch.object(reviewer.subprocess, 'run') as run, \
                mock.patch.object(reviewer.sys, 'stdin', stdin), \
                mock.patch.object(reviewer.sys, 'stderr', stderr):
            rc = reviewer.main()
        self.assertEqual(rc, 4)
        run.assert_not_called()
        self.assertIn('claude não instalado', stderr.getvalue())

    def test_fallback_receives_only_its_own_variables(self):
        self.with_fallback()
        env = {'RHCSA_REVIEW_FALLBACK_URL': 'http://llm:1234/v1',
               'RHCSA_REVIEW_FALLBACK_MODEL': 'qwen', 'SEGREDO_QUALQUER': 'x'}
        with mock.patch.dict(reviewer.os.environ, env):
            _, _, calls = self.review(done(1, err=b'x'), done(0, b'ok'))
        fb_env = calls[1].kwargs['env']
        self.assertEqual(fb_env['RHCSA_REVIEW_FALLBACK_URL'], 'http://llm:1234/v1')
        self.assertEqual(fb_env['RHCSA_REVIEW_FALLBACK_MODEL'], 'qwen')
        self.assertNotIn('SEGREDO_QUALQUER', fb_env)

    def test_config_file_fills_only_missing_review_variables(self):
        with tempfile.TemporaryDirectory() as tmp:
            conf = Path(tmp) / 'env'
            conf.write_text('# comentario\nRHCSA_REVIEW_MODEL=opus\n'
                            'RHCSA_REVIEW_FALLBACK_URL="http://x/v1"\nPATH=/tmp/mal\n'
                            'RHCSA_REVIEW_FALLBACK_MODEL=do-arquivo\n', encoding='utf-8')
            with mock.patch.dict(reviewer.os.environ,
                                 {'RHCSA_REVIEW_FALLBACK_MODEL': 'do-ambiente'}, clear=True):
                reviewer.load_config(conf)
                self.assertEqual(reviewer.os.environ['RHCSA_REVIEW_MODEL'], 'opus')
                self.assertEqual(reviewer.os.environ['RHCSA_REVIEW_FALLBACK_URL'], 'http://x/v1')
                self.assertEqual(reviewer.os.environ['RHCSA_REVIEW_FALLBACK_MODEL'], 'do-ambiente')
                self.assertNotIn('PATH', reviewer.os.environ)
            reviewer.load_config(Path(tmp) / 'nao-existe')  # arquivo ausente: sem erro

    def test_reviewer_has_nothing_specific_to_the_homelab(self):
        source = SCRIPT.read_text(encoding='utf-8')
        for needle in ('dbaricardo', 'hermes', 'Hermes', '192.168.10.', 'LXC'):
            self.assertNotIn(needle, source)

    def test_workstation_timeout_covers_both_reviewers(self):
        import ai_review
        self.assertGreater(ai_review.DEFAULT_REVIEW_TIMEOUT_S,
                           reviewer.TIMEOUT_S + reviewer.FALLBACK_TIMEOUT_S)

if __name__ == '__main__':
    unittest.main()

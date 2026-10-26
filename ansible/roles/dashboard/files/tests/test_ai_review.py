"""Revisão por IA: replay das gravações, formato da transcrição, eventos e disparo no finish."""
import paths  # noqa: F401  (põe backend/ai_review no sys.path)
import json
import os
from pathlib import Path
import pwd
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import ai_review
import backend

CATALOG = [{'id': 'examsim-swap', 'number': 1, 'hosts': ['serverb'], 'title': 'Swap',
            'description': 'Criar swap', 'instructions': [], 'warning': ''}]
PROMPT = '[root@serverb ~]# '


def recording(chunks):
    """Monta (.out, .tm) no formato do script(1): cabeçalho + dados, timing 'delay bytes'."""
    data = b'Script started on 2026-09-27 12:00:00-03:00 [TERM="xterm"]\n'
    timing = []
    for delay, text in chunks:
        raw = text.encode()
        data += raw
        timing.append(f'{delay} {len(raw)}')
    return data + b'\nScript done on 2026-09-27\n', '\n'.join(timing)


class ReplayTests(unittest.TestCase):
    def test_readline_edits_are_applied_to_the_command_line(self):
        data, timing = recording([(1, PROMPT), (0.5, 'swapn'), (0.1, '\b \b'),
                                  (0.1, 'on -s\r\n'), (0.2, 'Filename\r\n')])
        lines = ai_review.replay(data, timing, 1000.0, 1000.0, 1010.0)
        self.assertEqual([text for _, text in lines], [PROMPT + 'swapon -s', 'Filename'])
        self.assertAlmostEqual(lines[0][0], 1001.0)

    def test_csi_erase_and_cursor_moves(self):
        data, timing = recording([(0, PROMPT + 'lsbk\x1b[D\x1b[D\x1b[K'), (0, 'blk\r\n')])
        lines = ai_review.replay(data, timing, 0.0, 0.0, 5.0)
        self.assertEqual(lines[0][1], PROMPT + 'lsblk')

    def test_full_screen_editor_becomes_a_marker(self):
        data, timing = recording([(0, PROMPT + 'vim /etc/fstab\r\n'),
                                  (1, '\x1b[?1049h\x1b[H~\r\n~\r\n"fstab" 12L'),
                                  (5, '\x1b[?1049l'), (0, PROMPT + 'mount -a\r\n')])
        texts = [text for _, text in ai_review.replay(data, timing, 0.0, 0.0, 60.0)]
        self.assertEqual(texts, [PROMPT + 'vim /etc/fstab',
                                 '⟦tela cheia (editor/pager) — conteúdo omitido⟧',
                                 PROMPT + 'mount -a'])

    def test_output_outside_the_attempt_window_is_dropped(self):
        data, timing = recording([(0, PROMPT + 'antes\r\n'), (100, PROMPT + 'durante\r\n'),
                                  (100, PROMPT + 'depois\r\n')])
        texts = [text for _, text in ai_review.replay(data, timing, 0.0, 50.0, 150.0)]
        self.assertEqual(texts, [PROMPT + 'durante'])

    def test_multibyte_utf8_split_across_chunks(self):
        raw = 'ação\r\n'.encode()
        data = b'Script started on x\n' + raw
        timing = f'0 3\n0 {len(raw) - 3}'
        self.assertEqual(ai_review.replay(data, timing, 0.0, 0.0, 1.0)[0][1], 'ação')


class FormatTests(unittest.TestCase):
    def test_prompts_get_elapsed_time_and_long_output_is_collapsed(self):
        lines = [(130.0, PROMPT + 'rpm -qa')] + [(131.0, f'pkg{i}') for i in range(40)]
        text = ai_review.format_transcript(lines, 100.0, 10_000)
        self.assertTrue(text.startswith('+00:30  ' + PROMPT + 'rpm -qa'))
        self.assertIn('(23 linhas de saída omitidas)', text)
        self.assertIn('pkg0', text)
        self.assertIn('pkg39', text)
        self.assertNotIn('pkg20', text)

    def test_password_piped_to_passwd_is_redacted(self):
        text = ai_review.format_transcript([(0.0, PROMPT + "echo 'S3nh@' | passwd --stdin barry")], 0.0, 1000)
        self.assertIn("echo [REDACTED] | passwd --stdin barry", text)
        self.assertNotIn('S3nh@', text)

    def test_password_variants_are_redacted(self):
        for cmd, secret in (("echo 'minha senha forte' | passwd --stdin barry", 'forte'),
                            ('printf "barry:Xy 9\\n" | sudo chpasswd', 'Xy 9'),
                            ("passwd --stdin barry <<< 'Pw 123'", 'Pw 123'),
                            ("chpasswd <<< barry:Zz9", 'Zz9')):
            text = ai_review.format_transcript([(0.0, PROMPT + cmd)], 0.0, 1000)
            self.assertNotIn(secret, text, cmd)
            self.assertIn('[REDACTED]', text, cmd)

    def test_collection_failure_is_reported_not_silent(self):
        failed = mock.Mock(returncode=255, stdout=b'', stderr=b'Permission denied')
        with mock.patch.object(ai_review.subprocess, 'run', return_value=failed):
            transcripts = ai_review.collect_transcripts(0.0, 10.0, 1000)
        self.assertEqual([t['host'] for t in transcripts], ['servera', 'serverb', 'workstation'])
        self.assertTrue(all('coleta falhou' in t['error'] for t in transcripts))

    def test_limit_keeps_head_and_tail(self):
        lines = [(0.0, PROMPT + f'cmd{i}') for i in range(500)]
        text = ai_review.format_transcript(lines, 0.0, 2000)
        self.assertIn('cmd0', text)
        self.assertIn('cmd499', text)
        self.assertIn('transcrição cortada', text)


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.store = backend.ProgressStore(self.tmp.name, CATALOG)

    def test_attempt_returns_events_after_last_successful_start(self):
        self.store.record('examsim-swap', 'start', 'velho', 0, started_ns=1)
        self.store.record('examsim-swap', 'grade', 'grade velho', 1, started_ns=2)
        self.store.record('examsim-swap', 'start', 'novo', 0, started_ns=10)
        self.store.record('examsim-swap', 'grade', 'grade novo', 1, started_ns=11)
        self.store.record('examsim-swap', 'finish', 'fim', 0, started_ns=12)
        self.store.record('examsim-swap', 'grade', 'depois', 1, started_ns=99)
        attempt = self.store.attempt('examsim-swap', until_ns=12)
        self.assertEqual(attempt['started_ns'], 10)
        self.assertEqual([(e['action'], e['output']) for e in attempt['events']],
                         [('grade', 'grade novo'), ('finish', 'fim')])
        self.assertIsNone(self.store.attempt('examsim-swap', until_ns=0))

    def test_review_is_exposed_without_touching_status_or_history(self):
        self.store.record('examsim-swap', 'start', 'ok', 0, started_ns=10)
        self.store.record_review('examsim-swap', {'state': 'running'}, started_ns=13)
        self.assertEqual(self.store.state()['tasks'][0]['review']['state'], 'running')
        self.store.record_review('examsim-swap', {'state': 'done', 'markdown': '## Veredito'}, started_ns=14)
        task = self.store.state()['tasks'][0]
        self.assertEqual(task['review']['markdown'], '## Veredito')
        self.assertEqual(task['status'], 'in_progress')
        self.assertEqual([h['action'] for h in task['history']], ['start'])

    def test_review_rejects_unknown_state_or_task(self):
        with self.assertRaises(ValueError):
            self.store.record_review('examsim-swap', {'state': 'weird'}, started_ns=1)
        with self.assertRaises(ValueError):
            self.store.record_review('nope', {'state': 'done'}, started_ns=1)

    def test_attempt_ignores_review_events(self):
        self.store.record('examsim-swap', 'start', 'ok', 0, started_ns=10)
        self.store.record_review('examsim-swap', {'state': 'running'}, started_ns=11)
        self.assertEqual(self.store.attempt('examsim-swap', until_ns=20)['events'], [])


class RunTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'catalog.json').write_text(json.dumps(CATALOG))
        self.store = backend.ProgressStore(self.root / 'data', CATALOG)
        self.store.record('examsim-swap', 'start', 'ok', 0, started_ns=10)
        self.store.record('examsim-swap', 'finish', 'fim', 0, started_ns=20)

    def run_review(self, reviewer):
        with mock.patch.object(ai_review, 'collect_transcripts', return_value=[]), \
                mock.patch.object(ai_review, 'ask_reviewer', side_effect=reviewer):
            return ai_review.run('examsim-swap', 20, catalog_path=self.root / 'catalog.json',
                                 data_dir=self.root / 'data', home=self.root)

    def test_success_records_done_and_writes_feedback_file(self):
        self.assertEqual(self.run_review(lambda payload, home: '## Veredito\nPassou.'), 0)
        review = self.store.state()['tasks'][0]['review']
        self.assertEqual((review['state'], review['markdown']), ('done', '## Veredito\nPassou.'))
        files = list((self.root / 'examsim-feedback').glob('examsim-swap-*.md'))
        self.assertEqual(len(files), 1)

    def test_reviewer_failure_records_error(self):
        def boom(payload, home):
            raise RuntimeError('revisor retornou 4: claude falhou')
        with self.assertRaises(RuntimeError):
            self.run_review(boom)
        review = self.store.state()['tasks'][0]['review']
        self.assertEqual(review['state'], 'error')
        self.assertIn('claude falhou', review['error'])


class WrapperSpawnTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'catalog.json').write_text(json.dumps(CATALOG))
        self.original = self.root / 'original'
        self.original.write_text('#!/usr/bin/python3\nprint("RESULTADO: PASSOU", flush=True)\n')
        self.original.chmod(0o755)
        self.review = self.root / 'fake_review.py'
        self.review.write_text('import sys, pathlib\npathlib.Path(sys.argv[0]).with_suffix(".called")'
                               '.write_text(" ".join(sys.argv[1:]))\n')

    def run_lab(self, action, env=None):
        code = ('import sys; sys.path.insert(0, ' + repr(str(paths.FILES)) + '); import lab_wrapper as w; w.exit_with_returncode(w.run_wrapper(' + repr([action, 'examsim-swap'])
                + f', original={str(self.original)!r}, catalog_path={str(self.root / "catalog.json")!r}'
                + f', data_dir={str(self.root / "data")!r}, student_user={pwd.getpwuid(os.getuid()).pw_name!r}'
                + f', review_script={str(self.review)!r}))')
        return subprocess.run([sys.executable, '-c', code], capture_output=True, timeout=10,
                              env=dict(os.environ, HOME=str(self.root), **(env or {})))

    def wait_called(self):
        marker = self.review.with_suffix('.called')
        for _ in range(50):
            if marker.exists() and marker.read_text():
                return marker.read_text()
            subprocess.run(['sleep', '0.1'])
        return None

    def test_finish_spawns_review_and_start_does_not(self):
        self.assertEqual(self.run_lab('start').returncode, 0)
        self.assertIsNone(self.wait_called() if self.review.with_suffix('.called').exists() else None)
        proc = self.run_lab('finish')
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn('Revisão por IA iniciada', proc.stdout.decode())
        called = self.wait_called()
        self.assertIsNotNone(called)
        task_id, finish_ns = called.split()
        self.assertEqual(task_id, 'examsim-swap')
        self.assertTrue(finish_ns.isdigit())

    def test_without_review_script_finish_is_unchanged(self):
        # ai_review_enabled=false: o role não instala ai_review.py.
        self.review.unlink()
        proc = self.run_lab('finish')
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn('RESULTADO: PASSOU', proc.stdout.decode())
        self.assertNotIn('Revisão por IA', proc.stdout.decode() + proc.stderr.decode())

    def test_review_can_be_disabled_by_environment(self):
        proc = self.run_lab('finish', env={'RHCSA_AI_REVIEW': '0'})
        self.assertEqual(proc.returncode, 0)
        self.assertNotIn('Revisão por IA', proc.stdout.decode())
        subprocess.run(['sleep', '0.5'])
        self.assertFalse(self.review.with_suffix('.called').exists())


class ExamPayloadTests(unittest.TestCase):
    """As duas provas completas levam o enunciado; tarefas avulsas não."""

    def payload(self, task_id, folder):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            if folder:
                (home / folder).mkdir()
                (home / folder / 'enunciado.txt').write_text('Q01 enunciado de teste', encoding='utf-8')
            attempt = {'started_ns': 1_000_000_000, 'started_at': 'x', 'events': []}
            task = {'id': task_id, 'title': 't', 'description': '', 'instructions': [], 'warning': '',
                    'hosts': ['workstation'], 'solve_target': ''}
            with mock.patch.object(ai_review, 'collect_transcripts', return_value={}) as collect:
                result = ai_review.build_payload(task, attempt, 2_000_000_000, home)
            return result, collect.call_args.args[2]

    def test_dynamic_exam_sends_its_own_statement_and_the_large_transcript_budget(self):
        result, limit = self.payload('examsim-dinamico', 'examsim-dinamico')
        self.assertEqual(result['enunciado'], 'Q01 enunciado de teste')
        self.assertEqual(limit, ai_review.MAX_HOST_CHARS_FULL)

    def test_fixed_full_exam_is_unchanged(self):
        result, limit = self.payload('examsim-full', 'examsim-full')
        self.assertEqual(result['enunciado'], 'Q01 enunciado de teste')
        self.assertEqual(limit, ai_review.MAX_HOST_CHARS_FULL)

    def test_single_tasks_get_no_statement_and_the_small_budget(self):
        result, limit = self.payload('examsim-swap', None)
        self.assertEqual(result['enunciado'], '')
        self.assertEqual(limit, ai_review.MAX_HOST_CHARS)

    def test_missing_statement_file_degrades_to_empty(self):
        result, _ = self.payload('examsim-dinamico', None)
        self.assertEqual(result['enunciado'], '')


class ReviewerConfigTests(unittest.TestCase):
    """O revisor vem de /etc/rhcsa-ai-review.conf (role ai_review), nunca do código."""

    def write(self, text):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name) / 'rhcsa-ai-review.conf'
        path.write_text(text, encoding='utf-8')
        return path

    def test_reads_reviewer_key_and_timeout(self):
        conf = ai_review.load_config(self.write(
            '# comentario\nRHCSA_AI_REVIEWER=rev@reviewer.example\n'
            'RHCSA_AI_REVIEW_KEY=.ssh/outra\nRHCSA_AI_REVIEW_TIMEOUT=900\n'))
        self.assertEqual(conf, {'reviewer': 'rev@reviewer.example', 'key': '.ssh/outra', 'timeout': 900})

    def test_missing_file_gives_defaults_and_no_reviewer(self):
        conf = ai_review.load_config('/nonexistent/rhcsa-ai-review.conf')
        self.assertEqual(conf['reviewer'], '')
        self.assertEqual(conf['key'], ai_review.DEFAULT_REVIEWER_KEY)
        self.assertEqual(conf['timeout'], ai_review.DEFAULT_REVIEW_TIMEOUT_S)

    def test_unconfigured_reviewer_fails_without_ssh(self):
        with mock.patch.object(ai_review.subprocess, 'run') as run, \
                self.assertRaisesRegex(RuntimeError, 'revisor não configurado'):
            ai_review.ask_reviewer({}, Path('/home/x'), {'reviewer': '', 'key': 'k', 'timeout': 60})
        run.assert_not_called()

    def test_ssh_uses_configured_reviewer_key_and_timeout(self):
        ok = subprocess.CompletedProcess([], 0, b'## ok', b'')
        with mock.patch.object(ai_review.subprocess, 'run', return_value=ok) as run:
            out = ai_review.ask_reviewer({}, Path('/home/x'),
                                         {'reviewer': 'rev@host', 'key': '.ssh/k', 'timeout': 99})
        self.assertEqual(out, '## ok')
        cmd = run.call_args.args[0]
        self.assertIn('/home/x/.ssh/k', cmd)
        self.assertEqual(cmd[-2:], ['rev@host', 'review'])
        self.assertEqual(run.call_args.kwargs['timeout'], 99)

if __name__ == '__main__':
    unittest.main()

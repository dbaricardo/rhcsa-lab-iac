"""Local fixtures only: these tests are not evidence of real lab grades."""
import importlib.util
import unittest
import tempfile
from pathlib import Path


CATALOG = [
    {'id': 'examsim-user-barry', 'number': 1, 'title': 'Barry', 'hosts': ['servera'], 'host': 'servera'},
    {'id': 'examsim-autofs-remoteuser2', 'number': 2, 'title': 'Autofs', 'hosts': ['servera', 'workstation'], 'host': 'servera + workstation'},
]


class PersistenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def store(self):
        self.assertTrue(hasattr(backend(), 'ProgressStore'), 'ProgressStore missing')
        return backend().ProgressStore(self.tmp.name, CATALOG)

    def test_unknown_actions_cannot_enter_event_log(self):
        store = self.store()
        with self.assertRaises(ValueError):
            store.record(CATALOG[0]['id'], 'shell', 'OK: x\nRESULTADO: PASSOU', 0)
        self.assertEqual(store.state()['tasks'][0]['history'], [])

    def test_concurrent_writes_keep_all_attempts_and_start_order(self):
        from concurrent.futures import ThreadPoolExecutor
        store = self.store()
        task_id = CATALOG[0]['id']
        def write(n):
            self.store().record(task_id, 'grade', 'OK: x\nRESULTADO: PASSOU', 0, started_ns=n)
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(write, range(20)))
        # An earlier-started command finishing late must not overwrite a reset.
        store.record(task_id, 'start', 'reset', 0, started_ns=40)
        store.record(task_id, 'grade', 'OK: old\nRESULTADO: PASSOU', 0, started_ns=30)
        task = store.state()['tasks'][0]
        self.assertEqual(task['attempts'], 21)
        self.assertEqual(len(task['history']), 22)
        self.assertEqual(task['status'], 'in_progress')

    def test_action_errors_are_visible_and_finish_can_contain_a_real_grade(self):
        store = self.store()
        task_id = CATALOG[0]['id']
        store.record(task_id, 'start', 'ERRO: SSH unreachable', 2)
        task = store.state()['tasks'][0]
        self.assertEqual(task['status'], 'error')
        self.assertIn('SSH unreachable', task['output'])
        store.record(task_id, 'finish', 'OK: x\nRESULTADO: PASSOU', 0)
        task = store.state()['tasks'][0]
        self.assertEqual(task['status'], 'passed')
        self.assertEqual(task['attempts'], 1)
        store.record(task_id, 'finish', 'ERRO: cleanup', 2)
        task = store.state()['tasks'][0]
        self.assertEqual(task['status'], 'error')
        self.assertEqual(task['criteria'], [{'ok': True, 'text': 'x'}])
        self.assertIn('cleanup', task['output'])

    def test_successful_start_resets_and_finish_retains_grade(self):
        store = self.store()
        task_id = CATALOG[0]['id']
        store.record(task_id, 'grade', 'OK: x\nRESULTADO: PASSOU', 0)
        store.record(task_id, 'finish', 'cleanup done', 0)
        task = store.state()['tasks'][0]
        self.assertEqual(task['status'], 'passed')
        self.assertEqual(task['attempts'], 1)
        self.assertEqual(task['criteria'], [{'ok': True, 'text': 'x'}])
        self.assertEqual(task['last_action'], 'finish')
        store.record(task_id, 'start', 'prepared', 0)
        task = store.state()['tasks'][0]
        self.assertEqual(task['status'], 'in_progress')
        self.assertEqual(task['criteria'], [])
        self.assertEqual(task['total_criteria'], 0)
        self.assertIsNone(task['last_grade_at'])
        self.assertEqual(len(task['history']), 3)
        self.assertEqual(task['attempts'], 1)
        store.record(task_id, 'finish', 'cleanup done', 0)
        self.assertEqual(store.state()['tasks'][0]['status'], 'in_progress')
        store.record(CATALOG[1]['id'], 'finish', 'cleanup done', 0)
        self.assertEqual(store.state()['tasks'][1]['status'], 'pending')

    def test_grade_persists_on_reopen_with_pending_defaults_and_history(self):
        store = self.store()
        state = store.state()
        self.assertEqual(state['summary'], dict(total=2, passed=0, pending=2, in_progress=0, failed=0, error=0))
        self.assertEqual(state['next_task'], 'examsim-user-barry')
        self.assertIsNone(state['updated_at'])
        store.record('examsim-user-barry', 'grade', 'FALHOU: x\nRESULTADO: FALHOU', 1)
        store.record('examsim-user-barry', 'grade', 'OK: x\nRESULTADO: PASSOU', 0)
        state = self.store().state()
        task = state['tasks'][0]
        self.assertEqual(task['status'], 'passed')
        self.assertEqual(task['attempts'], 2)
        self.assertEqual(task['last_action'], 'grade')
        self.assertTrue(task['last_grade_at'].endswith('Z'))
        self.assertEqual([h['status'] for h in task['history']], ['failed', 'passed'])
        self.assertEqual(state['next_task'], CATALOG[1]['id'])
        self.assertEqual(state['summary']['passed'], 1)


def backend():
    assert importlib.util.find_spec('backend') is not None, 'backend implementation missing'
    import backend as module
    return module


class HTTPTests(unittest.TestCase):
    def test_cli_starts_with_explicit_local_paths(self):
        import json
        import subprocess
        import sys
        import urllib.request
        import select
        with tempfile.TemporaryDirectory() as tmp:
            catalog = Path(tmp, 'catalog.json')
            catalog.write_text(json.dumps(CATALOG))
            proc = subprocess.Popen([sys.executable, '-u', 'backend.py', '--host', '127.0.0.1',
                                     '--port', '0', '--data-dir', str(Path(tmp, 'data')),
                                     '--catalog', str(catalog), '--static-dir', tmp],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                ready, _, _ = select.select([proc.stdout], [], [], 3)
                self.assertTrue(ready, 'backend did not announce readiness')
                line = proc.stdout.readline().strip()
                self.assertTrue(line.startswith('Listening on http://127.0.0.1:'), repr(line))
                with urllib.request.urlopen(line.removeprefix('Listening on ') + '/healthz', timeout=3) as response:
                    self.assertEqual(response.status, 200)
            finally:
                proc.terminate()
                proc.communicate(timeout=3)

    def test_read_only_http_and_security_headers(self):
        import http.client
        import json
        import threading
        self.assertTrue(hasattr(backend(), 'create_server'), 'HTTP server missing')
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, 'index.html').write_text('<html>fixture UI</html>')
            Path(tmp, 'secret.txt').write_text('DO NOT SERVE')
            store = backend().ProgressStore(Path(tmp, 'data'), CATALOG)
            server = backend().create_server('127.0.0.1', 0, store, tmp)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                def request(method, path):
                    conn = http.client.HTTPConnection(*server.server_address, timeout=3)
                    try:
                        conn.request(method, path)
                        response = conn.getresponse()
                        return response.status, dict(response.getheaders()), response.read()
                    finally:
                        conn.close()
                code, headers, body = request('GET', '/api/state')
                self.assertEqual(code, 200)
                self.assertEqual(json.loads(body)['summary']['pending'], 2)
                self.assertEqual(headers['Cache-Control'], 'no-store')
                self.assertEqual(headers['X-Content-Type-Options'], 'nosniff')
                self.assertIn("default-src 'self'", headers['Content-Security-Policy'])
                self.assertNotIn('Access-Control-Allow-Origin', headers)
                self.assertEqual(request('GET', '/healthz')[0], 200)
                self.assertIn(b'fixture UI', request('GET', '/')[2])
                self.assertEqual(request('POST', '/api/state')[0], 405)
                for path in ['/../secret.txt', '/%2e%2e/secret.txt', '/secret.txt', '/backend.py', '//etc/passwd']:
                    self.assertEqual(request('GET', path)[0], 404, path)
            finally:
                server.shutdown()
                server.server_close()
                thread.join(3)


class ParsingTests(unittest.TestCase):
    def test_ansi_and_credentials_are_sanitized_without_losing_scores(self):
        text = ('\x1b[32mOK: senha de barry e SECRET\x1b[0m\n'
                'OK: pas\x1b[31msword=SECRET\n'
                'token: SECRET\n-----BEGIN PRIVATE KEY-----\nSECRET\n-----END PRIVATE KEY-----\n'
                'OK: public criterion\nRESULTADO: PASSOU\n')
        result = backend().parse_grade(text, 0, ['servera'])
        self.assertEqual(result['status'], 'passed')
        self.assertEqual(result['passed_criteria'], 3)
        self.assertNotIn('SECRET', str(result))
        self.assertNotIn('\x1b', str(result))
        self.assertEqual(result['criteria'][0]['text'], '[REDACTED]')

    def test_missing_partial_or_malformed_results_are_errors(self):
        parse = backend().parse_grade
        for text, rc, hosts in [
            ('', 0, ['servera']),
            ('OK: check\nRESULTADO: unknown', 0, ['servera']),
            ('OK: check\nRESULTADO: PASSOU', 0, ['servera', 'workstation']),
            ('OK: check\nRESULTADO: PASSOU', 255, ['servera']),
            ('ERRO: nao consegui alcancar root@servera por SSH.', 2, ['servera']),
            ('FALHOU: check\nRESULTADO: PASSOU', 0, ['servera']),
        ]:
            with self.subTest(text=text, rc=rc):
                self.assertEqual(parse(text, rc, hosts)['status'], 'error')
        partial = parse('FALHOU: check\nRESULTADO: FALHOU\nERRO: lab falhou (codigo 1).', 1, ['servera', 'workstation'])
        self.assertEqual(partial['status'], 'failed')
        complete = parse('OK: a\nRESULTADO: PASSOU\nOK: b\nRESULTADO: PASSOU', 0, ['servera', 'workstation'])
        self.assertEqual(complete['status'], 'passed')

    def test_single_host_failure_then_pass(self):
        parse = backend().parse_grade
        failed = parse('FALHOU: usuario barry existe\nRESULTADO: FALHOU\n', 1, ['servera'])
        self.assertEqual(failed['status'], 'failed')
        self.assertEqual(failed['passed_criteria'], 0)
        self.assertEqual(failed['total_criteria'], 1)
        passed = parse('OK: usuario barry existe\nRESULTADO: PASSOU\n', 0, ['servera'])
        self.assertEqual(passed['status'], 'passed')
        self.assertEqual(passed['criteria'], [{'ok': True, 'text': 'usuario barry existe'}])

    def test_finish_cleanup_success_does_not_hide_failed_grade(self):
        output = ('FALHOU: hostname esperado\nRESULTADO: FALHOU\n\n'
                  '==> lab finish (avaliação + limpeza)\nOK: item limpo')
        result = backend().parse_grade(output, 0, ['servera'])
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['passed_criteria'], 0)
        self.assertEqual(result['total_criteria'], 1)

    def test_history_keeps_sanitized_failure_reasons_for_a_finished_attempt(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = backend().ProgressStore(tmp, CATALOG)
            task_id = CATALOG[0]['id']
            store.record(task_id, 'start', 'preparado', 0, started_ns=1)
            store.record(task_id, 'finish',
                         'FALHOU: porta 82 nao esta associada a http_port_t\n'
                         'FALHOU: password=nao-persistir\nRESULTADO: FALHOU\n'
                         'OK: limpeza concluida', 0, started_ns=2)
            event = store.state()['tasks'][0]['history'][-1]
        self.assertEqual(event['status'], 'failed')
        self.assertEqual(event['failure_reasons'], [
            'porta 82 nao esta associada a http_port_t', '[REDACTED]'])


if __name__ == '__main__':
    unittest.main()

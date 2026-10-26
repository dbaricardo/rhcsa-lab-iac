"""contrib/ai-reviewer/rhcsa-ai-review-openai: reserva via API compatível com OpenAI."""
import paths
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import subprocess
import sys
import threading
import unittest

SCRIPT = str(paths.REVIEWER_OPENAI)


class FakeAPI(BaseHTTPRequestHandler):
    reply = '<think>pensando...</think>\n## Veredito\nOk'
    seen = []

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        FakeAPI.seen.append((self.path, self.headers.get('Authorization'), body))
        out = json.dumps({'choices': [{'message': {'content': FakeAPI.reply}}]}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    def log_message(self, *args):
        pass


class OpenAIReviewerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(('127.0.0.1', 0), FakeAPI)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.url = f'http://127.0.0.1:{cls.server.server_port}/v1/'

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def run_script(self, **env):
        base = {'PATH': os.environ.get('PATH', '/usr/bin'), 'RHCSA_REVIEW_SYSTEM': 'sistema'}
        return subprocess.run([sys.executable, SCRIPT], input='o prompt', capture_output=True,
                              text=True, env={**base, **env}, timeout=30)

    def setUp(self):
        FakeAPI.seen.clear()
        FakeAPI.reply = '<think>pensando...</think>\n## Veredito\nOk'

    def test_sends_chat_request_and_strips_thinking(self):
        proc = self.run_script(RHCSA_REVIEW_FALLBACK_URL=self.url,
                               RHCSA_REVIEW_FALLBACK_MODEL='qwen', RHCSA_REVIEW_FALLBACK_API_KEY='k')
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, '## Veredito\nOk\n')
        path, auth, body = FakeAPI.seen[0]
        self.assertEqual(path, '/v1/chat/completions')
        self.assertEqual(auth, 'Bearer k')
        self.assertEqual(body['model'], 'qwen')
        self.assertEqual(body['messages'], [{'role': 'system', 'content': 'sistema'},
                                            {'role': 'user', 'content': 'o prompt'}])

    def test_no_api_key_sends_no_authorization(self):
        self.run_script(RHCSA_REVIEW_FALLBACK_URL=self.url, RHCSA_REVIEW_FALLBACK_MODEL='qwen')
        self.assertIsNone(FakeAPI.seen[0][1])

    def test_missing_configuration_fails(self):
        proc = self.run_script(RHCSA_REVIEW_FALLBACK_URL=self.url)
        self.assertEqual(proc.returncode, 2)
        self.assertIn('RHCSA_REVIEW_FALLBACK_MODEL', proc.stderr)

    def test_empty_answer_fails(self):
        FakeAPI.reply = '<think>so pensou</think>'
        proc = self.run_script(RHCSA_REVIEW_FALLBACK_URL=self.url, RHCSA_REVIEW_FALLBACK_MODEL='q')
        self.assertEqual(proc.returncode, 1)
        self.assertIn('vazia', proc.stderr)

    def test_unreachable_api_fails_with_reason(self):
        proc = self.run_script(RHCSA_REVIEW_FALLBACK_URL='http://127.0.0.1:9/v1',
                               RHCSA_REVIEW_FALLBACK_MODEL='q')
        self.assertEqual(proc.returncode, 1)
        self.assertIn('API http://127.0.0.1:9/v1', proc.stderr)


if __name__ == '__main__':
    unittest.main()

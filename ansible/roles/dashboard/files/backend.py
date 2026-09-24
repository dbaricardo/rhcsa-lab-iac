#!/usr/bin/python3
"""Local-only RHCSA progress parsing, persistence and read-only HTTP API."""
import re
import json
import sqlite3
import time
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


def create_server(host, port, store, static_dir):
    """Only allow three literal GET resources, never filesystem-derived URLs."""
    index_path = Path(static_dir) / 'index.html'

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def reply(self, status, body, content_type='application/json; charset=utf-8'):
            self.send_response(status)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Content-Security-Policy',
                             "default-src 'self'; script-src 'self' 'unsafe-inline'; "
                             "style-src 'self' 'unsafe-inline'; connect-src 'self'; "
                             "object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'")
            self.send_header('Referrer-Policy', 'no-referrer')
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            path = urlsplit(self.path).path
            try:
                if path == '/api/state':
                    self.reply(200, json.dumps(store.state(), ensure_ascii=False).encode())
                elif path == '/healthz':
                    store.state()
                    self.reply(200, b'{"status":"ok"}')
                elif path == '/':
                    self.reply(200, index_path.read_bytes(), 'text/html; charset=utf-8')
                else:
                    self.reply(404, b'{"error":"not found"}')
            except (OSError, sqlite3.Error, ValueError):
                self.reply(503, b'{"error":"local dashboard data unavailable"}')

        def do_POST(self):
            self.reply(405, b'{"error":"read only"}')

        do_PUT = do_DELETE = do_PATCH = do_OPTIONS = do_POST

    return ThreadingHTTPServer((host, port), Handler)


ANSI = re.compile(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-?]*[ -/]*[@-~]|\x1b[@-_]')
SECRET = re.compile(r'senha|password|token|private[\s_-]*key', re.I)


def sanitize_output(output):
    """Remove terminal controls and entire sensitive lines before persistence."""
    text = ANSI.sub('', output)
    text = ''.join(c for c in text if c in '\n\t' or (ord(c) >= 32 and not 127 <= ord(c) <= 159))
    lines = []
    private = False
    for line in text.splitlines():
        if re.search(r'-----BEGIN .*PRIVATE KEY-----', line, re.I):
            private = True
        if private or SECRET.search(line):
            prefix = re.match(r'^\s*(OK|FALHOU):', line)
            lines.append((prefix[1] + ': ' if prefix else '') + '[REDACTED]')
        else:
            lines.append(line)
        if re.search(r'-----END .*PRIVATE KEY-----', line, re.I):
            private = False
    return '\n'.join(lines)


def parse_grade(output, returncode, hosts):
    """Interpret observed grader criteria; exit zero alone is not a score."""
    output = sanitize_output(output)
    criteria = []
    results = []
    collecting_grade = True
    for line in output.splitlines():
        stripped = line.strip()
        if re.search(r'(?:^|==>\s*)lab grade\b', stripped):
            collecting_grade = True
        match = re.fullmatch(r'(OK|FALHOU):\s*(.*)', stripped)
        if match and collecting_grade:
            criteria.append({'ok': match[1] == 'OK', 'text': match[2]})
        match = re.fullmatch(r'RESULTADO:\s*(PASSOU|FALHOU)', stripped)
        if match:
            results.append(match[1])
            collecting_grade = False
    status = 'error'
    if (returncode == 0 and results == ['PASSOU'] * len(hosts)
            and hosts and criteria and all(c['ok'] for c in criteria)):
        status = 'passed'
    elif (returncode in (0, 1) and 0 < len(results) <= len(hosts)
          and results[-1] == 'FALHOU' and not all(c['ok'] for c in criteria)):
        status = 'failed'
    failure_reasons = []
    if status == 'failed':
        for criterion in criteria:
            if not criterion['ok']:
                text = criterion['text'].strip() or 'Critério não atendido.'
                failure_reasons.append(text[:300])
                if len(failure_reasons) == 8:
                    break
    return {'status': status, 'criteria': criteria,
            'passed_criteria': sum(c['ok'] for c in criteria),
            'total_criteria': len(criteria), 'failure_reasons': failure_reasons,
            'output': output}


class ProgressStore:
    """Append-only event log; every connection has a bounded busy timeout."""

    def __init__(self, data_dir, catalog):
        self.catalog = sorted(catalog, key=lambda task: task['number'])
        self.tasks = {task['id']: task for task in self.catalog}
        Path(data_dir).mkdir(parents=True, exist_ok=True)
        self.path = Path(data_dir) / 'progress.sqlite3'
        with closing(self.connect()) as conn:
            conn.execute('PRAGMA journal_mode=WAL')
            conn.execute('''CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT NOT NULL, action TEXT NOT NULL,
                started_ns INTEGER NOT NULL, at TEXT NOT NULL,
                returncode INTEGER NOT NULL, result TEXT NOT NULL)''')
            conn.commit()

    def connect(self):
        conn = sqlite3.connect(self.path, timeout=10)
        conn.execute('PRAGMA busy_timeout=10000')
        conn.row_factory = sqlite3.Row
        return conn

    def record(self, task_id, action, output, returncode, *, started_ns=None):
        if action not in ('start', 'grade', 'finish'):
            raise ValueError('Unsupported lab action')
        task = self.tasks[task_id]
        result = parse_grade(output, returncode, task['hosts'])
        at = datetime.now(timezone.utc).isoformat(timespec='microseconds').replace('+00:00', 'Z')
        with closing(self.connect()) as conn, conn:
            conn.execute('BEGIN IMMEDIATE')
            conn.execute('INSERT INTO events(task_id,action,started_ns,at,returncode,result) VALUES(?,?,?,?,?,?)',
                         (task_id, action, started_ns if started_ns is not None else time.time_ns(),
                          at, returncode, json.dumps(result, ensure_ascii=False)))

    def state(self):
        tasks = {task['id']: dict(task, status='pending', passed_criteria=0, total_criteria=0,
                                 last_grade_at=None, last_action=None, attempts=0,
                                 criteria=[], failure_reasons=[], output='', history=[]) for task in self.catalog}
        updated_at = None
        with closing(self.connect()) as conn:
            events = conn.execute('SELECT * FROM events ORDER BY started_ns,id').fetchall()
        for event in events:
            if event['task_id'] not in tasks:
                continue
            task = tasks[event['task_id']]
            result = json.loads(event['result'])
            # Existing SQLite records predate failure_reasons; rebuild safely from criteria.
            result.setdefault('failure_reasons', [
                (criterion.get('text') or 'Critério não atendido.')[:300]
                for criterion in result.get('criteria', []) if not criterion.get('ok')
            ][:8])
            action = event['action']
            if action == 'grade' or (action == 'finish' and
                                     re.search(r'^RESULTADO:', result['output'], re.M)):
                task.update(result)
                task['attempts'] += 1
                task['last_grade_at'] = event['at']
            elif action == 'start' and event['returncode'] == 0:
                task.update(status='in_progress', criteria=[], failure_reasons=[], passed_criteria=0,
                            total_criteria=0, last_grade_at=None, output=result['output'])
            elif event['returncode'] != 0:
                task.update(status='error', output=result['output'])
            task['last_action'] = action
            task['history'].append(dict(action=action, status=task['status'], at=event['at'],
                                        returncode=event['returncode'], passed_criteria=result['passed_criteria'],
                                        total_criteria=result['total_criteria'],
                                        failure_reasons=result['failure_reasons']))
            updated_at = max(updated_at or '', event['at'])
        summary = dict(total=len(tasks), passed=0, pending=0, in_progress=0, failed=0, error=0)
        for task in tasks.values():
            summary[task['status']] += 1
        return dict(tasks=list(tasks.values()), summary=summary,
                    next_task=next((t['id'] for t in tasks.values() if t['status'] != 'passed'), None),
                    updated_at=updated_at)


def load_catalog(path):
    """Load the local, administrator-provided task catalog."""
    return json.loads(Path(path).read_text(encoding='utf-8'))


def main(argv=None):
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', default='0.0.0.0')
    parser.add_argument('--port', type=int, default=8421)
    parser.add_argument('--data-dir', default='/var/lib/rhcsa-lab-dashboard')
    parser.add_argument('--catalog', default='/opt/rhcsa-lab-dashboard/catalog.json')
    parser.add_argument('--static-dir', default='/opt/rhcsa-lab-dashboard')
    args = parser.parse_args(argv)
    store = ProgressStore(args.data_dir, load_catalog(args.catalog))
    server = create_server(args.host, args.port, store, args.static_dir)
    print(f'Listening on http://{args.host}:{server.server_port}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()


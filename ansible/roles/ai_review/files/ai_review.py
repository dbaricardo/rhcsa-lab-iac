#!/usr/bin/python3 -I
"""Revisão por IA de uma tentativa examsim-*.

Disparado em segundo plano pelo lab_wrapper após ``lab finish``: coleta as
gravações de terminal (/var/log/rhcsa-rec) de servera, serverb e da própria
workstation na janela start→finish, junta enunciado e saídas dos grades,
envia ao revisor configurado em /etc/rhcsa-ai-review.conf (SSH com forced
command, ver contrib/ai-reviewer/) e registra a resposta como evento
``review`` no painel e em ~/examsim-feedback/.
"""
import codecs
import io
import json
import os
import re
import subprocess
import sys
import tarfile
import time
from datetime import datetime, timezone
from pathlib import Path

if __name__ == '__main__':
    sys.path.insert(0, '/opt/rhcsa-lab-dashboard')

from backend import ProgressStore, load_catalog

REC_DIR = '/var/log/rhcsa-rec'
# "localhost" é a workstation: o dispatcher já confia na chave de student em root@localhost.
REC_HOSTS = (('servera', 'servera'), ('serverb', 'serverb'), ('localhost', 'workstation'))
SSH_OPTS = ['-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', '-o', 'StrictHostKeyChecking=accept-new']
# Revisor: vem de /etc/rhcsa-ai-review.conf (gerado pelo Ansible, role ai_review,
# a partir do .env). Nada do revisor fica fixo no código.
CONFIG_PATH = '/etc/rhcsa-ai-review.conf'
DEFAULT_REVIEWER_KEY = '.ssh/rhcsa_ai_review'
DEFAULT_REVIEW_TIMEOUT_S = 780
MAX_HOST_CHARS = 40_000
MAX_HOST_CHARS_FULL = 120_000
MAX_EVENT_OUTPUT = 12_000
MAX_LINE = 300
OUTPUT_KEEP_HEAD, OUTPUT_KEEP_TAIL = 12, 5
PROMPT = re.compile(r'^\[[^\]\s]+@[^\]\s]+ [^\]]*\][#$] ')
# Senhas passadas ao passwd/chpasswd por pipe (echo/printf, com ou sem aspas) ou here-string.
PASSWORD_PIPE = re.compile(r'(\b(?:echo|printf)\s+).*?(\s*\|\s*(?:sudo\s+)?(?:passwd|chpasswd)\b)')
PASSWORD_HERESTRING = re.compile(r'(\b(?:passwd|chpasswd)\b[^<]*<<<\s*).*$')
ALT_SCREEN_MODES = {'?1049', '?1047', '?47'}


class Terminal:
    """Emulador mínimo de linha: aplica \\r, \\b e CSI de edição do readline.

    Telas cheias (vim, less, man, top) viram um marcador, pois a revisão
    precisa dos comandos e das saídas, não do redesenho da tela.
    """

    def __init__(self):
        self.lines = []
        self.line, self.col, self.line_ts = [], 0, None
        self.alt = False
        self.state, self.params = 'normal', ''

    def _commit(self, ts):
        text = ''.join(self.line).rstrip()
        if text or (self.lines and self.lines[-1][1]):
            self.lines.append((self.line_ts if self.line_ts is not None else ts, text))
        self.line, self.col, self.line_ts = [], 0, None

    def _put(self, ch, ts):
        if self.alt:
            return
        if self.line_ts is None:
            self.line_ts = ts
        if self.col > len(self.line):
            self.line.extend(' ' * (self.col - len(self.line)))
        if self.col == len(self.line):
            self.line.append(ch)
        else:
            self.line[self.col] = ch
        self.col += 1

    def _csi(self, final, ts):
        params = self.params
        num = int(params) if params.isdigit() else 1
        if final in 'hl' and params in ALT_SCREEN_MODES:
            if final == 'h' and not self.alt:
                if self.line:
                    self._commit(ts)
                self.lines.append((ts, '⟦tela cheia (editor/pager) — conteúdo omitido⟧'))
            self.alt = final == 'h'
        elif self.alt:
            return
        elif final == 'K':
            if params in ('', '0'):
                del self.line[self.col:]
            elif params == '1':
                self.line[:self.col] = [' '] * min(self.col, len(self.line))
            elif params == '2':
                self.line, self.col = [], 0
        elif final == 'C':
            self.col += num
        elif final == 'D':
            self.col = max(0, self.col - num)
        elif final == 'G':
            self.col = max(0, num - 1)
        elif final == 'P':
            del self.line[self.col:self.col + num]
        elif final == '@':
            self.line[self.col:self.col] = [' '] * num
        elif final == 'X':
            for i in range(self.col, min(len(self.line), self.col + num)):
                self.line[i] = ' '

    def feed(self, text, ts):
        for ch in text:
            state = self.state
            if state == 'normal':
                if ch == '\x1b':
                    self.state = 'esc'
                elif ch == '\n':
                    if not self.alt:
                        self._commit(ts)
                elif ch == '\r':
                    self.col = 0
                elif ch == '\b':
                    self.col = max(0, self.col - 1)
                elif ch == '\t':
                    for _ in range(8 - self.col % 8):
                        self._put(' ', ts)
                elif ch >= ' ' and ch != '\x7f':
                    self._put(ch, ts)
            elif state == 'esc':
                if ch == '[':
                    self.state, self.params = 'csi', ''
                elif ch == ']':
                    self.state = 'osc'
                elif ch in '()*+':
                    self.state = 'charset'
                else:
                    self.state = 'normal'
            elif state == 'csi':
                if '\x40' <= ch <= '\x7e':
                    self.state = 'normal'
                    self._csi(ch, ts)
                else:
                    self.params += ch
            elif state == 'osc':
                if ch == '\x07':
                    self.state = 'normal'
                elif ch == '\x1b':
                    self.state = 'osc_esc'
            elif state == 'osc_esc':
                self.state = 'normal' if ch == '\\' else 'osc'
            else:  # charset: consome um caractere de designação
                self.state = 'normal'

    def finish(self, ts):
        if self.line:
            self._commit(ts)
        return self.lines


def replay(data, timing, t0, start, end):
    """Retorna [(epoch, linha)] da gravação, só com a saída dentro de [start, end]."""
    header, sep, rest = data.partition(b'\n')
    if header.startswith(b'Script started on') and sep:
        data = rest
    decoder = codecs.getincrementaldecoder('utf-8')('replace')
    term, pos, now = Terminal(), 0, t0
    for raw in timing.splitlines():
        try:
            delay, size = raw.split()
            now += float(delay)
            size = int(size)
        except ValueError:
            continue
        chunk = decoder.decode(data[pos:pos + size])
        pos += size
        if start - 1 <= now <= end + 1:
            term.feed(chunk, now)
    return term.finish(now)


def format_transcript(lines, start, limit):
    """Marca prompts com tempo desde o start e resume saídas longas."""
    out, block = [], []

    def flush():
        if len(block) > OUTPUT_KEEP_HEAD + OUTPUT_KEEP_TAIL + 1:
            omitted = len(block) - OUTPUT_KEEP_HEAD - OUTPUT_KEEP_TAIL
            block[OUTPUT_KEEP_HEAD:-OUTPUT_KEEP_TAIL] = [f'         … ({omitted} linhas de saída omitidas)']
        out.extend(block)
        block.clear()

    for ts, text in lines:
        text = PASSWORD_HERESTRING.sub(r'\1[REDACTED]', PASSWORD_PIPE.sub(r'\1[REDACTED]\2', text))
        if len(text) > MAX_LINE:
            text = text[:MAX_LINE] + ' …'
        if PROMPT.match(text):
            flush()
            elapsed = max(0, int(ts - start))
            out.append(f'+{elapsed // 60:02d}:{elapsed % 60:02d}  {text}')
        else:
            block.append(f'         {text}')
    flush()
    text = '\n'.join(out)
    if len(text) > limit:
        half = limit // 2
        text = f'{text[:half]}\n… (transcrição cortada no meio) …\n{text[-half:]}'
    return text


def fetch_recordings(host, start):
    """Baixa via tar as gravações modificadas desde o start: {base: {'out': b, 'tm': b}}."""
    remote = (f'cd {REC_DIR} 2>/dev/null || exit 0; '
              f"find . -maxdepth 1 \\( -name '*.out' -o -name '*.tm' \\) -newermt @{int(start)} -print0"
              ' | tar --null -T - -cf - 2>/dev/null')
    proc = subprocess.run(['ssh', *SSH_OPTS, f'root@{host}', remote],
                          capture_output=True, timeout=60)
    if proc.returncode != 0:
        # Host fora do ar ou SSH negado não pode virar "aluno sem gravação".
        raise subprocess.CalledProcessError(proc.returncode, 'ssh')
    files = {}
    if not proc.stdout:
        return files
    with tarfile.open(fileobj=io.BytesIO(proc.stdout)) as tar:
        for member in tar.getmembers():
            name = Path(member.name).name
            base, _, kind = name.rpartition('.')
            if member.isfile() and kind in ('out', 'tm'):
                files.setdefault(base, {})[kind] = tar.extractfile(member).read()
    return files


def collect_transcripts(start, end, limit):
    transcripts = []
    for host, label in REC_HOSTS:
        try:
            recordings = fetch_recordings(host, start)
        except (OSError, subprocess.SubprocessError, tarfile.TarError) as exc:
            transcripts.append({'host': label, 'user': '-', 'error': f'coleta falhou: {type(exc).__name__}'})
            continue
        for base, parts in sorted(recordings.items()):
            match = re.fullmatch(r'(\d+(?:\.\d+)?)-(.+)-(\d+)', base)
            if not match or 'out' not in parts or 'tm' not in parts:
                continue
            t0 = float(match[1])
            if t0 > end:
                continue
            lines = replay(parts['out'], parts['tm'].decode('ascii', 'replace'), t0, start, end)
            if any(text for _, text in lines):
                transcripts.append({'host': label, 'user': match[2],
                                    'text': format_transcript(lines, start, limit)})
    return transcripts


def build_payload(task, attempt, now_ns, home):
    start = attempt['started_ns'] / 1e9
    end = now_ns / 1e9
    # As duas provas completas têm enunciado próprio e transcrição maior.
    exam_dir = {'examsim-full': 'examsim-full', 'examsim-dinamico': 'examsim-dinamico'}.get(task['id'])
    full = exam_dir is not None
    enunciado = ''
    if full:
        try:
            enunciado = (home / exam_dir / 'enunciado.txt').read_text(
                encoding='utf-8', errors='replace')[:20_000]
        except OSError:
            enunciado = ''
    return {
        'task': {key: task.get(key) for key in
                 ('id', 'title', 'description', 'instructions', 'warning', 'hosts', 'solve_target')},
        'enunciado': enunciado,
        'attempt': {'started_at': attempt['started_at'],
                    'duration_s': int(end - start)},
        'events': [dict(event, output=event['output'][-MAX_EVENT_OUTPUT:])
                   for event in attempt['events']],
        'transcripts': collect_transcripts(start, end, MAX_HOST_CHARS_FULL if full else MAX_HOST_CHARS),
    }


def load_config(path=CONFIG_PATH):
    """Lê KEY=VALUE (RHCSA_AI_REVIEWER, RHCSA_AI_REVIEW_KEY, RHCSA_AI_REVIEW_TIMEOUT)."""
    values = {}
    try:
        lines = Path(path).read_text(encoding='utf-8').splitlines()
    except OSError:
        lines = []
    for line in lines:
        key, sep, value = line.strip().partition('=')
        if sep and key and not key.startswith('#'):
            values[key.strip()] = value.strip().strip('"\'')
    try:
        timeout = int(values.get('RHCSA_AI_REVIEW_TIMEOUT') or DEFAULT_REVIEW_TIMEOUT_S)
    except ValueError:
        timeout = DEFAULT_REVIEW_TIMEOUT_S
    return {'reviewer': values.get('RHCSA_AI_REVIEWER', ''),
            'key': values.get('RHCSA_AI_REVIEW_KEY') or DEFAULT_REVIEWER_KEY,
            'timeout': max(30, timeout)}


def ask_reviewer(payload, home, config=None):
    config = config or load_config()
    if not re.fullmatch(r'[A-Za-z0-9._-]+@[A-Za-z0-9.:_-]+', config['reviewer']):
        raise RuntimeError(f'revisor não configurado em {CONFIG_PATH} (RHCSA_AI_REVIEWER=usuario@host)')
    key = Path(config['key'])
    cmd = ['ssh', *SSH_OPTS, '-i', str(key if key.is_absolute() else home / key),
           '-o', 'IdentitiesOnly=yes', config['reviewer'], 'review']
    proc = subprocess.run(cmd, input=json.dumps(payload, ensure_ascii=False).encode(),
                          capture_output=True, timeout=config['timeout'])
    if proc.returncode != 0 or not proc.stdout.strip():
        detail = proc.stderr.decode('utf-8', 'replace').strip().splitlines()[-1:] or ['sem detalhe']
        raise RuntimeError(f'revisor retornou {proc.returncode}: {detail[0][:200]}')
    return proc.stdout.decode('utf-8', 'replace').strip()


def run(task_id, finish_ns, *, catalog_path, data_dir, home):
    catalog = load_catalog(catalog_path)
    store = ProgressStore(data_dir, catalog)
    task = store.tasks[task_id]
    attempt = store.attempt(task_id, until_ns=finish_ns)
    base = dict(attempt_started_at=attempt['started_at'] if attempt else None)
    store.record_review(task_id, dict(base, state='running'), started_ns=finish_ns + 1)
    try:
        if attempt is None:
            raise RuntimeError('nenhum lab start encontrado para esta tentativa')
        payload = build_payload(task, attempt, time.time_ns(), home)
        markdown = ask_reviewer(payload, home)
    except Exception as exc:
        store.record_review(task_id, dict(base, state='error', error=str(exc)[:300]),
                            started_ns=finish_ns + 2)
        raise
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    feedback_dir = home / 'examsim-feedback'
    feedback_dir.mkdir(mode=0o700, exist_ok=True)
    feedback_dir.chmod(0o700)
    target = feedback_dir / f'{task_id}-{stamp}.md'
    target.write_text(markdown + '\n', encoding='utf-8')
    target.chmod(0o600)
    store.record_review(task_id, dict(base, state='done', markdown=markdown[:60_000],
                                      sessions=len(payload['transcripts'])),
                        started_ns=finish_ns + 2)
    return 0


def main(argv):
    if len(argv) != 2 or not argv[1].isdigit():
        print('uso: ai_review.py <task_id> <finish_started_ns>', file=sys.stderr)
        return 2
    return run(argv[0], int(argv[1]), catalog_path='/opt/rhcsa-lab-dashboard/catalog.json',
               data_dir='/var/lib/rhcsa-lab-dashboard', home=Path.home())


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

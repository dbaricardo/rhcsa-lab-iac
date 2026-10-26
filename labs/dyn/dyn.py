#!/usr/bin/python3
"""Motor do exame dinâmico: sorteia as questões e gera os passos para o orquestrador.

Só biblioteca padrão. O orquestrador bash (examsim-dinamico.sh) chama os
subcomandos abaixo; a lógica de sorteio fica aqui para ser testável.

  draw      sorteia a prova e grava o manifesto privado (JSON)
  steps     passos executáveis (TSV) de start | grade | finish
  questions lista "q<TAB>título" na ordem da prova
  hosts     hosts que a prova toca
  bind      troca @DISK@ pelos discos reais de cada host (lsblk)
  statement enunciado completo para o terminal
  public    JSON público (sem params) para o painel
  archive   fecha a prova com os resultados e imprime o JSON público
  summary   linhas finais da correção (RESULTADO, nota, domínios)
"""
import argparse
import json
import math
import random
import re
import shlex
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

LS = '/usr/local/lib/lab-scripts'
LF = '/usr/local/lib/lab-finish'
LG = '/usr/local/lib/lab-grade'
SB = 'bash /usr/local/lib/lab-full/examsim-full-serverb.sh'

DEFAULT_COUNT = 24
MIN_PER_DOMAIN = 2
PASS_RATIO = 0.70
MAX_ATTEMPTS = 50
# Discos de pratica novos em cada host (os legados de 1 e 6 GiB da serverb ficam
# com o grupo storage-serverb). A tarefa acha o disco pelo tamanho exato.
DISK_SIZES = (2 * 1024**3, 3 * 1024**3)
DISK_CAPACITY = len(DISK_SIZES)
LEGACY_DISK_SIZES = {'@DISCO1@': 1 * 1024**3, '@DISCO6@': 6 * 1024**3}
KEY_RE = re.compile(r'^[A-Z][A-Z0-9_]*$')
# Variaveis que o bash controla (ou o ambiente usa): um parametro com esse nome seria ignorado
# ou mudaria o comportamento dos comandos da tarefa (ja deu problema com HOSTNAME, UID, GROUPS).
RESERVED_KEYS = frozenset((
    'UID', 'EUID', 'GROUPS', 'HOSTNAME', 'HOSTTYPE', 'OSTYPE', 'MACHTYPE', 'PPID', 'BASHPID', 'RANDOM',
    'SECONDS', 'LINENO', 'SHLVL', 'PWD', 'OLDPWD', 'IFS', 'PATH', 'HOME', 'USER', 'LOGNAME', 'SHELL',
    'TERM', 'LANG', 'OPTIND', 'OPTARG', 'OPTERR', 'PS1', 'PS2', 'PS4', 'BASH', 'BASH_VERSION', 'EPOCHSECONDS',
    'ENV', 'TMPDIR', 'MAIL', 'TZ'))
# Credencial de exercício que o painel (HTTP na LAN) não deve exibir.
PUBLIC_MASKS = (('atenorth', '‹credencial do exercício: veja o enunciado no terminal›'),)


class DrawError(Exception):
    """O pool não consegue satisfazer o mínimo por domínio."""


def load_pool(path):
    pool = json.loads(Path(path).read_text(encoding='utf-8'))
    ids = [t['id'] for t in pool['tasks']]
    if len(ids) != len(set(ids)):
        raise ValueError('ids duplicados no pool')
    for task in pool['tasks']:
        keys = list(task.get('params') or {})
        for pset in task.get('param_sets') or []:
            keys += list(pset)
        for key in keys:
            if not KEY_RE.match(key) or key in RESERVED_KEYS:
                raise ValueError(f"parâmetro inválido em {task['id']}: {key}")
    return pool


def quotas(domains, count=DEFAULT_COUNT, minimum=MIN_PER_DOMAIN):
    """Questões por domínio: mínimo garantido, resto pelo peso (maior resto)."""
    ids = sorted(domains)
    if count < minimum * len(ids):
        raise ValueError(f'{count} questões não cobrem {minimum} por domínio')
    total = sum(d['weight'] for d in domains.values())
    ideal = {n: count * domains[n]['weight'] / total for n in ids}
    quota = {n: max(minimum, int(ideal[n])) for n in ids}
    while sum(quota.values()) < count:
        n = max(ids, key=lambda i: (ideal[i] - quota[i], domains[i]['weight']))
        quota[n] += 1
    while sum(quota.values()) > count:
        n = min((i for i in ids if quota[i] > minimum), key=lambda i: ideal[i] - quota[i])
        quota[n] -= 1
    return quota


def render(text, mapping):
    """Troca {CHAVE}; repete porque um valor (ex.: WHAT) pode conter outro {CHAVE}."""
    for _ in range(3):
        before = text
        for key, value in mapping.items():
            text = text.replace('{' + key + '}', str(value))
        if text == before:
            break
    return text


def _resources(task, host):
    return {r.replace('{host}', host) for r in task.get('conflicts', [])}


def _blocked(task, host, claimed):
    group = task.get('group')
    return any(r in claimed and (group is None or claimed[r] != group)
               for r in _resources(task, host))


def _make_params(task, rng):
    params = {}
    if task.get('param_sets'):
        params.update(rng.choice(task['param_sets']))
    for key, spec in (task.get('params') or {}).items():
        if 'int' in spec:
            params[key] = str(rng.randint(*spec['int']))
        else:
            params[key] = rng.choice(spec['choice'])
    return params


def _attempt(pool, quota, rng):
    chosen, used, claimed, cat_use = [], set(), {}, Counter()
    disk_used = Counter()
    for dom in sorted(quota):
        cands = [t for t in pool['tasks'] if t['domain'] == dom and not t.get('extra')]
        for filled in range(quota[dom]):
            options = [
                (t, h) for t in cands if t['id'] not in used for h in t['hosts']
                if not _blocked(t, h, claimed)
                and disk_used[h] + t.get('disk_slots', 0) <= DISK_CAPACITY
                and not (t.get('console') and any(c[0].get('console') for c in chosen))]
            if not options:
                raise DrawError(f'domínio {dom}: só {filled} de {quota[dom]} questões elegíveis')
            least = min(cat_use[(dom, t['category'])] for t, _ in options)
            options = [o for o in options if cat_use[(dom, o[0]['category'])] == least]
            task, host = rng.choice(options)
            used.add(task['id'])
            cat_use[(dom, task['category'])] += 1
            for res in _resources(task, host):
                claimed.setdefault(res, task.get('group') or task['id'])
            params = _make_params(task, rng)
            slots = task.get('disk_slots', 0)
            if slots:
                first = disk_used[host]
                params['DSIZE'] = str(DISK_SIZES[first])
                if slots > 1:
                    params['DSIZE2'] = str(DISK_SIZES[first + 1])
                disk_used[host] += slots
            chosen.append((task, host, params))
    return chosen


def draw(pool, count=DEFAULT_COUNT, minimum=MIN_PER_DOMAIN, seed=None, now=None):
    seed = random.SystemRandom().randrange(1, 2**31) if seed is None else int(seed)
    quota = quotas({int(k): v for k, v in pool['domains'].items()}, count, minimum)
    last = None
    for attempt in range(MAX_ATTEMPTS):
        rng = random.Random(f'{seed}:{attempt}')
        try:
            chosen = _attempt(pool, quota, rng)
        except DrawError as exc:
            last = exc
            continue
        rng.shuffle(chosen)
        return _manifest(pool, quota, chosen, seed, count, minimum, now)
    raise DrawError(f'pool não satisfaz a prova após {MAX_ATTEMPTS} tentativas: {last}')


def _manifest(pool, quota, chosen, seed, count, minimum, now):
    when = now or datetime.now(timezone.utc)
    domains = {n: pool['domains'][str(n)] for n in quota}
    questions, groups = [], {}
    for number, (task, host, params) in enumerate(chosen, 1):
        mapping = dict(params, host=host)
        question = {
            'q': number, 'id': task['id'], 'kind': task['kind'], 'title': task['title'],
            'domain': task['domain'], 'domain_name': domains[task['domain']]['name'],
            'category': task['category'], 'host': host, 'console': bool(task.get('console')),
            'order': task['order'], 'statement': render(task['statement'], mapping),
            'params': params}
        for key in ('group', 'grade_env', 'extra_hosts', 'server_hosts', 'disk_slots'):
            if task.get(key):
                question[key] = task[key]
        if task.get('group'):
            groups[task['group']] = pool['groups'][task['group']]
        questions.append(question)
    return {
        'version': 1, 'id': 'dyn-' + when.strftime('%Y%m%dT%H%M%SZ'), 'seed': seed,
        'count': count, 'minimum': minimum, 'pass_ratio': PASS_RATIO,
        'pass_mark': math.ceil(PASS_RATIO * count),
        'started_at': when.isoformat(timespec='seconds').replace('+00:00', 'Z'),
        'domains': {str(n): {'name': domains[n]['name'], 'quota': quota[n]} for n in quota},
        'groups': groups, 'questions': questions}


def _env_words(params):
    return ' '.join(f'{k}={shlex.quote(str(v))}' for k, v in sorted(params.items()))


def steps(manifest, phase, only_q=None):
    """Passos como tuplas (q, label, host, kind, a, b); kind é cmd ou script."""
    questions = manifest['questions']
    if phase == 'grade':
        out = []
        for ques in questions:
            if only_q is not None and ques['q'] != only_q:
                continue
            hosts = [ques['host']] + list(ques.get('extra_hosts', []))
            for host in hosts:
                out.append(_grade_step(ques, host))
        return out
    entries = []
    for ques in questions:
        if ques.get('group'):
            continue
        extra = ques.get('server_hosts', []) if ques['kind'] == 'ported' else ques.get('extra_hosts', [])
        for sub, host in enumerate(list(extra) + [ques['host']]):
            entries.append((ques['order'], sub, _phase_step(ques, host, phase)))
    for name, group in manifest.get('groups', {}).items():
        action = group['start' if phase == 'start' else 'finish']
        entries.append((group['order'], 0, (0, f'group:{name}', group['host'], 'cmd',
                                            f'{SB} {action}', '')))
    entries.sort(key=lambda e: (e[0], e[1]))
    ordered = [e[2] for e in entries]
    return ordered if phase == 'start' else ordered[::-1]


def _phase_step(ques, host, phase):
    if ques['kind'] == 'ported':
        # Preparo do servidor NFS (na workstation) usa a fase server-start/server-finish.
        fn = f'server-{phase}' if host in ques.get('server_hosts', []) else phase
        return (ques['q'], ques['id'], host, 'script',
                f"tasks/{ques['id']}.sh|{fn}", _env_words(ques['params']))
    base = {'start': LS, 'finish': LF}[phase]
    return (ques['q'], ques['id'], host, 'cmd', f"bash {base}/{ques['id']}.sh", '')


def _grade_step(ques, host):
    if ques['kind'] == 'ported':
        return (ques['q'], ques['id'], host, 'script',
                f"tasks/{ques['id']}.sh|grade", _env_words(ques['params']))
    env = ques.get('grade_env', '')
    cmd = f"{env} bash {LG}/{ques['id']}.sh".strip()
    return (ques['q'], ques['id'], host, 'cmd', cmd, '')


def bind(manifest, disks):
    """Troca @DISK@/@DISK2@ (e @DISCO1@/@DISCO6@ dos legados) pelos nomes reais.

    disks: {host: {tamanho_em_bytes: '/dev/sdX'}}, lido do lsblk de cada host.
    """
    for ques in manifest['questions']:
        by_size = disks.get(ques['host'], {})
        repl = {}
        for token, key in (('@DISK@', 'DSIZE'), ('@DISK2@', 'DSIZE2')):
            if key in ques['params']:
                repl[token] = by_size.get(int(ques['params'][key]))
        if ques['kind'] == 'legacy':
            for token, size in LEGACY_DISK_SIZES.items():
                repl[token] = by_size.get(size)
        for token, dev in repl.items():
            if dev:
                ques['statement'] = ques['statement'].replace(token, dev)
    return manifest


def parse_disks(text):
    disks = {}
    for line in text.splitlines():
        parts = line.split('\t')
        if len(parts) == 3 and parts[2].isdigit():
            disks.setdefault(parts[0], {})[int(parts[2])] = '/dev/' + parts[1]
    return disks


def hosts(manifest):
    seen = []
    for step in steps(manifest, 'start') + steps(manifest, 'grade'):
        if step[2] not in seen:
            seen.append(step[2])
    return seen


UNBOUND = {'@DISK@': '[disco de prática]', '@DISK2@': '[2º disco de prática]',
           '@DISCO1@': '[disco de 1 GiB]', '@DISCO6@': '[disco de 6 GiB]'}


def _unbound(text):
    """Nenhum token @X@ pode chegar ao aluno nem ao painel, mesmo se o bind falhar."""
    for token, repl in UNBOUND.items():
        text = text.replace(token, repl)
    return text


def _mask(text):
    for secret, repl in PUBLIC_MASKS:
        text = text.replace(secret, repl)
    return _unbound(text)


def statement(manifest, disco1='disco de 1 GiB', disco6='disco de 6 GiB'):
    lines = ['=' * 79,
             f"EXAME DINÂMICO RHCSA (EX200) — {manifest['count']} questões sorteadas — tempo sugerido 3h",
             '=' * 79,
             'servera: ssh servera (192.168.56.20) · serverb: ssh serverb (192.168.56.30 · console: virsh console rhcsa-lab-serverb ou virt-viewer)',
             'NFS = workstation.lab.example.com (192.168.56.10)', '',
             'Regras:',
             '- Tudo deve ficar PERSISTENTE (sobreviver a reboot), como na prova real.',
             '- A correção acontece só no final: lab finish examsim-dinamico.',
             f"- Referência de aprovação: {manifest['pass_mark']}/{manifest['count']} (70%).",
             '- Se houver a questão de repositórios do servera, resolva-a antes de instalar pacotes.',
             '- Senha de exercício para contas pedidas: atenorth', '',
             'Domínios sorteados (mínimo de ' + str(manifest['minimum']) + ' por domínio):']
    for n, dom in sorted(manifest['domains'].items(), key=lambda kv: int(kv[0])):
        lines.append(f"  D{n} {dom['name']}: {dom['quota']}")
    lines.append('-' * 79)
    for ques in manifest['questions']:
        body = ques['statement'] if ques['kind'] == 'legacy' else f"{ques['title']} — {ques['statement']}"
        body = _unbound(body.replace('@DISCO1@', disco1).replace('@DISCO6@', disco6))
        lines += [f"Q{ques['q']:02d} [{ques['host']} · D{ques['domain']} {ques['domain_name']}]", f'    {body}', '']
    return '\n'.join(lines)


def public(manifest, state='open', results=None):
    results = results or manifest.get('results')
    questions = []
    for ques in manifest['questions']:
        item = {k: ques[k] for k in ('q', 'id', 'kind', 'title', 'domain', 'domain_name',
                                     'category', 'host', 'console')}
        item['statement'] = _mask(ques['statement'])
        if results and str(ques['q']) in results:
            item.update(results[str(ques['q'])])
        questions.append(item)
    out = {'id': manifest['id'], 'state': state, 'seed': manifest['seed'],
           'started_at': manifest['started_at'], 'count': manifest['count'],
           'minimum': manifest['minimum'], 'pass_mark': manifest['pass_mark'],
           'domains': [{'n': int(n), 'name': d['name'], 'quota': d['quota']}
                       for n, d in sorted(manifest['domains'].items(), key=lambda kv: int(kv[0]))],
           'questions': questions}
    for key in ('finished_at', 'score', 'by_domain'):
        if manifest.get(key) is not None:
            out[key] = manifest[key]
    return out


def parse_results(text):
    results = {}
    for line in text.splitlines():
        parts = line.split('\t', 2)
        if len(parts) >= 2 and parts[0].isdigit() and parts[1] in ('OK', 'FALHOU'):
            results[parts[0]] = {'ok': parts[1] == 'OK',
                                 'pending': parts[2].strip() if len(parts) > 2 else ''}
    return results


def score(manifest, results):
    passed = sum(1 for q in manifest['questions'] if results.get(str(q['q']), {}).get('ok'))
    by_domain = {}
    for ques in manifest['questions']:
        slot = by_domain.setdefault(str(ques['domain']), {'passed': 0, 'total': 0})
        slot['total'] += 1
        slot['passed'] += bool(results.get(str(ques['q']), {}).get('ok'))
    total = len(manifest['questions'])
    return {'passed': passed, 'total': total, 'pass_mark': manifest['pass_mark'],
            'percent': passed * 100 // total, 'approved': passed >= manifest['pass_mark']}, by_domain


def archive(manifest, results, finished_at=None):
    when = finished_at or datetime.now(timezone.utc)
    closed = dict(manifest, results=results,
                  finished_at=when.isoformat(timespec='seconds').replace('+00:00', 'Z'))
    closed['score'], closed['by_domain'] = score(manifest, results)
    return public(closed, 'closed', results)


def summary(manifest, results):
    sc, by_domain = score(manifest, results)
    lines = ['RESULTADO: PASSOU' if sc['passed'] == sc['total'] else 'RESULTADO: FALHOU',
             f"Nota {sc['passed']}/{sc['total']} ({sc['percent']}%) — referência "
             f"{sc['pass_mark']}/{sc['total']} → {'APROVADO' if sc['approved'] else 'REPROVADO'}"]
    for n, slot in sorted(by_domain.items(), key=lambda kv: int(kv[0])):
        lines.append(f"Domínio {n} — {manifest['domains'][n]['name']}: {slot['passed']}/{slot['total']}")
    return '\n'.join(lines)


def _load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('draw')
    p.add_argument('--pool', required=True)
    p.add_argument('--out', required=True)
    p.add_argument('--count', type=int, default=DEFAULT_COUNT)
    p.add_argument('--min', type=int, default=MIN_PER_DOMAIN, dest='minimum')
    p.add_argument('--seed')
    p = sub.add_parser('steps')
    p.add_argument('manifest')
    p.add_argument('phase', choices=('start', 'grade', 'finish'))
    p.add_argument('--q', type=int)
    for name in ('questions', 'hosts', 'public'):
        sub.add_parser(name).add_argument('manifest')
    p = sub.add_parser('bind')
    p.add_argument('manifest')
    p.add_argument('disks')
    p = sub.add_parser('statement')
    p.add_argument('manifest')
    p.add_argument('--disco1', default='disco de 1 GiB')
    p.add_argument('--disco6', default='disco de 6 GiB')
    for name in ('archive', 'summary'):
        p = sub.add_parser(name)
        p.add_argument('manifest')
        p.add_argument('results')
    args = parser.parse_args(argv)

    if args.cmd == 'draw':
        try:
            manifest = draw(load_pool(args.pool), args.count, args.minimum, args.seed)
        except (DrawError, ValueError) as exc:
            print(f'ERRO: {exc}', file=sys.stderr)
            return 2
        Path(args.out).write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding='utf-8')
        print(f"prova {manifest['id']} seed={manifest['seed']} questões={len(manifest['questions'])}")
        return 0
    manifest = _load(args.manifest)
    if args.cmd == 'steps':
        for step in steps(manifest, args.phase, args.q):
            print('\t'.join(str(x) for x in step))
    elif args.cmd == 'bind':
        disks = parse_disks(Path(args.disks).read_text(encoding='utf-8'))
        Path(args.manifest).write_text(
            json.dumps(bind(manifest, disks), ensure_ascii=False, indent=1), encoding='utf-8')
    elif args.cmd == 'questions':
        for ques in manifest['questions']:
            print(f"{ques['q']}\t{ques['title']}")
    elif args.cmd == 'hosts':
        print('\n'.join(hosts(manifest)))
    elif args.cmd == 'statement':
        print(statement(manifest, args.disco1, args.disco6))
    elif args.cmd == 'public':
        print(json.dumps(public(manifest), ensure_ascii=False))
    else:
        results = parse_results(Path(args.results).read_text(encoding='utf-8'))
        if args.cmd == 'archive':
            print(json.dumps(archive(manifest, results), ensure_ascii=False))
        else:
            print(summary(manifest, results))
    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Valida labs/catalog.json (escrito à mão, igual ao homelab).

Antes este script agregava labs/<slug>/meta.json. Desde o porte do lab do
homelab, o catálogo é a fonte de verdade escrita à mão (como em
rhcsa-lab-dashboard/catalog.json): 27 entradas, `number` 0 para as provas
orquestradas. `make catalog` (dependência de `infra`/`provision`) agora só
valida -- falha cedo, antes do Terraform/Ansible, em vez de o painel subir
com um catálogo que ele próprio rejeitaria.

Valida o formato descrito em labs/catalog.schema.json sem depender do pacote
`jsonschema` (stdlib apenas) e as regras que o dashboard e o lab_wrapper
assumem: ids únicos, números 1..N sem buraco, `ssh`/`console` coerentes.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / 'labs' / 'catalog.json'
HOSTS = ('workstation', 'servera', 'serverb')
REQUIRED = {'id': str, 'number': int, 'title': str, 'host': str, 'hosts': list,
            'description': str, 'instructions': list, 'warning': str, 'solve_target': str,
            'solve_method': str, 'solve_command': str, 'solve_note': str}
OPTIONAL = {'grade': bool, 'dynamic': bool, 'exam_limit_minutes': int}
ORCHESTRATED = {'examsim-full', 'examsim-dinamico'}


def is_type(value, kind):
    # bool é subclasse de int em Python: nunca aceitar True como número.
    if kind is int:
        return isinstance(value, int) and not isinstance(value, bool)
    return isinstance(value, kind)


def task_errors(task):
    errors = []
    if not isinstance(task, dict):
        return ['entrada não é objeto']
    for key, kind in {**REQUIRED, **OPTIONAL}.items():
        if key in task and not is_type(task[key], kind):
            errors.append(f'{key} deve ser {kind.__name__}')
    errors += [f'falta {key}' for key in REQUIRED if key not in task]
    errors += [f'campo desconhecido {key}' for key in task if key not in REQUIRED and key not in OPTIONAL]
    if errors:
        return errors
    if not re.fullmatch(r'examsim-[a-z0-9-]+', task['id']):
        errors.append('id fora do padrão examsim-*')
    if task['number'] < 0:
        errors.append('number negativo')
    if not task['hosts'] or len(set(task['hosts'])) != len(task['hosts']) \
            or any(h not in HOSTS for h in task['hosts']):
        errors.append(f'hosts inválido: {task["hosts"]}')
    if not task['instructions'] or not all(isinstance(i, str) for i in task['instructions']):
        errors.append('instructions vazio ou não-texto')
    method, command = task['solve_method'], task['solve_command']
    if method == 'ssh' and not re.fullmatch(r'ssh (servera|serverb)', command):
        errors.append('solve_method=ssh exige solve_command "ssh servera|serverb"')
    elif method == 'console' and command != '':
        errors.append('solve_method=console exige solve_command vazio')
    elif method not in ('ssh', 'console'):
        errors.append('solve_method deve ser ssh ou console')
    for key in ('title', 'solve_target', 'solve_note'):
        if not task[key].strip():
            errors.append(f'{key} vazio')
    if task.get('exam_limit_minutes', 1) < 1:
        errors.append('exam_limit_minutes < 1')
    return errors


def validate(tasks):
    if not isinstance(tasks, list) or not tasks:
        return ['catálogo deve ser uma lista não vazia']
    errors = []
    for index, task in enumerate(tasks):
        label = task.get('id', f'#{index}') if isinstance(task, dict) else f'#{index}'
        errors += [f'{label}: {e}' for e in task_errors(task)]
    if errors:
        return errors
    ids = [t['id'] for t in tasks]
    if len(ids) != len(set(ids)):
        errors.append('ids duplicados')
    zero = sorted(t['id'] for t in tasks if t['number'] == 0)
    if set(zero) - ORCHESTRATED:
        errors.append(f'number 0 é reservado às provas orquestradas: {zero}')
    numbered = sorted(t['number'] for t in tasks if t['number'] > 0)
    if numbered != list(range(1, len(numbered) + 1)):
        errors.append(f'numeração 1..N com buraco ou repetição: {numbered}')
    return errors


def main():
    try:
        tasks = json.loads(CATALOG.read_text(encoding='utf-8'))
    except (OSError, ValueError) as exc:
        raise SystemExit(f'{CATALOG.relative_to(ROOT)}: ilegível ({exc})')
    errors = validate(tasks)
    if errors:
        raise SystemExit(f'{CATALOG.relative_to(ROOT)} inválido:\n  ' + '\n  '.join(errors))
    print(f'{CATALOG.relative_to(ROOT)}: {len(tasks)} entradas válidas')
    return 0


if __name__ == '__main__':
    sys.exit(main())

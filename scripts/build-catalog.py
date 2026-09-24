#!/usr/bin/env python3
"""Agrega labs/<slug>/meta.json em labs/catalog.json (formato consumido pelo
dashboard e pelo dispatcher `lab`). Roda antes de `vagrant up`/`provision`
(ver Makefile: `catalog` é dependência de `up`/`reprovision`)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LABS_DIR = ROOT / 'labs'
OUT_PATH = LABS_DIR / 'catalog.json'
REQUIRED = ('id', 'number', 'title', 'domain', 'hosts', 'description', 'instructions')


def load_tasks():
    tasks = []
    for meta_path in sorted(LABS_DIR.glob('*/meta.json')):
        data = json.loads(meta_path.read_text(encoding='utf-8'))
        missing = [key for key in REQUIRED if key not in data]
        if missing:
            raise SystemExit(f'{meta_path}: campos obrigatórios ausentes: {missing}')
        if data['id'] != meta_path.parent.name:
            raise SystemExit(
                f"{meta_path}: id '{data['id']}' não corresponde ao diretório "
                f"'{meta_path.parent.name}'")
        for action in ('start', 'grade', 'finish'):
            script = meta_path.parent / f'{action}.sh'
            if not script.exists():
                raise SystemExit(f'{meta_path.parent}: falta {action}.sh')
        data.setdefault('host', data['hosts'][0])
        tasks.append(data)
    return tasks


def main():
    tasks = load_tasks()
    ids = [t['id'] for t in tasks]
    if len(ids) != len(set(ids)):
        raise SystemExit(f'ids duplicados em labs/*/meta.json: {ids}')
    tasks.sort(key=lambda t: t['number'])
    OUT_PATH.write_text(
        json.dumps(tasks, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{OUT_PATH.relative_to(ROOT)}: {len(tasks)} exercícios')


if __name__ == '__main__':
    sys.exit(main())

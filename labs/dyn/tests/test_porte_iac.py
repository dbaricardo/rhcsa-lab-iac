"""Guardas do porte homelab -> iac: nenhum IP do homelab sobra e o pool continua identico."""
import importlib.util
import json
import re
import unittest
from pathlib import Path

DYN_DIR = Path(__file__).resolve().parent.parent
POOL_PATH = DYN_DIR / 'pool.json'
spec = importlib.util.spec_from_file_location('dyn', DYN_DIR / 'dyn.py')
dyn = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dyn)

# Textos do homelab que nao podem chegar ao iac (tabela de traducao do CONTRATO.md).
HOMELAB_PATTERNS = (r'192\.168\.10\.', r'\bVM 13[0-2]\b', r'noVNC', r'\bqm (reboot|monitor|start)\b')


def _engine_files():
    for path in sorted(DYN_DIR.rglob('*')):
        if path.is_file() and '__pycache__' not in path.parts and path.suffix in ('.py', '.sh', '.json', '.md'):
            if path.name == Path(__file__).name:
                continue  # este arquivo cita os padroes de proposito
            yield path


class HomelabLeftoversTests(unittest.TestCase):
    def test_no_homelab_ip_or_console_text_left_in_labs_dyn(self):
        for path in _engine_files():
            text = path.read_text(encoding='utf-8')
            for pattern in HOMELAB_PATTERNS:
                found = re.search(pattern, text)
                self.assertIsNone(found, f'{path.relative_to(DYN_DIR)}: sobrou "{found and found.group(0)}"')

    def test_translated_values_are_in_place(self):
        lib = (DYN_DIR / 'tasks' / '_lib.sh').read_text(encoding='utf-8')
        self.assertIn('NFS_SERVER_IP=192.168.56.10', lib)
        self.assertIn('MIRROR=http://content.example.com:8091', lib)
        self.assertIn('FP_URL=http://flatpak.lab.example.com:8091/myrepo.flatpakrepo', lib)
        header = dyn.statement(dyn.draw(dyn.load_pool(POOL_PATH), seed=1))
        self.assertIn('192.168.56.20', header)
        self.assertIn('192.168.56.30', header)
        self.assertIn('192.168.56.10', header)
        self.assertIn('virsh console rhcsa-lab-serverb', header)


class PoolIdentityTests(unittest.TestCase):
    """O porte nao muda a prova: mesmo pool, mesmas cotas, mesmo tamanho e mesma nota."""

    def setUp(self):
        self.pool = dyn.load_pool(POOL_PATH)

    def test_pool_has_166_tasks_24_legacy_142_ported(self):
        kinds = [t['kind'] for t in self.pool['tasks']]
        self.assertEqual(len(kinds), 166)
        self.assertEqual(kinds.count('legacy'), 24)
        self.assertEqual(kinds.count('ported'), 142)
        self.assertFalse([t['id'] for t in self.pool['tasks'] if t.get('extra')])

    def test_every_ported_task_has_its_script(self):
        scripts = {p.stem for p in (DYN_DIR / 'tasks').glob('dyn-*.sh')}
        ported = {t['id'] for t in self.pool['tasks'] if t['kind'] == 'ported'}
        self.assertEqual(scripts, ported)

    def test_quota_count_and_pass_mark_are_the_homelab_ones(self):
        quota = dyn.quotas({int(k): v for k, v in self.pool['domains'].items()})
        self.assertEqual([quota[d] for d in sorted(quota)], [3, 3, 3, 5, 2, 3, 3, 2])
        exam = dyn.draw(self.pool, seed=1)
        self.assertEqual(len(exam['questions']), 24)
        self.assertEqual(exam['pass_mark'], 17)

    def test_practice_disk_sizes_are_unchanged(self):
        self.assertEqual(dyn.DISK_SIZES, (2 * 1024**3, 3 * 1024**3))
        self.assertEqual(dyn.LEGACY_DISK_SIZES, {'@DISCO1@': 1024**3, '@DISCO6@': 6 * 1024**3})


if __name__ == '__main__':
    unittest.main()

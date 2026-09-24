"""Valida a forma de labs/catalog.json (gerado por scripts/build-catalog.py),
não o conteúdo de nenhum lab específico — os exercícios em labs/ são
extensíveis, este teste não deve travar quando alguém adicionar um novo."""
import json
import unittest
from pathlib import Path

CATALOG_PATH = Path(__file__).resolve().parents[5] / 'labs' / 'catalog.json'
VALID_HOSTS = {'workstation', 'servera', 'serverb'}
REQUIRED = ('id', 'number', 'title', 'domain', 'hosts', 'description', 'instructions')


class CatalogShapeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not CATALOG_PATH.exists():
            raise unittest.SkipTest(
                f'{CATALOG_PATH} não existe — rode `make catalog` primeiro.')
        cls.tasks = json.loads(CATALOG_PATH.read_text(encoding='utf-8'))

    def test_at_least_one_task(self):
        self.assertGreater(len(self.tasks), 0)

    def test_ids_are_unique(self):
        ids = [task['id'] for task in self.tasks]
        self.assertEqual(len(ids), len(set(ids)))

    def test_every_task_has_required_fields(self):
        for task in self.tasks:
            with self.subTest(task=task.get('id')):
                for key in REQUIRED:
                    self.assertIn(key, task)

    def test_hosts_are_known_machines(self):
        for task in self.tasks:
            with self.subTest(task=task['id']):
                self.assertTrue(task['hosts'])
                self.assertTrue(set(task['hosts']).issubset(VALID_HOSTS))

    def test_numbers_are_unique(self):
        numbers = [task['number'] for task in self.tasks]
        self.assertEqual(len(numbers), len(set(numbers)))

    def test_solve_fields_when_present_are_consistent(self):
        for task in self.tasks:
            with self.subTest(task=task['id']):
                if task.get('solve_method') == 'ssh':
                    self.assertRegex(task.get('solve_command', ''), r'^ssh (servera|serverb)$')


if __name__ == '__main__':
    unittest.main()

import paths  # noqa: F401  (põe backend/ai_review no sys.path)
import os
import json
import re
import subprocess
import sys
from pathlib import Path
import unittest

# Senha real de root do lab: so' vem do ambiente (RHCSA_LAB_ROOT_PASSWORD), nunca do codigo.
ROOT_PW = os.environ.get('RHCSA_LAB_ROOT_PASSWORD', '')


class CatalogExecutionTargetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tasks = json.loads(paths.CATALOG.read_text(encoding='utf-8'))

    def test_all_27_tasks_declare_how_and_where_to_solve(self):
        self.assertEqual(len(self.tasks), 27)
        for task in self.tasks:
            with self.subTest(task=task['id']):
                self.assertIn(task['solve_method'], ('ssh', 'console'))
                self.assertTrue(task['solve_target'])
                self.assertTrue(task['solve_note'])
                if task['solve_method'] == 'ssh':
                    self.assertRegex(task['solve_command'], r'^ssh (servera|serverb)$')
                else:
                    self.assertEqual(task['solve_command'], '')

    def test_video_items_2_to_15_are_solved_on_servera(self):
        for task in self.tasks:
            if 1 <= task['number'] <= 15 or task['number'] in (21, 23):
                self.assertIn('servera', task['solve_target'], task['id'])
                self.assertEqual(task['solve_command'], 'ssh servera', task['id'])

    def test_video_items_16_to_20_and_22_are_solved_on_serverb(self):
        for task in self.tasks:
            if task['number'] in (16, 17, 18, 19, 20, 22, 24, 25):
                self.assertIn('serverb', task['solve_target'], task['id'])

    def test_root_recovery_uses_console_and_autofs_explains_both_hosts(self):
        by_id = {task['id']: task for task in self.tasks}
        recovery = by_id['examsim-rootpw-recover-node2']
        self.assertEqual(recovery['solve_method'], 'console')
        self.assertIn('virsh console rhcsa-lab-serverb', recovery['solve_target'])
        autofs = by_id['examsim-autofs-remoteuser2']
        self.assertIn('servera', autofs['solve_target'])
        self.assertIn('workstation', autofs['solve_note'])
        self.assertIn('servidor NFS', autofs['solve_note'])

    def test_numbers_cover_the_two_exams_and_questions_1_to_25(self):
        # número 0 = provas orquestradas: examsim-full e examsim-dinamico
        self.assertEqual(sorted(t['number'] for t in self.tasks), [0, 0] + list(range(1, 26)))
        self.assertEqual(sorted(t['id'] for t in self.tasks if t['number'] == 0),
                         ['examsim-dinamico', 'examsim-full'])

    def test_dynamic_exam_is_finish_only_dynamic_and_has_no_secrets(self):
        dyn = {t['id']: t for t in self.tasks}['examsim-dinamico']
        self.assertIs(dyn['grade'], False)
        self.assertIs(dyn['dynamic'], True)
        self.assertEqual(dyn['exam_limit_minutes'], 180)
        self.assertEqual(dyn['solve_method'], 'console')
        self.assertEqual(dyn['solve_command'], '')
        blob = json.dumps(dyn, ensure_ascii=False).lower()
        for secret in [s for s in ('atenorth', ROOT_PW) if s]:
            self.assertNotIn(secret, blob)

    def test_full_exam_is_finish_only_with_3h_visual_limit_and_no_secrets(self):
        full = {t['id']: t for t in self.tasks}['examsim-full']
        self.assertEqual(full['number'], 0)
        self.assertIs(full['grade'], False)
        self.assertEqual(full['exam_limit_minutes'], 180)
        self.assertEqual(full['solve_method'], 'console')
        blob = json.dumps(self.tasks, ensure_ascii=False).lower()
        for secret in [s for s in ('atenorth', ROOT_PW) if s]:
            self.assertNotIn(secret, blob)


class NoHomelabLeftoversTests(unittest.TestCase):
    """Porte homelab -> iac: IPs/VMIDs/noVNC do homelab não podem sobrar no que o aluno vê."""
    PATTERN = re.compile(r'192\.168\.10\.|VM 1[0-9]{2}\b|noVNC|Proxmox|homelab|LXC 802')

    def test_catalog_index_and_full_exam_texts_are_translated(self):
        files = [paths.CATALOG, paths.FILES / 'index.html',
                 paths.LAB_FULL / 'examsim-full-enunciado.txt', paths.LAB_FULL / 'examsim-full.sh',
                 paths.WORKSTATION_FILES / 'rhcsa-lab-original',
                 paths.AI_REVIEW_DIR / 'ai_review.py', paths.REVIEWER]
        for path in files:
            with self.subTest(path=path.name):
                self.assertIsNone(self.PATTERN.search(path.read_text(encoding='utf-8')))

    def test_dispatcher_lists_only_examsim_labs(self):
        text = (paths.WORKSTATION_FILES / 'rhcsa-lab-original').read_text(encoding='utf-8')
        listed = re.search(r'TODOS_OS_LABS="(.*?)"', text, re.S)[1].split()
        self.assertEqual(sorted(listed), sorted(t['id'] for t in self.tasks_from_catalog()))
        for rh199 in ('edit-file', 'files-review', 'compreview-review1', 'nfsclient-review'):
            self.assertNotIn(rh199, text)

    def test_build_catalog_validates_the_catalog(self):
        proc = subprocess.run([sys.executable, str(paths.REPO / 'scripts' / 'build-catalog.py')],
                              capture_output=True, text=True, timeout=10)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn('27 entradas', proc.stdout)

    @staticmethod
    def tasks_from_catalog():
        return json.loads(paths.CATALOG.read_text(encoding='utf-8'))

if __name__ == '__main__':
    unittest.main()

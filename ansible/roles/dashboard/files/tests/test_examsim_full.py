"""Static and offline checks for the 24-question full exam (no SSH, no VMs)."""
import paths  # noqa: F401  (põe backend/ai_review no sys.path)
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

from backend import parse_grade

# Senha real de root do lab: so' vem do ambiente (RHCSA_LAB_ROOT_PASSWORD), nunca do codigo.
ROOT_PW = os.environ.get('RHCSA_LAB_ROOT_PASSWORD', '')

# No iac os arquivos do homelab (lab-scripts/) ficam espalhados: lab-full e o
# dispatcher no role workstation, scripts dos alvos em labs/hosts/<host>/ (A2).
FULL = paths.LAB_FULL / 'examsim-full.sh'
DISPATCHER = paths.WORKSTATION_FILES / 'rhcsa-lab-original'
RESIZE_GRADER = paths.HOSTS / 'serverb/usr/local/lib/lab-grade/examsim-lvm-resize-home.sh'
TUNED_SERVERA_START = paths.HOSTS / 'servera/usr/local/lib/lab-scripts/examsim-tuned-servera.sh'
SCRIPT_ROOTS = (paths.LAB_FULL, paths.WORKSTATION_FILES, paths.HOSTS)


def all_files():
    return sorted(p for root in SCRIPT_ROOTS for p in root.rglob('*')
                  if p.is_file() and '__pycache__' not in p.parts)


class FullExamScriptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.full = FULL.read_text(encoding='utf-8')

    def section(self, name):
        return re.search(name + r'=\((.*?)\n\)', self.full, re.S)[1]

    def test_every_lab_script_parses(self):
        scripts = [p for p in all_files() if p.suffix == '.sh' or p == DISPATCHER]
        self.assertIn(DISPATCHER, scripts)
        for path in scripts:
            with self.subTest(script=str(path)):
                proc = subprocess.run(['bash', '-n', str(path)], capture_output=True, text=True)
                self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_grade_is_refused_offline(self):
        proc = subprocess.run(['bash', str(FULL), 'grade'], capture_output=True, text=True, timeout=5)
        self.assertEqual(proc.returncode, 2)
        self.assertIn('lab finish examsim-full', proc.stdout)
        self.assertNotRegex(proc.stdout, r'(?m)^(OK|FALHOU|RESULTADO):')

    def test_finish_without_open_exam_refuses_before_touching_hosts(self):
        with tempfile.TemporaryDirectory() as home:
            env = dict(os.environ, HOME=home, PATH='/usr/bin:/bin')
            proc = subprocess.run(['bash', str(FULL), 'finish'], capture_output=True,
                                  text=True, env=env, timeout=5)
        self.assertEqual(proc.returncode, 2)
        self.assertIn('nenhuma prova aberta', proc.stderr)

    def test_questions_are_1_to_24_and_q22_uses_vg_home(self):
        numbers = sorted(int(n) for n in re.findall(r'^\s+\[(\d+)\]=', self.section('declare -A QUESTOES'), re.M))
        self.assertEqual(numbers, list(range(1, 25)))
        self.assertIn('EXAMSIM_HOME_VG=vg_home:examsim-lvm-resize-home', self.full)
        self.assertRegex(self.full, r'\[12\]=.*servera:examsim-autofs-remoteuser2 localhost:examsim-autofs-remoteuser2')

    def test_start_order_keeps_repo_before_timer_and_storage_last_on_serverb(self):
        starts = self.section('STARTS')
        self.assertLess(starts.index('examsim-repo-node1.sh'), starts.index('examsim-timer-acl.sh'))
        self.assertLess(starts.index('localhost:bash $LS/examsim-autofs'), starts.index('servera:bash $LS/examsim-autofs'))
        self.assertLess(starts.index('rootpw-start'), starts.index('storage-start'))
        self.assertLess(starts.index('storage-start'), starts.index('examsim-repo-node2.sh'))

    def test_finish_uses_storage_helper_instead_of_single_disk_finishes(self):
        finishes = self.section('FINISHES')
        self.assertIn('storage-finish', finishes)
        self.assertIn('rootpw-finish', finishes)
        for single in ('examsim-swap', 'examsim-lvm-mydatabase', 'examsim-lvm-resize-home', 'examsim-vgextend'):
            self.assertNotIn(single, finishes)
        self.assertLess(finishes.index('servera:bash $LF/examsim-autofs'), finishes.index('localhost:bash $LF/examsim-autofs'))

    def test_resize_home_grader_defaults_to_myvg(self):
        grader = RESIZE_GRADER.read_text(encoding='utf-8')
        self.assertIn('VG=${EXAMSIM_HOME_VG:-myvg}', grader)
        self.assertNotRegex(grader, r'(?<![$\w])myvg/home')

    def test_dispatcher_routes_full_exam_before_generic_handling(self):
        dispatcher = DISPATCHER.read_text(encoding='utf-8')
        route = dispatcher.index('exec bash /usr/local/lib/lab-full/examsim-full.sh')
        self.assertLess(route, dispatcher.index('AVISO=$(lab_aviso'))
        for lab in ('examsim-flatpak', 'examsim-script-args', 'examsim-tuned-servera', 'examsim-vgextend', 'examsim-full'):
            self.assertIn(lab, dispatcher)

    def test_tuned_start_removes_only_the_package_not_its_dependencies(self):
        start = TUNED_SERVERA_START.read_text(encoding='utf-8')
        self.assertIn('rpm -e tuned', start)
        self.assertNotRegex(start, r'(?m)^[^#]*dnf[^\n]*remove')

    def test_no_plaintext_credentials_in_scripts(self):
        for path in all_files():
            with self.subTest(script=str(path)):
                if ROOT_PW:
                    self.assertNotIn(ROOT_PW, path.read_text(encoding='utf-8'))


class FullExamParseTests(unittest.TestCase):
    OUTPUT = '\n'.join([
        '==> Correcao da prova iniciada em 27/09/2026 10:00:00',
        '==> Q01 — Flatpak: remote examrepo + codium',
        '    │ FALHOU: remote examrepo configurado',
        '    │ RESULTADO: FALHOU',
        'FALHOU: Q01 — Flatpak: remote examrepo + codium (remote examrepo configurado)',
        '==> Q02 — Rede e hostname',
        '    │ OK: hostname',
        '    │ RESULTADO: PASSOU',
        'OK: Q02 — Rede e hostname',
        '',
        'RESULTADO: FALHOU',
        'Nota 1/2 (50%) — referência 17/24 → REPROVADO',
        '==> limpeza servera: examsim-flatpak.sh',
        '    │ OK: item 1 limpo.',
    ])

    def test_only_question_lines_become_criteria(self):
        result = parse_grade(self.OUTPUT, 1, ['workstation'])
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['total_criteria'], 2)
        self.assertEqual(result['passed_criteria'], 1)
        self.assertTrue(result['failure_reasons'][0].startswith('Q01'))

    def test_all_questions_ok_passes(self):
        output = 'OK: Q01 — a\nOK: Q02 — b\n\nRESULTADO: PASSOU\nNota 2/2\n'
        self.assertEqual(parse_grade(output, 0, ['workstation'])['status'], 'passed')


if __name__ == '__main__':
    unittest.main()

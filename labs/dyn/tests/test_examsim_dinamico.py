"""Exame dinâmico: sorteio, passos, enunciado e integridade do pool (fixtures locais)."""
import os
import importlib.util
import json
import re
import subprocess
import unittest
from collections import Counter
from pathlib import Path

# Senha real de root do lab: so' vem do ambiente (RHCSA_LAB_ROOT_PASSWORD), nunca do codigo.
ROOT_PW = os.environ.get('RHCSA_LAB_ROOT_PASSWORD', '')

# Porte iac: o motor mora em labs/dyn/ (no homelab: lab-scripts/dyn/ + lab-scripts/examsim-dinamico.sh).
DYN_DIR = Path(__file__).resolve().parent.parent
REPO = DYN_DIR.parent.parent
ORCH = DYN_DIR / 'examsim-dinamico.sh'


def _companion(name):
    """Arquivo de outro role (examsim-full.sh, rhcsa-lab-original): procura no repo; None se ausente."""
    hits = sorted(p for p in REPO.glob(f'ansible/roles/*/files/**/{name}') if p.is_file())
    hits += sorted(p for p in REPO.glob(f'labs/**/{name}') if p.is_file() and DYN_DIR not in p.parents)
    return hits[0] if hits else None
POOL_PATH = DYN_DIR / 'pool.json'
SEEDS = range(1, 301)


def load_dyn():
    spec = importlib.util.spec_from_file_location('dyn', DYN_DIR / 'dyn.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


dyn = load_dyn()
POOL = dyn.load_pool(POOL_PATH)


class QuotaTests(unittest.TestCase):
    def domains(self):
        return {int(k): v for k, v in POOL['domains'].items()}

    def test_default_split_follows_ex200_v10_weights_with_minimum_two(self):
        quota = dyn.quotas(self.domains())
        self.assertEqual(quota, {1: 3, 2: 3, 3: 3, 4: 5, 5: 2, 6: 3, 7: 3, 8: 2})
        self.assertEqual(sum(quota.values()), 24)

    def test_every_domain_gets_the_minimum_for_any_feasible_count(self):
        for count in range(16, 41):
            quota = dyn.quotas(self.domains(), count)
            with self.subTest(count=count):
                self.assertEqual(sum(quota.values()), count)
                self.assertTrue(all(v >= 2 for v in quota.values()))

    def test_count_below_the_minimum_is_rejected(self):
        with self.assertRaises(ValueError):
            dyn.quotas(self.domains(), 15)


class DrawTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.exams = [dyn.draw(POOL, seed=seed) for seed in SEEDS]

    def test_always_24_unique_questions_with_at_least_two_per_domain(self):
        for exam in self.exams:
            with self.subTest(seed=exam['seed']):
                questions = exam['questions']
                self.assertEqual(len(questions), 24)
                self.assertEqual(len({q['id'] for q in questions}), 24)
                per_domain = Counter(q['domain'] for q in questions)
                self.assertEqual(set(per_domain), set(range(1, 9)))
                self.assertTrue(all(n >= 2 for n in per_domain.values()), per_domain)
                self.assertEqual([q['q'] for q in questions], list(range(1, 25)))

    def test_questions_per_domain_match_the_quota(self):
        for exam in self.exams[:50]:
            counted = Counter(str(q['domain']) for q in exam['questions'])
            for dom, info in exam['domains'].items():
                self.assertEqual(counted[dom], info['quota'])

    def test_every_pool_task_belongs_to_one_of_the_eight_domains_unless_flagged_extra(self):
        for task in POOL['tasks']:
            if not task.get('extra'):
                self.assertIn(str(task['domain']), POOL['domains'], task['id'])

    def test_tasks_flagged_extra_are_never_drawn(self):
        extra = dict(POOL['tasks'][0], id='extra-sintetica', extra=True)
        pool = dict(POOL, tasks=POOL['tasks'] + [extra])
        for seed in range(1, 120):
            exam = dyn.draw(pool, seed=seed)
            self.assertNotIn('extra-sintetica', {q['id'] for q in exam['questions']})

    def test_at_most_one_console_question(self):
        for exam in self.exams:
            self.assertLessEqual(sum(q['console'] for q in exam['questions']), 1)

    def test_no_two_questions_claim_the_same_resource_unless_they_share_a_group(self):
        by_id = {t['id']: t for t in POOL['tasks']}
        for exam in self.exams:
            claimed = {}
            for q in exam['questions']:
                task = by_id[q['id']]
                for res in {r.replace('{host}', q['host']) for r in task.get('conflicts', [])}:
                    owner = claimed.setdefault(res, task.get('group') or task['id'])
                    self.assertEqual(owner, task.get('group') or task['id'],
                                     f"seed {exam['seed']}: {res} disputado por {owner} e {q['id']}")

    def test_hosts_respect_what_each_task_allows(self):
        by_id = {t['id']: t for t in POOL['tasks']}
        for exam in self.exams:
            for q in exam['questions']:
                self.assertIn(q['host'], by_id[q['id']]['hosts'])

    def test_same_seed_gives_the_same_exam_and_other_seeds_differ(self):
        def stable(exam):
            return {k: v for k, v in exam.items() if k not in ('id', 'started_at')}
        self.assertEqual(stable(dyn.draw(POOL, seed=7)), stable(dyn.draw(POOL, seed=7)))
        distinct = {json.dumps([(q['id'], q['host'], q['params']) for q in e['questions']]) for e in self.exams}
        self.assertGreater(len(distinct), 100, 'seeds diferentes precisam gerar provas diferentes')

    def test_no_unresolved_placeholder_survives_in_a_statement(self):
        for exam in self.exams:
            for q in exam['questions']:
                self.assertNotRegex(q['statement'], r'\{[A-Za-z_]+\}', q['id'])

    def test_infeasible_pool_fails_loudly_instead_of_returning_a_short_exam(self):
        small = dict(POOL, tasks=[t for t in POOL['tasks'] if t['domain'] != 5])
        with self.assertRaises(dyn.DrawError):
            dyn.draw(small, seed=1)


class StepTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.exams = [dyn.draw(POOL, seed=seed) for seed in range(1, 120)]

    def test_finish_is_the_exact_reverse_of_start(self):
        for exam in self.exams:
            who = lambda steps: [(s[1], s[2]) for s in steps]
            self.assertEqual(who(dyn.steps(exam, 'finish')), who(dyn.steps(exam, 'start'))[::-1])

    def test_group_setup_runs_once_and_members_have_no_individual_start(self):
        for exam in self.exams:
            starts = dyn.steps(exam, 'start')
            labels = [s[1] for s in starts]
            for group in exam['groups']:
                self.assertEqual(labels.count(f'group:{group}'), 1)
            grouped = {q['id'] for q in exam['questions'] if q.get('group')}
            self.assertFalse(grouped & set(labels))

    def test_every_question_is_graded_on_its_host(self):
        for exam in self.exams:
            for q in exam['questions']:
                grades = dyn.steps(exam, 'grade', only_q=q['q'])
                self.assertGreaterEqual(len(grades), 1)
                self.assertEqual(grades[0][2], q['host'])

    def test_repo_task_starts_before_timer_acl_as_in_the_full_exam(self):
        # As duas raramente saem juntas (~0,2% das provas): procura uma que as tenha.
        seen = False
        for seed in range(1, 6000):
            exam = dyn.draw(POOL, seed=seed)
            ids = [s[1] for s in dyn.steps(exam, 'start')]
            if 'examsim-repo-node1' in ids and 'examsim-timer-acl' in ids:
                seen = True
                self.assertLess(ids.index('examsim-repo-node1'), ids.index('examsim-timer-acl'))
                break
        self.assertTrue(seen)

    def test_autofs_prepares_the_nfs_server_first_and_grades_both_hosts(self):
        for exam in self.exams:
            if not any(q['id'] == 'examsim-autofs-remoteuser2' for q in exam['questions']):
                continue
            starts = [(s[2]) for s in dyn.steps(exam, 'start') if s[1] == 'examsim-autofs-remoteuser2']
            self.assertEqual(starts, ['localhost', 'servera'])
            q = next(q for q in exam['questions'] if q['id'] == 'examsim-autofs-remoteuser2')
            self.assertEqual([s[2] for s in dyn.steps(exam, 'grade', only_q=q['q'])], ['servera', 'localhost'])
            return
        self.fail('autofs nunca foi sorteado')

    def test_ported_params_are_shell_quoted(self):
        self.assertEqual(dyn._env_words({'A': "it's a b", 'B': 'x'}), "A='it'\"'\"'s a b' B=x")

    def test_params_cannot_use_names_the_shell_controls(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            for reserved in ('UID', 'GROUPS', 'HOSTNAME', 'USER', 'PATH', 'RANDOM'):
                bad = {'version': 1, 'domains': {}, 'tasks': [{'id': 'x', 'params': {reserved: {'choice': ['1']}}}]}
                path = Path(tmp) / f'{reserved}.json'
                path.write_text(json.dumps(bad))
                with self.assertRaises(ValueError, msg=reserved):
                    dyn.load_pool(path)

    def test_nested_placeholders_are_rendered_through_param_values(self):
        self.assertEqual(dyn.render('On {host}: {WHAT}', {'WHAT': 'lock {ACCT}.', 'ACCT': 'u1', 'host': 'servera'}),
                         'On servera: lock u1.')

    def test_env_keys_must_be_shell_safe(self):
        bad = {'version': 1, 'domains': {}, 'tasks': [{'id': 'x', 'params': {'bad key': {'choice': ['1']}}}]}
        tmp = Path(__file__).parent / '_bad_pool.json'
        tmp.write_text(json.dumps(bad))
        self.addCleanup(tmp.unlink)
        with self.assertRaises(ValueError):
            dyn.load_pool(tmp)

    def test_hosts_lists_every_machine_the_exam_touches(self):
        for exam in self.exams:
            hosts = dyn.hosts(exam)
            for q in exam['questions']:
                self.assertIn(q['host'], hosts)


class DiskBudgetTests(unittest.TestCase):
    """Fase 2: cada host tem 2 discos novos (2 e 3 GiB); a prova nunca promete mais que isso."""

    @classmethod
    def setUpClass(cls):
        cls.exams = [dyn.draw(POOL, seed=seed) for seed in SEEDS]

    def test_never_more_disk_slots_per_host_than_the_host_has(self):
        for exam in self.exams:
            used = Counter()
            for q in exam['questions']:
                used[q['host']] += q.get('disk_slots', 0)
            for host, n in used.items():
                self.assertLessEqual(n, dyn.DISK_CAPACITY, f"seed {exam['seed']} {host}")

    def test_each_disk_is_given_to_one_question_per_host(self):
        for exam in self.exams:
            taken = set()
            for q in exam['questions']:
                for key in ('DSIZE', 'DSIZE2'):
                    if key in q['params']:
                        self.assertIn(int(q['params'][key]), dyn.DISK_SIZES)
                        self.assertNotIn((q['host'], q['params'][key]), taken, f"seed {exam['seed']}")
                        taken.add((q['host'], q['params'][key]))

    def test_vg_extend_gets_both_disks_of_its_host(self):
        found = False
        for exam in self.exams:
            for q in exam['questions']:
                if q['id'] == 'dyn-lvm-vg-extend':
                    found = True
                    self.assertEqual([q['params']['DSIZE'], q['params']['DSIZE2']], [str(s) for s in dyn.DISK_SIZES])
        self.assertTrue(found, 'dyn-lvm-vg-extend nunca foi sorteada')

    def test_disk_questions_always_have_a_disk_size_and_other_questions_do_not(self):
        by_id = {t['id']: t for t in POOL['tasks']}
        for exam in self.exams:
            for q in exam['questions']:
                self.assertEqual('DSIZE' in q['params'], bool(by_id[q['id']].get('disk_slots')), q['id'])

    def test_int_params_are_drawn_inside_their_range(self):
        for exam in self.exams:
            for q in exam['questions']:
                if q['id'] == 'dyn-fs-extend':
                    self.assertTrue(1000 <= int(q['params']['SUFFIX']) <= 9999)

    def test_nfs_server_prep_runs_on_the_workstation_before_the_client_and_is_undone_after(self):
        seen = False
        for exam in self.exams:
            for q in exam['questions']:
                if q['id'] != 'dyn-nfs-mount':
                    continue
                seen = True
                start = [(s[2], s[4].split('|')[1]) for s in dyn.steps(exam, 'start') if s[1] == q['id']]
                self.assertEqual(start, [('localhost', 'server-start'), (q['host'], 'start')])
                finish = [(s[2], s[4].split('|')[1]) for s in dyn.steps(exam, 'finish') if s[1] == q['id']]
                self.assertEqual(finish, [(q['host'], 'finish'), ('localhost', 'server-finish')])
                grade = dyn.steps(exam, 'grade', only_q=q['q'])
                self.assertEqual([s[2] for s in grade], [q['host']], 'a correcao roda so no cliente')
        self.assertTrue(seen)

    def test_autofs_tasks_exclude_each_other_and_the_legacy_autofs_on_the_same_host(self):
        for exam in self.exams:
            per_host = Counter(q['host'] for q in exam['questions']
                               if q['id'] in ('dyn-autofs-basic', 'dyn-autofs-home', 'examsim-autofs-remoteuser2'))
            self.assertTrue(all(n <= 1 for n in per_host.values()), f"seed {exam['seed']}: {per_host}")

    def test_parse_disks_reads_the_lsblk_table(self):
        parsed = dyn.parse_disks('servera\tsdb\t2147483648\nservera\tsda\t21474836480\nruido\nserverb\tsdd\t2147483648\n')
        self.assertEqual(parsed['servera'][2147483648], '/dev/sdb')
        self.assertEqual(parsed['serverb'][2147483648], '/dev/sdd')
        self.assertNotIn('ruido', parsed)


class OutputTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.exam = dyn.draw(POOL, seed=11)

    def test_statement_lists_every_question_with_host_and_domain(self):
        text = dyn.statement(self.exam)
        for q in self.exam['questions']:
            self.assertIn(f"Q{q['q']:02d} [{q['host']} · D{q['domain']} ", text)
        self.assertIn('lab finish examsim-dinamico', text)
        self.assertIn('17/24', text)

    def test_disk_placeholders_are_bound_to_real_devices_and_never_leak(self):
        disks = {h: {2 * 1024**3: '/dev/sdb', 3 * 1024**3: '/dev/sdc', 1024**3: '/dev/sdd', 6 * 1024**3: '/dev/sde'}
                 for h in ('servera', 'serverb')}
        seen = False
        for seed in SEEDS:
            exam = dyn.draw(POOL, seed=seed)
            if not any('@DISK' in q['statement'] or '@DISCO' in q['statement'] for q in exam['questions']):
                continue
            seen = True
            # sem bind: o terminal e o painel mostram um texto legivel, nunca o token cru
            self.assertNotRegex(dyn.statement(exam), r'@DISK|@DISCO')
            self.assertNotRegex(json.dumps(dyn.public(exam), ensure_ascii=False), r'@DISK|@DISCO')
            bound = dyn.bind(json.loads(json.dumps(exam)), disks)
            for original, q in zip(exam['questions'], bound['questions']):
                self.assertNotRegex(q['statement'], r'@DISK|@DISCO', q['id'])
                if '@DISK@' in original['statement'] and q['params'].get('DSIZE') == str(2 * 1024**3):
                    self.assertIn('/dev/sdb', q['statement'], q['id'])
            break
        self.assertTrue(seen, 'nenhuma prova sorteou questões de disco')

    def test_public_manifest_hides_params_internals_and_the_exercise_credential(self):
        for seed in SEEDS:
            exam = dyn.draw(POOL, seed=seed)
            blob = json.dumps(dyn.public(exam), ensure_ascii=False)
            self.assertNotIn('atenorth', blob)
            self.assertNotIn('"params"', blob)
            self.assertNotIn('"order"', blob)
            self.assertNotIn(ROOT_PW or '\0', blob)
        for seed in SEEDS:
            exam = dyn.draw(POOL, seed=seed)
            raw = [q for q in exam['questions'] if 'atenorth' in q['statement']]
            if raw:
                shown = {q['id']: q['statement'] for q in dyn.public(exam)['questions']}
                for q in raw:
                    self.assertNotIn('atenorth', shown[q['id']])
                    self.assertIn('credencial do exercício', shown[q['id']])
                return
        self.fail('nenhuma prova sorteou uma questão com a credencial de exercício')

    def test_results_score_by_domain_and_pass_mark(self):
        exam = self.exam
        ok_all = {str(q['q']): {'ok': True, 'pending': ''} for q in exam['questions']}
        closed = dyn.archive(exam, ok_all)
        self.assertEqual(closed['state'], 'closed')
        self.assertEqual(closed['score']['passed'], 24)
        self.assertTrue(closed['score']['approved'])
        self.assertEqual(sum(d['total'] for d in closed['by_domain'].values()), 24)
        self.assertIn('RESULTADO: PASSOU', dyn.summary(exam, ok_all))

        mark = exam['pass_mark']
        edge = {str(q['q']): {'ok': q['q'] <= mark, 'pending': 'x'} for q in exam['questions']}
        self.assertTrue(dyn.score(exam, edge)[0]['approved'])
        below = {str(q['q']): {'ok': q['q'] < mark, 'pending': 'x'} for q in exam['questions']}
        score, _ = dyn.score(exam, below)
        self.assertFalse(score['approved'])
        text = dyn.summary(exam, below)
        self.assertIn('RESULTADO: FALHOU', text)
        self.assertIn('REPROVADO', text)

    def test_summary_lines_never_look_like_grading_criteria(self):
        results = {str(q['q']): {'ok': False, 'pending': 'x'} for q in self.exam['questions']}
        for line in dyn.summary(self.exam, results).splitlines():
            self.assertNotRegex(line, r'^(OK|FALHOU):')

    def test_parse_results_ignores_noise(self):
        parsed = dyn.parse_results('3\tOK\t\n7\tFALHOU\tfaltou x\nlixo\nx\tOK\t\n')
        self.assertEqual(parsed, {'3': {'ok': True, 'pending': ''}, '7': {'ok': False, 'pending': 'faltou x'}})


class PoolIntegrityTests(unittest.TestCase):
    def test_pool_has_no_plaintext_account_password(self):
        self.assertNotIn(ROOT_PW or '\0', POOL_PATH.read_text(encoding='utf-8'))

    def test_every_domain_has_enough_tasks_for_its_quota(self):
        quota = dyn.quotas({int(k): v for k, v in POOL['domains'].items()})
        for dom, need in quota.items():
            have = [t for t in POOL['tasks'] if t['domain'] == dom and not t.get('extra')]
            self.assertGreaterEqual(len(have), need, f'domínio {dom}')

    def test_legacy_start_order_matches_the_full_exam_orchestrator(self):
        path = _companion('examsim-full.sh')
        if path is None:
            self.skipTest('examsim-full.sh (role do A4) ainda nao esta no repo')
        full = path.read_text(encoding='utf-8')
        block = re.search(r'STARTS=\(\n(.*?)\n\)', full, re.S).group(1)
        position = {}
        for index, line in enumerate((l for l in block.splitlines() if l.strip()), 1):
            found = re.search(r'examsim-[a-z0-9-]+(?=\.sh)', line)
            if found:  # as linhas rootpw/storage sao grupos: contam na posicao, sem script
                position.setdefault(found.group(0), index)
        for task in POOL['tasks']:
            if task['kind'] == 'legacy' and not task.get('group') and task['id'] in position:
                self.assertEqual(task['order'], position[task['id']], task['id'])

    def test_every_ported_task_has_a_script_with_the_full_contract(self):
        for task in POOL['tasks']:
            if task['kind'] != 'ported':
                continue
            path = DYN_DIR / 'tasks' / f"{task['id']}.sh"
            with self.subTest(task=task['id']):
                body = path.read_text(encoding='utf-8')
                for fn in ('do_start()', 'do_grade()', 'do_finish()'):
                    self.assertIn(fn, body)
                self.assertTrue(body.rstrip().endswith('run "$@"'))
                self.assertEqual(subprocess.run(['bash', '-n', str(path)]).returncode, 0)
                keys = set((task.get('params') or {}))
                for pset in task.get('param_sets') or []:
                    keys |= set(pset)
                placeholders = set(re.findall(r'\{([A-Z_]+)\}', task['statement']))
                self.assertLessEqual(placeholders, keys)

    def test_task_scripts_parse_and_the_orchestrator_is_valid_bash(self):
        for path in list((DYN_DIR / 'tasks').glob('*.sh')) + [ORCH,
                                                              DYN_DIR / 'qa' / 'validate-ported.sh']:
            self.assertEqual(subprocess.run(['bash', '-n', str(path)]).returncode, 0, path.name)

    def test_restores_that_recreate_files_with_tar_also_restore_selinux_labels(self):
        # tar/cp recriam arquivos com o rotulo do diretorio pai, nao o da politica: sem restorecon
        # o firewalld (confinado) nao consegue gravar em /etc/firewalld (aconteceu em 2026-10-05).
        lib = (DYN_DIR / 'tasks' / '_lib.sh').read_text(encoding='utf-8')
        for func, needle in (('fw_restore', 'restorecon -R /etc/firewalld'),
                             ('autofs_restore', 'restorecon -R /etc/auto.master'),
                             ('conf_restore', 'restorecon "$1"'),
                             ('yumrepo_restore', 'restorecon -R "$RD"')):
            body = re.search(r'\n' + func + r'\(\) \{(.*?)\n\}', lib, re.S).group(1)
            self.assertIn(needle, body, func)

    def test_qa_snapshots_include_the_selinux_label_count(self):
        for name in ('solutions-d4.sh', 'solutions-d3d8.sh', 'solutions-d7d6.sh', 'solutions-d1d5.sh'):
            self.assertIn('rotulos=$(restorecon -nR', (DYN_DIR / 'qa' / name).read_text(encoding='utf-8'), name)

    def test_network_tasks_only_touch_the_virtual_interface(self):
        # A ens18 e' a gerencia (SSH): nenhuma tarefa de rede pode mexer nela, nem dar gateway/rota
        # padrao a dyn0 (um default via dyn0 derrubaria o acesso as VMs).
        for path in sorted((DYN_DIR / 'tasks').glob('dyn-net-*.sh')) + [DYN_DIR / 'tasks' / '_lib.sh']:
            for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                if line.lstrip().startswith('#'):
                    continue
                self.assertNotRegex(line, r'\bens\d+\b', f'{path.name}:{number}')
                self.assertNotIn('ipv4.gateway', line, f'{path.name}:{number}')
        lib = (DYN_DIR / 'tasks' / '_lib.sh').read_text(encoding='utf-8')
        self.assertIn('ipv4.never-default yes', re.search(r'\nnet_mkprof\(\) \{(.*?)\n\}', lib, re.S).group(1))

    def test_phase5_tasks_claim_the_shared_resources(self):
        for task in POOL['tasks']:
            if task['kind'] != 'ported':
                continue
            with self.subTest(task=task['id']):
                if task['category'] == 'flatpak':
                    self.assertEqual(task['hosts'], ['servera'])   # so' o servera tem flatpak
                    self.assertIn('flatpak@servera', task['conflicts'])
                if task['id'] in ('dyn-pkg-install', 'dyn-pkg-remove') or task['category'] == 'repos':
                    self.assertIn('repo@{host}', task['conflicts'])
                if task['id'].startswith('dyn-net-') and task['id'] not in ('dyn-net-hosts', 'dyn-net-hostname', 'dyn-net-verify'):
                    self.assertIn('nic-dyn0@{host}', task['conflicts'])

    def test_ported_tasks_never_reboot_or_power_off_the_vm(self):
        # Reiniciar no meio da prova derrubaria o SSH da correcao e as outras questoes; a
        # configuracao de boot e' conferida pelo estado (grubby, grub.cfg, fstab), nunca pelo reboot.
        risky = re.compile(r'(^|[;&|(\s])(reboot|poweroff|halt|shutdown)\b|\binit [0-6]\b|systemctl\s+(isolate|reboot|poweroff)')
        for path in sorted((DYN_DIR / 'tasks').glob('*.sh')):
            for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                if line.lstrip().startswith('#'):
                    continue
                self.assertIsNone(risky.search(line), f'{path.name}:{number}: {line.strip()}')

    def test_tasks_that_edit_the_boot_loader_save_and_restore_it(self):
        for path in sorted((DYN_DIR / 'tasks').glob('dyn-*.sh')):
            body = path.read_text(encoding='utf-8')
            if any(w in body for w in ('--update-kernel', 'grub2-mkconfig', 'grub_regen', 'GRUB_TIMEOUT=')):
                with self.subTest(task=path.name):
                    self.assertIn('boot_save "$ID"', body)
                    self.assertIn('boot_restore "$ID"', body)

    def test_chroot_task_never_deletes_recursively(self):
        # O diretorio do chroot tem /dev, /proc e /sys montados: um rm -r nele apagaria o host.
        body = (DYN_DIR / 'tasks' / 'dyn-chroot-practice.sh').read_text(encoding='utf-8')
        self.assertNotRegex(body, r'rm\s+-\w*[rR]')
        self.assertIn('rmdir', body)
        self.assertLess(body.index('unmount_all\n    if findmnt'), body.index('rmdir "$CHROOT/$m"'))

    def test_orchestrator_refuses_grade_and_never_embeds_credentials(self):
        text = ORCH.read_text(encoding='utf-8')
        self.assertIn('grade)', text)
        self.assertIn('exit 2', text)
        self.assertNotIn(ROOT_PW or '\0', text)
        self.assertNotRegex(text, r'(?m)^[^#]*dnf[^\n]*remove')

    def test_orchestrator_masks_the_exercise_credential_in_the_correction_text(self):
        text = ORCH.read_text(encoding='utf-8')
        body = re.search(r'limpa_texto\(\) \{(.*?)\n\}', text, re.S).group(1)
        self.assertIn('atenorth', body)
        self.assertIn('credencial do exercicio', body)

    def test_lib_restores_missing_config_files_and_dropin_directories(self):
        lib = (DYN_DIR / 'tasks' / '_lib.sh').read_text(encoding='utf-8')
        for needle in ('.absent', '.nodir', 'rmdir "$JD"', 'reset-failed'):
            self.assertIn(needle, lib)

    def test_no_task_script_can_kill_every_process_of_the_root_filesystem(self):
        # "fuser -m <dir> -k" num diretorio que nao e ponto de montagem mira o "/" inteiro
        # (derrubou sshd, firewalld, NetworkManager... nas duas VMs em 2026-10-04).
        risky = re.compile(r'\bfuser\s+(-\w*m\w*k|-\w*k\w*m)\b|\bfuser\b[^\n]*--mount[^\n]*-k')
        for path in list((DYN_DIR / 'tasks').glob('*.sh')) + [ORCH]:
            for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                if line.lstrip().startswith('#'):
                    continue
                self.assertIsNone(risky.search(line), f'{path.name}:{number}: {line.strip()}')

    def test_destructive_removals_in_tasks_are_anchored_to_known_paths(self):
        # rm -rf de variavel so' com ${VAR:?} ou com um "case" ancorado em prefixo na mesma linha
        bare = re.compile(r'rm -rf\s+"?\$\w+"?')
        guarded = re.compile(r'\$\{\w+:\?\}|case\s+"\$\w+"\s+in\s+/[\w./-]+\?[*?]\)')
        for path in (DYN_DIR / 'tasks').glob('*.sh'):
            for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                if line.lstrip().startswith('#') or not bare.search(line):
                    continue
                self.assertRegex(line, guarded, f'{path.name}:{number}: rm -rf de variavel sem protecao: {line.strip()}')

    def test_disk_slots_match_the_statement_and_the_script(self):
        for task in POOL['tasks']:
            if task['kind'] != 'ported':
                continue
            body = (DYN_DIR / 'tasks' / f"{task['id']}.sh").read_text(encoding='utf-8')
            slots = task.get('disk_slots', 0)
            with self.subTest(task=task['id']):
                if '@DISK@' in task['statement'] or '@DISK2@' in task['statement']:
                    self.assertGreaterEqual(slots, 1, 'o enunciado cita um disco que a tarefa nao reservou')
                if slots:
                    # o VG de cenario ja existe em alguns enunciados: o script usa o disco mesmo assim
                    self.assertIn('need_disk "$DSIZE"', body)
                if slots > 1:
                    self.assertIn('@DISK2@', task['statement'])
                    self.assertIn('need_disk "$DSIZE2"', body)
                if not slots:
                    self.assertNotIn('need_disk', body)
                    self.assertNotIn('DSIZE', body)
                    self.assertNotIn('@DISK', task['statement'])

    def test_tasks_with_a_server_side_define_both_server_phases(self):
        for task in POOL['tasks']:
            body = (DYN_DIR / 'tasks' / f"{task['id']}.sh").read_text(encoding='utf-8') if task['kind'] == 'ported' else ''
            if task.get('server_hosts'):
                self.assertEqual(task['server_hosts'], ['localhost'])
                self.assertIn('do_server_start()', body, task['id'])
                self.assertIn('do_server_finish()', body, task['id'])
            elif task['kind'] == 'ported':
                self.assertNotIn('do_server_start()', body, task['id'])

    def test_orchestrator_binds_real_disk_names_before_publishing(self):
        text = ORCH.read_text(encoding='utf-8')
        self.assertIn('bind_discos()', text)
        self.assertLess(text.index('\n    bind_discos\n'), text.index('publica "$($PY public "$MAN")"'))

    def test_dispatcher_routes_the_dynamic_exam_to_the_orchestrator(self):
        path = _companion('rhcsa-lab-original')
        if path is None:
            self.skipTest('rhcsa-lab-original (role do A4) ainda nao esta no repo')
        text = path.read_text(encoding='utf-8')
        self.assertIn('examsim-full|examsim-dinamico)', text)
        self.assertIn('exec bash /usr/local/lib/lab-dyn/examsim-dinamico.sh "$SUBCOMMAND"', text)


if __name__ == '__main__':
    unittest.main()

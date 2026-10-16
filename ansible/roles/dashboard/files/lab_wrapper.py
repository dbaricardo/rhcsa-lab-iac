#!/usr/bin/python3 -I
"""Transparent lab dispatcher wrapper with local progress recording."""
import os
import pwd
import signal
import subprocess
import sys
import time

if __name__ == '__main__':
    # Isolated mode omits the script directory; add only the fixed application path.
    sys.path.insert(0, '/opt/rhcsa-lab-dashboard')

from backend import ProgressStore, load_catalog

ACTIONS = frozenset(('start', 'grade', 'finish'))


def _record(data_dir, catalog, task_id, action, output, returncode, started_ns,
            student_user):
    """Record as the unprivileged student when the wrapper was invoked by root."""
    def write():
        ProgressStore(data_dir, catalog).record(
            task_id, action, output, returncode, started_ns=started_ns)

    if os.geteuid() != 0:
        write()
        return

    account = pwd.getpwnam(student_user)
    pid = os.fork()
    if pid == 0:
        try:
            os.initgroups(account.pw_name, account.pw_gid)
            os.setgid(account.pw_gid)
            os.setuid(account.pw_uid)
            write()
        except BaseException:
            os._exit(1)
        os._exit(0)
    _, status = os.waitpid(pid, 0)
    if not os.WIFEXITED(status) or os.WEXITSTATUS(status) != 0:
        raise OSError('unprivileged progress writer failed')


def _spawn_review(task_id, finish_ns, review_script, student_user):
    """Start the AI review detached; the lab result never waits on it."""
    account = pwd.getpwnam(student_user)
    as_root = os.geteuid() == 0
    home = account.pw_dir if as_root else os.path.expanduser('~')
    log_dir = os.path.join(home, 'examsim-feedback')
    log_path = os.path.join(log_dir, '.review.log')
    os.makedirs(log_dir, mode=0o700, exist_ok=True)
    with open(log_path, 'ab') as log:
        # A transcrição e a revisão ficam só para o aluno, mesmo se o diretório já existia.
        os.chmod(log_dir, 0o700)
        os.chmod(log_path, 0o600)
        if as_root:
            # sudo lab finish must not leave root-owned files in the student's home.
            for path in (log_dir, log_path):
                os.chown(path, account.pw_uid, account.pw_gid)
        subprocess.Popen([sys.executable, '-I', review_script, task_id, str(finish_ns)],
                         stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                         start_new_session=True, close_fds=True,
                         env={'HOME': home, 'PATH': '/usr/bin:/bin', 'LANG': 'C.UTF-8'},
                         **({'user': account.pw_uid, 'group': account.pw_gid,
                             'extra_groups': []} if as_root else {}))


def run_wrapper(args, *, original, catalog_path, data_dir, student_user='student',
                review_script=None):
    """Run the dispatcher transparently and record exact known examsim commands."""
    catalog = load_catalog(catalog_path)
    known = {task['id']: task for task in catalog}
    tracked = (len(args) == 2 and args[0] in ACTIONS and
               args[1] in known and args[1].startswith('examsim-'))
    # The full exam refuses 'grade' (scoring happens only on finish); recording
    # that refusal would flip the dashboard to 'error' mid-exam.
    if tracked and args[0] == 'grade' and known[args[1]].get('grade') is False:
        tracked = False

    # Preserve separate stdout/stderr and avoid creating dashboard state for all
    # existing RH199 commands, malformed calls, help, and list.
    if not tracked:
        return subprocess.call([original, *args])

    started_ns = time.time_ns()
    proc = subprocess.Popen([original, *args], stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, bufsize=0)
    output = bytearray()
    assert proc.stdout is not None
    with proc.stdout:
        while chunk := proc.stdout.read(8192):
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()
            output.extend(chunk)
    returncode = proc.wait()

    try:
        _record(data_dir, catalog, args[1], args[0],
                output.decode('utf-8', 'replace'), returncode, started_ns,
                student_user)
    except BaseException as exc:
        # Dashboard recording is observational: it must never change the lab result.
        print(f'AVISO: dashboard não registrou este evento ({type(exc).__name__}).',
              file=sys.stderr, flush=True)
        return returncode

    # Revisão por IA é opcional: só existe quando o role ai_review instalou o script.
    if (args[0] == 'finish' and review_script and os.path.isfile(review_script)
            and os.environ.get('RHCSA_AI_REVIEW') != '0'):
        try:
            _spawn_review(args[1], started_ns, review_script, student_user)
            print('Revisão por IA iniciada em segundo plano: aparece no painel e em '
                  '~/examsim-feedback/ em 1-3 min.', flush=True)
        except BaseException as exc:
            print(f'AVISO: revisão por IA não iniciou ({type(exc).__name__}).',
                  file=sys.stderr, flush=True)
    return returncode


def exit_with_returncode(returncode):
    """Preserve ordinary exit codes and child signal termination semantics."""
    if returncode < 0:
        signum = -returncode
        signal.signal(signum, signal.SIG_DFL)
        os.kill(os.getpid(), signum)
    raise SystemExit(returncode)


def main(args):
    return run_wrapper(
        args,
        original='/usr/local/libexec/rhcsa-lab-original',
        catalog_path='/opt/rhcsa-lab-dashboard/catalog.json',
        data_dir='/var/lib/rhcsa-lab-dashboard',
        student_user='student',
        review_script='/opt/rhcsa-lab-dashboard/ai_review.py',
    )


if __name__ == '__main__':
    exit_with_returncode(main(sys.argv[1:]))

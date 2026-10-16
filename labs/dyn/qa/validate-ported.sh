#!/bin/bash
# QA das tarefas portadas do exame dinamico, contra as VMs reais.
# Roda na workstation como student (usa o mesmo transporte do orquestrador).
# Ciclo por tarefa/host/variante:
#   retrato antes -> start -> grade (deve FALHAR) -> solucao -> grade (deve PASSAR)
#   -> finish -> retrato depois (deve ser IGUAL ao de antes).
# Uso: validate-ported.sh [id-da-tarefa ...]   (sem argumentos: todas)
DYN=${DYN:-/usr/local/lib/lab-dyn}
# shellcheck disable=SC1091
source "$DYN/examsim-dinamico.sh"
set -u

declare -A SOL RET
SOL[dyn-boot-default-target]='systemctl set-default $TARGET'
RET[dyn-boot-default-target]='systemctl get-default'
SOL[dyn-journal-persistent]="sed -i 's/^Storage=.*/Storage=persistent/' /etc/systemd/journald.conf; systemctl reset-failed systemd-journald; systemctl restart systemd-journald"
RET[dyn-journal-persistent]='md5sum < /etc/systemd/journald.conf 2>&1; ls -A /etc/systemd/journald.conf.d 2>&1; test -d /var/log/journal && echo dir || echo nodir'
# RHEL 10 nao traz /etc/systemd/journald.conf: o aluno cria o arquivo ou um drop-in.
# A 1a variante (RUNMAX=50M) usa o arquivo, as demais usam drop-in (testa dropins_restore).
SOL[dyn-journal-size]='if [ "$RUNMAX" = 50M ]; then printf "[Journal]\nSystemMaxUse=%s\nRuntimeMaxUse=%s\n" $MAXUSE $RUNMAX > /etc/systemd/journald.conf; else mkdir -p /etc/systemd/journald.conf.d; printf "[Journal]\nSystemMaxUse=%s\nRuntimeMaxUse=%s\n" $MAXUSE $RUNMAX > /etc/systemd/journald.conf.d/size.conf; fi; systemctl reset-failed systemd-journald; systemctl restart systemd-journald'
RET[dyn-journal-size]='ls /etc/systemd/journald.conf 2>&1; md5sum < /etc/systemd/journald.conf 2>&1; ls -A /etc/systemd/journald.conf.d 2>&1'
SOL[dyn-net-hosts]='echo "$IP $FQDN $SHORT" >> /etc/hosts'
RET[dyn-net-hosts]='md5sum < /etc/hosts'
SOL[dyn-net-hostname]='hostnamectl set-hostname $NEWNAME'
RET[dyn-net-hostname]='hostnamectl --static; cat /etc/hostname'
SOL[dyn-selinux-bool]='setsebool -P $BOOL $VALUE'
RET[dyn-selinux-bool]='getsebool $BOOL; semanage boolean -l | grep "^$BOOL "'
SOL[dyn-selinux-port]='semanage port -a -t $TYPE -p $PROTO $PORT 2>/dev/null || semanage port -m -t $TYPE -p $PROTO $PORT'
RET[dyn-selinux-port]='semanage port -l -C'
SOL[dyn-fw-service]='firewall-cmd --permanent --zone=$ZONE --add-service=$SERVICE; firewall-cmd --reload'
RET[dyn-fw-service]='firewall-cmd --permanent --zone=$ZONE --list-services; firewall-cmd --zone=$ZONE --list-services'
SOL[dyn-fw-port]='firewall-cmd --permanent --zone=$ZONE --add-port=$PORT/$PROTO; firewall-cmd --reload'
RET[dyn-fw-port]='firewall-cmd --permanent --zone=$ZONE --list-ports; firewall-cmd --zone=$ZONE --list-ports'

# Dominio 4: solucoes/retratos (disco de 2 GiB = $D, 3 GiB = $D2, particao 1 = $P1)
[ -f "$DYN/qa/solutions-d4.sh" ] && source "$DYN/qa/solutions-d4.sh"
[ -f "$DYN/qa/solutions-d3d8.sh" ] && source "$DYN/qa/solutions-d3d8.sh"
[ -f "$DYN/qa/solutions-d7d6.sh" ] && source "$DYN/qa/solutions-d7d6.sh"
[ -f "$DYN/qa/solutions-d1d5.sh" ] && source "$DYN/qa/solutions-d1d5.sh"
[ -f "$DYN/qa/solutions-d2.sh" ] && source "$DYN/qa/solutions-d2.sh"
PRE='D=$(lsblk -bdnro NAME,SIZE | awk -v s="${DSIZE:-0}" "\$2==s{print \"/dev/\"\$1; exit}"); D2=$(lsblk -bdnro NAME,SIZE | awk -v s="${DSIZE2:-0}" "\$2==s{print \"/dev/\"\$1; exit}"); P1=${D}1; '

# id <TAB> host <TAB> "K=V ..." <TAB> servidor(0/1)  (todas as variantes na servera, a 1a na serverb)
casos() {
    python3 - "$DYN/pool.json" "$DYN" "$@" <<'PY'
import sys, json
sys.path.insert(0, sys.argv[2])
import dyn
pool = json.load(open(sys.argv[1])); only = set(sys.argv[3:])
for t in pool['tasks']:
    if t['kind'] != 'ported' or (only and t['id'] not in only):
        continue
    sets = t.get('param_sets') or [{}]
    ch = {k: v['choice'] for k, v in (t.get('params') or {}).items() if 'choice' in v}
    n = max([len(sets)] + [min(len(c), 2) for c in ch.values()]
            + [2 for _ in (t.get('params') or {}).values() if 'int' in _])
    variants = []
    ints = {k: v['int'] for k, v in (t.get('params') or {}).items() if 'int' in v}
    for i in range(n):
        v = dict(sets[i % len(sets)])
        for k, c in ch.items():
            v[k] = c[0] if i == 0 else c[-1]
        for k, (lo, hi) in ints.items():
            v[k] = str(lo if i == 0 else hi)
        if t.get('disk_slots'):
            v['DSIZE'] = str(dyn.DISK_SIZES[0])
            if t['disk_slots'] > 1:
                v['DSIZE2'] = str(dyn.DISK_SIZES[1])
        variants.append(v)
    for host in t['hosts']:
        for i, v in enumerate(variants if host == 'servera' else variants[:1]):
            print(f"{t['id']}\t{host}\t{dyn._env_words(v) or '_QA=1'}\t{1 if t.get('server_hosts') else 0}")
PY
}

host_cmd() {  # host "K=V ..." "comando" [estrito]  (executa o trecho com as variaveis da tarefa)
    local host=$1 envw=$2 snippet=$3
    # Solucoes rodam com set -e: um passo que falha nao pode ser mascarado pelo ultimo comando.
    [ "${4:-}" = estrito ] && snippet="set -e; $snippet"
    case "$envw" in *DSIZE*) snippet="$PRE$snippet" ;; esac
    ssh $SSH_OPTS "root@$host" "env $envw bash -c $(printf '%q' "$snippet")" 2>&1 </dev/null
}

passo() {  # passo <host> <id> <fase> "K=V" -> rc do passo (saida em $SAIDA, sem eco)
    local host=$1 id=$2 fase=$3 envw=$4 body
    body=$(cat "$DYN/tasks/_lib.sh" "$DYN/tasks/$id.sh" | base64 -w0)
    SAIDA=$(ssh $SSH_OPTS "root@$host" "env $envw bash -c \"\$(printf %s $body | base64 -d)\" _ $fase" 2>&1 </dev/null)
}

# Carregado com "source" (solve-exam.sh) so' define SOL/RET/PRE/host_cmd; executado, roda o QA.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0

ok=0; bad=0
resultado() { if [ "$1" -eq 0 ]; then ok=$((ok + 1)); printf '  PASS  %s\n' "$2"; else bad=$((bad + 1)); printf '  FAIL  %s\n' "$2"; [ -n "${3:-}" ] && printf '%s\n' "$3" | sed 's/^/        | /' | head -${QA_LINES:-12}; fi; }

while IFS=$'\t' read -r id host envw srv; do
    echo "== $id @ $host  [$envw]"
    antes=$(host_cmd "$host" "$envw" "${RET[$id]}")
    if [ "$srv" = 1 ]; then
        antes_srv=$(host_cmd localhost "$envw" "$RETSRV")
        passo localhost "$id" server-start "$envw"; resultado $? "server-start (workstation)" "$SAIDA"
    fi
    passo "$host" "$id" start "$envw"; resultado $? "start" "$SAIDA"
    passo "$host" "$id" grade "$envw"; rc=$?
    [ "$rc" -ne 0 ]; resultado $? "grade ANTES da solucao falha (precondicao real)" "$SAIDA"
    sol=$(host_cmd "$host" "$envw" "${SOL[$id]}" estrito); solrc=$?
    resultado $solrc "solucao aplicada" "$sol"
    passo "$host" "$id" grade "$envw"; rc=$?
    resultado $rc "grade DEPOIS da solucao passa" "$SAIDA"
    passo "$host" "$id" finish "$envw"; resultado $? "finish" "$SAIDA"
    if [ "$srv" = 1 ]; then
        passo localhost "$id" server-finish "$envw"; resultado $? "server-finish (workstation)" "$SAIDA"
        depois_srv=$(host_cmd localhost "$envw" "$RETSRV")
        [ "$antes_srv" = "$depois_srv" ]; resultado $? "retrato da workstation igual ao de antes" "ANTES:  $antes_srv
DEPOIS: $depois_srv"
    fi
    depois=$(host_cmd "$host" "$envw" "${RET[$id]}")
    [ "$antes" = "$depois" ]; resultado $? "retrato apos finish igual ao de antes" "ANTES:  $antes
DEPOIS: $depois"
done < <(casos "$@")
echo
echo "RESUMO: $ok passaram, $bad falharam"
[ "$bad" -eq 0 ]

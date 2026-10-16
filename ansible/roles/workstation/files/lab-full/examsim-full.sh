#!/bin/bash
# examsim-full — prova completa de 24 questoes (simulado kBsMuA-DA9E + 4 extras).
#
# Roda na workstation como student, chamado pelo dispatcher
# (lab start|grade|finish examsim-full). Reusa os scripts avulsos ja
# validados em cada host, chamando-os DIRETO com bash (o "lab finish" dos
# hosts roda o grade antes de limpar, e aqui a correcao e' centralizada).
#
# Saida do finish, lida pelo dashboard (backend.parse_grade):
#   - uma linha "OK: Qnn — titulo" ou "FALHOU: Qnn — titulo (pendencias)" por questao;
#   - uma unica linha "RESULTADO: PASSOU|FALHOU" (PASSOU so' com 24/24).
# Tudo que vem dos scripts subordinados sai indentado com "    │ " para nao
# ser confundido com criterio.
#
# Uso: examsim-full.sh start|grade|finish
set -u

SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
LS=/usr/local/lib/lab-scripts
LG=/usr/local/lib/lab-grade
LF=/usr/local/lib/lab-finish
FULL=/usr/local/lib/lab-full
SB="bash $FULL/examsim-full-serverb.sh"
DIR=$HOME/examsim-full
MARCA=$DIR/.aberta
APROVACAO=17

# host:comando na ordem de execucao. "localhost" e' a propria workstation
# (servidor NFS da questao 12), alcancada como root pela chave de student.
# Ordem do servera: quem faz dnf install antes do repo-node1 remover os repos;
# timer-acl depois do repo-node1 (o repo-node1 apaga qualquer .repo com
# content.example.com); grupos por ultimo entre os de usuarios para
# natasha/harry/sarah/sysadmin comecarem inexistentes; network por ultimo.
STARTS=(
    "servera:bash $LS/examsim-selinux-httpd.sh"
    "servera:bash $LS/examsim-find-strato.sh"
    "localhost:bash $LS/examsim-autofs-remoteuser2.sh"
    "servera:bash $LS/examsim-autofs-remoteuser2.sh"
    "servera:bash $LS/examsim-repo-node1.sh"
    "servera:bash $LS/examsim-timer-acl.sh"
    "servera:bash $LS/examsim-cron.sh"
    "servera:bash $LS/examsim-dir-colaborativo.sh"
    "servera:bash $LS/examsim-grupos.sh"
    "servera:bash $LS/examsim-backup.sh"
    "servera:bash $LS/examsim-ntp.sh"
    "servera:bash $LS/examsim-find-simone.sh"
    "servera:bash $LS/examsim-user-barry.sh"
    "servera:bash $LS/examsim-script-suid-umask.sh"
    "servera:bash $LS/examsim-script-args.sh"
    "servera:bash $LS/examsim-flatpak.sh"
    "servera:bash $LS/examsim-tuned-servera.sh"
    "servera:bash $LS/examsim-network.sh"
    "serverb:bash $LS/examsim-tuned.sh"
    "serverb:$SB rootpw-start"
    "serverb:$SB storage-start"
    "serverb:bash $LS/examsim-repo-node2.sh"
)

# Ordem inversa do start; o storage do serverb e' desfeito de uma vez pelo
# helper (os finishes avulsos 19/20/22 zerariam o disco de 1 GiB errado).
FINISHES=(
    "serverb:bash $LF/examsim-repo-node2.sh"
    "serverb:$SB storage-finish"
    "serverb:$SB rootpw-finish"
    "serverb:bash $LF/examsim-tuned.sh"
    "servera:bash $LF/examsim-network.sh"
    "servera:bash $LF/examsim-tuned-servera.sh"
    "servera:bash $LF/examsim-flatpak.sh"
    "servera:bash $LF/examsim-script-args.sh"
    "servera:bash $LF/examsim-script-suid-umask.sh"
    "servera:bash $LF/examsim-user-barry.sh"
    "servera:bash $LF/examsim-find-simone.sh"
    "servera:bash $LF/examsim-ntp.sh"
    "servera:bash $LF/examsim-backup.sh"
    "servera:bash $LF/examsim-grupos.sh"
    "servera:bash $LF/examsim-dir-colaborativo.sh"
    "servera:bash $LF/examsim-cron.sh"
    "servera:bash $LF/examsim-timer-acl.sh"
    "servera:bash $LF/examsim-repo-node1.sh"
    "servera:bash $LF/examsim-autofs-remoteuser2.sh"
    "localhost:bash $LF/examsim-autofs-remoteuser2.sh"
    "servera:bash $LF/examsim-find-strato.sh"
    "servera:bash $LF/examsim-selinux-httpd.sh"
)

# Questao -> "titulo|host:grader[ host:grader...]"; grader = nome em lab-grade,
# opcionalmente precedido de VAR=valor. Q12 so' passa com cliente E servidor NFS.
declare -A QUESTOES=(
    [1]="Flatpak: remote examrepo + codium|servera:examsim-flatpak"
    [2]="Rede e hostname|servera:examsim-network"
    [3]="Repositórios BaseOS/AppStream (servera)|servera:examsim-repo-node1"
    [4]="SELinux: httpd na porta 82|servera:examsim-selinux-httpd"
    [5]="Grupo sysadmin e usuários|servera:examsim-grupos"
    [6]="Diretório colaborativo /common/admin|servera:examsim-dir-colaborativo"
    [7]="Cron de natasha e harry|servera:examsim-cron"
    [8]="Backup tar.bz2 de /etc|servera:examsim-backup"
    [9]="NTP com chrony|servera:examsim-ntp"
    [10]="Arquivos de Simone em /root/found|servera:examsim-find-simone"
    [11]="strato em /searchfile|servera:examsim-find-strato"
    [12]="autofs do home de remoteuser2|servera:examsim-autofs-remoteuser2 localhost:examsim-autofs-remoteuser2"
    [13]="Usuário barry UID 2112|servera:examsim-user-barry"
    [14]="Script newsearch e umask de alex|servera:examsim-script-suid-umask"
    [15]="Timer systemd e ACL|servera:examsim-timer-acl"
    [16]="Recuperar acesso root (serverb)|serverb:examsim-rootpw-recover-node2"
    [17]="Repositórios BaseOS/AppStream (serverb)|serverb:examsim-repo-node2"
    [18]="tuned recomendado (serverb)|serverb:examsim-tuned"
    [19]="Swap persistente|serverb:examsim-swap"
    [20]="LVM myvg/mydatabase em /database|serverb:examsim-lvm-mydatabase"
    [21]="Shell script userinfo|servera:examsim-script-args"
    [22]="Resize de vg_home/home|serverb:EXAMSIM_HOME_VG=vg_home:examsim-lvm-resize-home"
    [23]="tuned throughput-performance (servera)|servera:examsim-tuned-servera"
    [24]="vgextend de vg_data/lv_data|serverb:examsim-vgextend"
)

# roda <host> <comando>: executa como root no host, mostra a saida indentada
# e deixa-a em $SAIDA.
roda() {
    local host=$1 rc
    shift
    SAIDA=$(ssh $SSH_OPTS "root@$host" "$*" 2>&1 </dev/null)
    rc=$?
    [ -n "$SAIDA" ] && printf '%s\n' "$SAIDA" | sed 's/^/    │ /'
    return $rc
}

checa_hosts() {
    local h
    for h in servera serverb localhost; do
        if ! ssh $SSH_OPTS "root@$h" true 2>/dev/null; then
            echo "ERRO: nao consegui alcancar root@$h por SSH. Nada foi alterado." >&2
            return 1
        fi
    done
}

start() {
    if [ -e "$MARCA" ]; then
        echo "ERRO: ja existe uma prova aberta (desde $(cat "$MARCA"))." >&2
        echo "      Rode 'lab finish examsim-full' para corrigir e limpar antes de comecar outra." >&2
        return 1
    fi
    if [ -e "$HOME/examsim-dinamico/.aberta" ]; then
        echo "ERRO: o exame dinamico esta aberto. Encerre com 'lab finish examsim-dinamico' antes." >&2
        return 1
    fi
    checa_hosts || return 2
    mkdir -p "$DIR"
    # Marca antes de mexer em qualquer coisa: se um start falhar no meio,
    # o finish ainda consegue limpar o que ja foi preparado.
    date '+%d/%m/%Y %H:%M:%S' > "$MARCA"
    local item host cmd n=0 d1="" d6=""
    for item in "${STARTS[@]}"; do
        host=${item%%:*}; cmd=${item#*:}; n=$((n + 1))
        echo "==> [$n/${#STARTS[@]}] $host: ${cmd##*/}"
        if ! roda "$host" "$cmd"; then
            echo "ERRO: preparacao falhou em $host (${cmd##*/})." >&2
            echo "      Rode 'lab finish examsim-full' para limpar o que ja foi preparado." >&2
            return 1
        fi
        case "$cmd" in
            *storage-start)
                d1=$(printf '%s\n' "$SAIDA" | sed -n 's/^DISCO1=//p')
                d6=$(printf '%s\n' "$SAIDA" | sed -n 's/^DISCO6=//p') ;;
        esac
    done
    sed -e "s#@DISCO1@#${d1:-disco de 1 GiB}#g" -e "s#@DISCO6@#${d6:-disco de 6 GiB}#g" \
        "$FULL/examsim-full-enunciado.txt" > "$DIR/enunciado.txt"
    echo
    cat "$DIR/enunciado.txt"
    echo
    echo "==> Prova iniciada em $(cat "$MARCA"). Enunciado salvo em $DIR/enunciado.txt"
    echo "==> Ao terminar (ou esgotar as 3h): lab finish examsim-full"
}

# Linha-resumo nao pode conter palavras que o dashboard redige (senha etc.),
# senao o criterio inteiro vira [REDACTED].
limpa_texto() {
    sed -e 's/[Ss]enha/credencial/g' -e 's/[Pp]assword/credencial/g' -e 's/[Tt]oken/chave/g'
}

corrige() {
    local q titulo specs spec host resto var grader pend ok aprovadas=0 total=${#QUESTOES[@]}
    echo "==> Correcao da prova iniciada em $(cat "$MARCA")"
    for q in $(printf '%s\n' "${!QUESTOES[@]}" | sort -n); do
        titulo=${QUESTOES[$q]%%|*}; specs=${QUESTOES[$q]#*|}
        pend=""; ok=1
        printf '\n==> Q%02d — %s\n' "$q" "$titulo"
        for spec in $specs; do
            host=${spec%%:*}; resto=${spec#*:}; var=""
            case "$resto" in *=*:*) var=${resto%%:*}; resto=${resto#*:} ;; esac
            grader=$resto
            if ! roda "$host" "$var bash $LG/$grader.sh"; then
                ok=0
                [ -z "$SAIDA" ] && SAIDA="FALHOU: $host sem resposta"
                pend="$pend; $(printf '%s\n' "$SAIDA" | sed -n 's/^FALHOU:[[:space:]]*//p' | paste -sd';' | sed 's/;/; /g')"
            fi
        done
        if [ "$ok" -eq 1 ]; then
            aprovadas=$((aprovadas + 1))
            printf 'OK: Q%02d — %s\n' "$q" "$titulo"
        else
            pend=${pend#; }
            printf 'FALHOU: Q%02d — %s (%s)\n' "$q" "$titulo" "$(printf '%s' "${pend:-sem detalhe}" | limpa_texto | cut -c1-240)"
        fi
    done
    echo
    [ "$aprovadas" -eq "$total" ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
    local pct=$((aprovadas * 100 / total)) veredito=REPROVADO
    [ "$aprovadas" -ge "$APROVACAO" ] && veredito=APROVADO
    echo "Nota $aprovadas/$total (${pct}%) — referência $APROVACAO/$total → $veredito"
}

limpa() {
    local item host cmd falhas=0
    echo
    echo "==> Limpando o ambiente (${#FINISHES[@]} etapas)"
    for item in "${FINISHES[@]}"; do
        host=${item%%:*}; cmd=${item#*:}
        echo "==> limpeza $host: ${cmd##*/}"
        roda "$host" "$cmd" || { falhas=$((falhas + 1)); echo "AVISO: limpeza falhou em $host (${cmd##*/})."; }
    done
    return $falhas
}

finish() {
    if [ ! -e "$MARCA" ]; then
        echo "ERRO: nenhuma prova aberta. Comece com 'lab start examsim-full'." >&2
        return 2
    fi
    checa_hosts || return 2
    local rel
    rel="$DIR/resultado-$(date +%Y%m%dT%H%M%S).txt"
    corrige | tee "$rel"
    echo "==> Relatorio salvo em $rel"
    if limpa; then
        rm -f "$MARCA"
        echo "==> Ambiente limpo. Pronto para outra prova: lab start examsim-full"
    else
        echo "AVISO: parte da limpeza falhou; a prova continua marcada como aberta." >&2
        echo "       Corrija e rode 'lab finish examsim-full' de novo." >&2
    fi
    grep -q '^RESULTADO: PASSOU$' "$rel"
    [ $? -eq 0 ] && return 0 || return 1
}

case "${1:-}" in
    start) start ;;
    grade)
        echo "A prova completa nao tem correcao parcial, como no EX200 real."
        echo "A correcao acontece so' no 'lab finish examsim-full' (avalia as 24 questoes e limpa)."
        exit 2 ;;
    finish) finish ;;
    *) echo "Uso: $0 start|grade|finish" >&2; exit 1 ;;
esac

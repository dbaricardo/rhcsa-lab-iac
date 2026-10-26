#!/bin/bash
# examsim-dinamico — prova EX200 sorteada a cada execucao (24 questoes, minimo de
# 2 por dominio, pesos do EX200 v10), corrigida so' no finish.
#
# Roda na workstation como student, chamado pelo dispatcher
# (lab start|grade|finish examsim-dinamico). Mesmo modelo do examsim-full.sh:
# SSH como root nos hosts, saida subordinada indentada com " │ " para nao ser
# confundida com criterio, e o finish imprime uma linha OK/FALHOU por questao
# mais uma unica linha "RESULTADO: PASSOU|FALHOU" (le: backend.parse_grade).
#
# O sorteio e os passos vem de dyn.py; as tarefas portadas (dyn/tasks/*.sh) sao
# enviadas ao host como argumento de "bash -c" (nada para reinstalar nas VMs
# depois de um restore). As tarefas legadas usam os scripts ja instalados.
#
# LAB_SEED=<n> reproduz uma prova. Uso: examsim-dinamico.sh start|grade|finish
set -u

SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
DYN=/usr/local/lib/lab-dyn
PY="python3 $DYN/dyn.py"
DIR=$HOME/examsim-dinamico
MARCA=$DIR/.aberta
MAN=$DIR/prova.json
RES=$DIR/.resultados
PUB=/var/lib/rhcsa-lab-dashboard/dinamico

# roda <host> <comando>: executa como root no host, mostra a saida indentada e
# a deixa em $SAIDA.
roda() {
    local host=$1 rc
    shift
    SAIDA=$(ssh $SSH_OPTS "root@$host" "$*" 2>&1 </dev/null)
    rc=$?
    [ -n "$SAIDA" ] && printf '%s\n' "$SAIDA" | sed 's/^/    │ /'
    return $rc
}

# roda_passo <host> <tipo> <a> <b>: tipo cmd (a = comando) ou script
# (a = "tasks/x.sh|fase", b = "K=V ..." exportado para a tarefa).
roda_passo() {
    local host=$1 kind=$2 a=$3 b=$4 file fn body
    if [ "$kind" = cmd ]; then
        roda "$host" "$a"
        return
    fi
    file=${a%%|*}; fn=${a##*|}
    body=$(cat "$DYN/tasks/_lib.sh" "$DYN/$file" | base64 -w0)
    roda "$host" "env $b bash -c \"\$(printf %s $body | base64 -d)\" _ $fn"
}

# "senha" vira "credencial" para a linha nao ser apagada pelo painel; a credencial
# de exercicio em si nao deve aparecer no texto da correcao.
limpa_texto() {
    sed -e 's/[Ss]enha/credencial/g' -e 's/[Pp]assword/credencial/g' -e 's/[Tt]oken/chave/g' \
        -e "s/atenorth/[credencial do exercicio]/g"
}

checa_hosts() {
    local h
    for h in "$@"; do
        if ! ssh $SSH_OPTS "root@$h" true 2>/dev/null; then
            echo "ERRO: nao consegui alcancar root@$h por SSH. Nada foi alterado." >&2
            return 1
        fi
    done
}

# Descobre em cada host qual /dev/X tem cada tamanho (os discos de pratica sao achados
# pelo tamanho) e troca os @DISK@ do enunciado pelos nomes reais.
bind_discos() {
    local h tsv="$DIR/.discos.tsv"
    : > "$tsv"
    for h in $($PY hosts "$MAN"); do
        [ "$h" = localhost ] && continue
        ssh $SSH_OPTS "root@$h" 'lsblk -bdnro NAME,SIZE -e 7,11' </dev/null 2>/dev/null \
            | awk -v h="$h" '{print h "\t" $1 "\t" $2}' >> "$tsv"
    done
    $PY bind "$MAN" "$tsv"
}

publica() {  # publica <estado-json> -> painel
    mkdir -p "$PUB/history"
    printf '%s\n' "$1" > "$PUB/current.json.novo" && mv -f "$PUB/current.json.novo" "$PUB/current.json"
}

start() {
    if [ -e "$MARCA" ]; then
        echo "ERRO: ja existe uma prova dinamica aberta (desde $(cat "$MARCA"))." >&2
        echo "      Rode 'lab finish examsim-dinamico' para corrigir e limpar antes de comecar outra." >&2
        return 1
    fi
    if [ -e "$HOME/examsim-full/.aberta" ]; then
        echo "ERRO: o examsim-full esta aberto. Encerre com 'lab finish examsim-full' antes." >&2
        return 1
    fi
    mkdir -p "$DIR"; chmod 700 "$DIR"
    $PY draw --pool "$DYN/pool.json" --out "$MAN.novo" ${LAB_SEED:+--seed "$LAB_SEED"} || return 2
    mv -f "$MAN.novo" "$MAN"
    checa_hosts $($PY hosts "$MAN") || return 2
    bind_discos
    # Marca antes de mexer em qualquer coisa: se um start falhar no meio, o
    # finish ainda consegue limpar o que ja foi preparado.
    date '+%d/%m/%Y %H:%M:%S' > "$MARCA"
    publica "$($PY public "$MAN")"

    local total n=0 d1="" d6="" q label host kind a b
    total=$($PY steps "$MAN" start | wc -l)
    while IFS=$'\t' read -r q label host kind a b; do
        n=$((n + 1))
        echo "==> [$n/$total] $host: $label"
        if ! roda_passo "$host" "$kind" "$a" "$b"; then
            echo "ERRO: preparacao falhou em $host ($label)." >&2
            echo "      Rode 'lab finish examsim-dinamico' para limpar o que ja foi preparado." >&2
            return 1
        fi
        case "$a" in
            *storage-start)
                d1=$(printf '%s\n' "$SAIDA" | sed -n 's/^DISCO1=//p')
                d6=$(printf '%s\n' "$SAIDA" | sed -n 's/^DISCO6=//p') ;;
        esac
    done < <($PY steps "$MAN" start)

    $PY statement "$MAN" --disco1 "${d1:-disco de 1 GiB}" --disco6 "${d6:-disco de 6 GiB}" > "$DIR/enunciado.txt"
    cat "$DIR/enunciado.txt"
    echo "==> Prova iniciada em $(cat "$MARCA"). Enunciado salvo em $DIR/enunciado.txt"
    echo "    Corrija e limpe com: lab finish examsim-dinamico"
}

corrige() {
    local q titulo pend ok step host kind a b label
    : > "$RES"
    echo "==> Correcao da prova iniciada em $(cat "$MARCA")"
    while IFS=$'\t' read -r q titulo; do
        pend=""; ok=1
        printf '\n==> Q%02d — %s\n' "$q" "$titulo"
        while IFS=$'\t' read -r _ label host kind a b; do
            if ! roda_passo "$host" "$kind" "$a" "$b"; then
                ok=0
                [ -z "$SAIDA" ] && SAIDA="FALHOU: $host sem resposta"
                pend="$pend; $(printf '%s\n' "$SAIDA" | sed -n 's/^FALHOU:[[:space:]]*//p' | paste -sd';' | sed 's/;/; /g')"
            fi
        done < <($PY steps "$MAN" grade --q "$q")
        pend=${pend#; }
        if [ "$ok" -eq 1 ]; then
            printf 'OK: Q%02d — %s\n' "$q" "$titulo"
            printf '%s\tOK\t\n' "$q" >> "$RES"
        else
            pend=$(printf '%s' "${pend:-sem detalhe}" | limpa_texto | cut -c1-240)
            printf 'FALHOU: Q%02d — %s (%s)\n' "$q" "$titulo" "$pend"
            printf '%s\tFALHOU\t%s\n' "$q" "$pend" >> "$RES"
        fi
    done < <($PY questions "$MAN")
    echo
    $PY summary "$MAN" "$RES"
}

limpa() {
    local total n=0 falhas=0 q label host kind a b
    total=$($PY steps "$MAN" finish | wc -l)
    echo
    echo "==> Limpando o ambiente ($total etapas)"
    while IFS=$'\t' read -r q label host kind a b; do
        n=$((n + 1))
        echo "==> limpeza [$n/$total] $host: $label"
        roda_passo "$host" "$kind" "$a" "$b" || { falhas=$((falhas + 1)); echo "AVISO: limpeza falhou em $host ($label)."; }
    done < <($PY steps "$MAN" finish)
    return $falhas
}

finish() {
    if [ ! -e "$MARCA" ]; then
        echo "ERRO: nenhuma prova aberta. Comece com 'lab start examsim-dinamico'." >&2
        return 2
    fi
    checa_hosts $($PY hosts "$MAN") || return 2
    local rel
    rel="$DIR/resultado-$(date +%Y%m%dT%H%M%S).txt"
    corrige | tee "$rel"
    echo "==> Relatorio salvo em $rel"
    # Fecha no painel antes de limpar: o resultado vale mesmo se a limpeza falhar.
    mkdir -p "$PUB/history"
    $PY archive "$MAN" "$RES" > "$PUB/history/$(python3 -c "import json,sys;print(json.load(open('$MAN'))['id'])").json"
    if limpa; then
        rm -f "$MARCA" "$PUB/current.json"
        echo "==> Ambiente limpo. Pronto para outra prova: lab start examsim-dinamico"
    else
        echo "AVISO: parte da limpeza falhou; prova continua marcada como aberta." >&2
        echo "       Corrija e rode 'lab finish examsim-dinamico' de novo." >&2
    fi
    grep -q '^RESULTADO: PASSOU$' "$rel"
    [ $? -eq 0 ] && return 0 || return 1
}

# Carregado com "source" (QA) so' define as funcoes; executado, despacha o subcomando.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
case "${1:-}" in
    start)  start ;;
    grade)
        echo "O exame dinamico nao tem correcao parcial, como no EX200 real."
        echo "A correcao acontece so' no 'lab finish examsim-dinamico' (avalia as questoes e limpa)."
        exit 2 ;;
    finish) finish ;;
    *) echo "Uso: $0 start|grade|finish" >&2; exit 1 ;;
esac

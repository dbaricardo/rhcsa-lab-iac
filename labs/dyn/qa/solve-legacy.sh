#!/bin/bash
# Resolve as questoes LEGADAS (examsim-*) da prova dinamica aberta com a solucao de referencia,
# no host de cada questao. Complementa o solve-exam.sh (que so' resolve as portadas).
# Uso (workstation, como student, com a prova aberta):  solve-legacy.sh [id-da-tarefa ...]
DYN=${DYN:-/usr/local/lib/lab-dyn}
MAN=${MAN:-$HOME/examsim-dinamico/prova.json}
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10"
# shellcheck disable=SC1091
source "$DYN/qa/solutions-legacy.sh"
[ -f "$MAN" ] || { echo "ERRO: nenhuma prova aberta ($MAN)"; exit 2; }
feitas=0; falhas=0
while IFS=$'\t' read -r q id host; do
    [ -n "$*" ] && case " $* " in *" $id "*) ;; *) continue ;; esac
    [ -n "${LSOL[$id]:-}" ] || { echo "Q$(printf %02d "$q") $id: sem solucao de referencia"; falhas=$((falhas + 1)); continue; }
    saida=$(ssh $SSH_OPTS "root@$host" "bash -c $(printf '%q' "$LPRE set -e; ${LSOL[$id]}")" 2>&1 </dev/null); rc=$?
    if [ "$rc" -eq 0 ]; then feitas=$((feitas + 1)); printf 'Q%02d %-30s @ %-8s resolvida\n' "$q" "$id" "$host"
    else falhas=$((falhas + 1)); printf 'Q%02d %-30s @ %-8s FALHOU: %s\n' "$q" "$id" "$host" "$(echo "$saida" | tail -2 | tr '\n' ' ')"; fi
done < <(python3 -c "
import json,sys
for q in json.load(open('$MAN'))['questions']:
    if q['kind'] == 'legacy': print(q['q'], q['id'], q['host'], sep='\t')")
echo "resolvidas: $feitas | falhas: $falhas"
[ "$falhas" -eq 0 ]

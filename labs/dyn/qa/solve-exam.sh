#!/bin/bash
# Resolve as questoes PORTADAS da prova dinamica aberta, aplicando a solucao de referencia
# do QA em cada host. Serve para testar o ciclo real start -> (resolver) -> finish.
# As questoes legadas (scripts examsim-*) nao sao resolvidas aqui.
# Uso (workstation, como student, com a prova aberta):  solve-exam.sh [id-da-tarefa ...]
DYN=${DYN:-/usr/local/lib/lab-dyn}
MAN=${MAN:-$HOME/examsim-dinamico/prova.json}
# shellcheck disable=SC1091
source "$DYN/qa/validate-ported.sh"
[ -f "$MAN" ] || { echo "ERRO: nenhuma prova aberta ($MAN)"; exit 2; }
only=" $* "
feitas=0; falhas=0
while IFS=$'\t' read -r q id host kind a envw; do
    [ "$kind" = script ] && [ "${a##*|}" = start ] || continue
    [ "$envw" = "" ] && envw="_QA=1"
    [ -n "$*" ] && case "$only" in *" $id "*) ;; *) continue ;; esac
    [ -n "${SOL[$id]:-}" ] || { echo "Q$(printf %02d "$q") $id: sem solucao de referencia"; continue; }
    saida=$(host_cmd "$host" "$envw" "${SOL[$id]}" estrito); rc=$?
    if [ "$rc" -eq 0 ]; then feitas=$((feitas + 1)); printf 'Q%02d %-26s @ %-8s resolvida\n' "$q" "$id" "$host"
    else falhas=$((falhas + 1)); printf 'Q%02d %-26s @ %-8s FALHOU: %s\n' "$q" "$id" "$host" "$(echo "$saida" | tail -2 | tr '\n' ' ')"; fi
done < <(python3 "$DYN/dyn.py" steps "$MAN" start)
echo "resolvidas: $feitas | falhas: $falhas"
[ "$falhas" -eq 0 ]

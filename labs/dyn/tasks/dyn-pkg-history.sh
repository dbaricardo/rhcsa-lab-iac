# Dominio 1 / packages: historico de transacoes do dnf em arquivo. Params: OUT
ID=dyn-pkg-history
do_start() { rm -f "$OUT"; echo "arquivo $OUT inexistente."; }
do_grade() {
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    total=$(dnf -q history list 2>/dev/null | awk '$1 ~ /^[0-9]+$/' | wc -l)
    got=$(awk '$1 ~ /^[0-9]+$/' "$OUT" 2>/dev/null | wc -l)
    want=$(( total < 10 ? total : 10 ))
    [ "$got" -ge "$want" ] && [ "$got" -gt 0 ]; check $? "o arquivo lista pelo menos $want transacoes (tem $got)"
    bad=0
    for id in $(awk '$1 ~ /^[0-9]+$/ {print $1}' "$OUT" 2>/dev/null); do
        dnf -q history list 2>/dev/null | awk -v i="$id" '$1 == i {f=1} END {exit !f}' || bad=1
    done
    [ "$bad" -eq 0 ]; check $? "todos os IDs do arquivo existem no historico real do dnf"
}
do_finish() { rm -f "$OUT"; echo "limpeza: $OUT removido."; }
run "$@"

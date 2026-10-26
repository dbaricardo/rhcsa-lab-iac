# Dominio 2 / journalctl: log de uma unidade em arquivo. Params: UNIT OUT
ID=dyn-journal-filter-unit
do_start() { rm -f "$OUT"; echo "arquivo $OUT inexistente."; }
do_grade() {
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    journalctl -u "$UNIT" --no-pager 2>/dev/null | grep -v '^-- ' | head -5 > "$ST/$ID.exp"
    missing=0
    while IFS= read -r l; do grep -qF -- "$l" "$OUT" 2>/dev/null || missing=$((missing + 1)); done < "$ST/$ID.exp"
    [ -s "$ST/$ID.exp" ] && [ "$missing" -eq 0 ]; check $? "o arquivo traz o log de $UNIT (faltam $missing de 5 linhas conferidas)"
    rm -f "$ST/$ID.exp"
}
do_finish() { rm -f "$OUT"; rm -f "${ST:?}/$ID.exp"; echo "limpeza: $OUT removido."; }
run "$@"

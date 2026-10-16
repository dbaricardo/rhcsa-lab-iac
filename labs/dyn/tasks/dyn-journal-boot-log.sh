# Dominio 2 / journalctl: log do boot atual filtrado por prioridade. Params: PRIO OUT
ID=dyn-journal-boot-log
do_start() { rm -f "$OUT"; echo "arquivo $OUT inexistente."; }
do_grade() {
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    journalctl -b 0 -p "$PRIO" --no-pager 2>/dev/null | grep -v '^-- ' | head -5 > "$ST/$ID.exp"
    missing=0
    while IFS= read -r l; do grep -qF -- "$l" "$OUT" 2>/dev/null || missing=$((missing + 1)); done < "$ST/$ID.exp"
    [ -s "$ST/$ID.exp" ] && [ "$missing" -eq 0 ]; check $? "o arquivo traz as mensagens do boot atual com prioridade $PRIO (faltam $missing de 5 conferidas)"
    rm -f "$ST/$ID.exp"
}
do_finish() { rm -f "$OUT"; rm -f "${ST:?}/$ID.exp"; echo "limpeza: $OUT removido."; }
run "$@"

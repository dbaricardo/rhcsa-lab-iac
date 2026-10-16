# Dominio 1 / packages: qual pacote fornece um arquivo. Params: TARGET OUT
ID=dyn-pkg-provides
do_start() { rm -f "$OUT"; echo "arquivo $OUT inexistente."; }
do_grade() {
    want=$(rpm -qf --qf '%{NAME}\n' "$TARGET" 2>/dev/null | head -1)
    [ -n "$want" ]; check $? "(referencia) $TARGET pertence a um pacote instalado"
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    grep -Eq "(^|[[:space:]])$want-[0-9]" "$OUT" 2>/dev/null || grep -Eq "^Name[[:space:]]*:[[:space:]]*$want[[:space:]]*$" "$OUT" 2>/dev/null
    check $? "o arquivo cita o pacote correto ($want)"
}
do_finish() { rm -f "$OUT"; echo "limpeza: $OUT removido."; }
run "$@"

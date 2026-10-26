# Dominio 2 / boot: entradas de boot e kernel padrao em arquivo. Params: OUT
ID=dyn-boot-entries
do_start() { rm -f "$OUT"; echo "arquivo $OUT inexistente."; }
do_grade() {
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    def=$(grubby --default-kernel 2>/dev/null)
    [ -n "$def" ] && grep -qF "$def" "$OUT" 2>/dev/null; check $? "o arquivo identifica o kernel padrao ($def)"
    missing=0
    for k in $(grubby --info=ALL 2>/dev/null | sed -n 's/^kernel="\(.*\)"$/\1/p'); do
        grep -qF "$k" "$OUT" 2>/dev/null || missing=$((missing + 1))
    done
    [ "$missing" -eq 0 ]; check $? "o arquivo lista todas as entradas de boot (faltam $missing)"
}
do_finish() { rm -f "$OUT"; echo "limpeza: $OUT removido."; }
run "$@"

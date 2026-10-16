# Dominio 2 / boot: tempo de boot e servicos mais lentos em arquivo. Params: OUT TOPN
ID=dyn-boot-analyze
do_start() { rm -f "$OUT"; echo "arquivo $OUT inexistente."; }
do_grade() {
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    grep -q "Startup finished in" "$OUT" 2>/dev/null; check $? "o arquivo traz o tempo total de boot (systemd-analyze)"
    missing=0
    for u in $(systemd-analyze blame --no-pager 2>/dev/null | head -"$TOPN" | awk '{print $NF}'); do
        grep -qF "$u" "$OUT" 2>/dev/null || missing=$((missing + 1))
    done
    [ "$missing" -eq 0 ]; check $? "o arquivo lista os $TOPN servicos mais lentos (faltam $missing)"
}
do_finish() { rm -f "$OUT"; echo "limpeza: $OUT removido."; }
run "$@"

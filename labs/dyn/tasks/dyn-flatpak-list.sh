# Dominio 1 / flatpak: listar o que um remote oferece em arquivo. Params: NAME MODE OUT (MODE: app|runtime)
ID=dyn-flatpak-list
do_start() {
    fp_remote_has "$NAME" && flatpak remote-delete --system --force "$NAME" &>/dev/null
    flatpak remote-add --system "$NAME" "$FP_URL" &>/dev/null || { echo "ERRO: nao consegui adicionar o remote $NAME"; return 1; }
    : > "$ST/$ID.fpremote.new"
    rm -f "$OUT"
    echo "remote $NAME configurado; $OUT inexistente."
}
do_grade() {
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    for id in $(flatpak remote-ls --system "$NAME" "--$MODE" --columns=application 2>/dev/null | sort -u); do
        grep -qF "$id" "$OUT" 2>/dev/null; check $? "o arquivo lista $id"
    done
    if [ "$MODE" = app ]; then
        ! grep -q "org.freedesktop.Platform" "$OUT" 2>/dev/null; check $? "o arquivo traz so' aplicativos, sem runtimes"
    fi
}
do_finish() {
    rm -f "$OUT"
    flatpak remote-delete --system --force "$NAME" &>/dev/null
    rm -f "${ST:?}/$ID.fpremote.new"
    echo "limpeza: $OUT e remote $NAME removidos."
}
run "$@"

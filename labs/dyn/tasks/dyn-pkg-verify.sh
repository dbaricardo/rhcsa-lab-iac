# Dominio 1 / packages: rpm -V acusa arquivo alterado. Params: PKG CONF OUT
ID=dyn-pkg-verify
do_start() {
    conf_save "$CONF" "$ID"
    echo "# alterado na prova" >> "$CONF"
    rm -f "$OUT"
    if rpm -V "$PKG" 2>/dev/null | grep -q " $CONF\$"; then echo "$CONF alterado."; else echo "ERRO: rpm -V nao acusa $CONF"; return 1; fi
}
do_grade() {
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    grep -Eq "^[S.][M.][5.].*[[:space:]]$CONF[[:space:]]*$" "$OUT" 2>/dev/null
    check $? "o arquivo mostra a linha do rpm -V para $CONF"
}
do_finish() {
    conf_restore "$CONF" "$ID"
    rm -f "$OUT"
    echo "limpeza: $CONF e $OUT restaurados."
}
run "$@"

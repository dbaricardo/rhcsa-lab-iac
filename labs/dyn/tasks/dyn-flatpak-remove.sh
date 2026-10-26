# Dominio 1 / flatpak: remover um aplicativo e os runtimes sem uso. Params: NAME APP
ID=dyn-flatpak-remove
do_start() {
    fp_refs > "$ST/$ID.fprefs"
    fp_remote_has "$NAME" && flatpak remote-delete --system --force "$NAME" &>/dev/null
    flatpak remote-add --system "$NAME" "$FP_URL" &>/dev/null || { echo "ERRO: nao consegui adicionar o remote $NAME"; return 1; }
    : > "$ST/$ID.fpremote.new"
    flatpak install --system -y --noninteractive "$NAME" "$APP" &>/dev/null
    flatpak list --system --app --columns=application | grep -qxF "$APP" || { echo "ERRO: nao consegui instalar $APP"; return 1; }
    echo "aplicativo $APP instalado (origem $NAME)."
}
do_grade() {
    ! flatpak list --system --app --columns=application 2>/dev/null | grep -qxF "$APP"
    check $? "o aplicativo $APP foi removido"
    extra=$(fp_refs | comm -13 "$ST/$ID.fprefs" - | grep -c .)
    [ "$extra" -eq 0 ]; check $? "nao sobrou runtime sem uso instalado por causa do aplicativo ($extra restante(s))"
}
do_finish() { fp_undo "$ID" "$NAME"; echo "limpeza: runtimes novos e remote $NAME removidos."; }
run "$@"

# Dominio 1 / flatpak: instalar um aplicativo de um remote. Params: NAME APP
ID=dyn-flatpak-install
do_start() {
    fp_refs > "$ST/$ID.fprefs"
    fp_remote_has "$NAME" && flatpak remote-delete --system --force "$NAME" &>/dev/null
    flatpak remote-add --system "$NAME" "$FP_URL" &>/dev/null || { echo "ERRO: nao consegui adicionar o remote $NAME"; return 1; }
    : > "$ST/$ID.fpremote.new"
    flatpak uninstall --system -y --noninteractive "$APP" &>/dev/null
    echo "remote $NAME configurado; $APP nao instalado."
}
do_grade() {
    flatpak list --system --app --columns=application 2>/dev/null | grep -qxF "$APP"
    check $? "o aplicativo $APP esta instalado no sistema (flatpak list --app)"
    org=$(flatpak list --system --app --columns=application,origin 2>/dev/null | awk -v a="$APP" '$1 == a {print $2}')
    [ "$org" = "$NAME" ]; check $? "o aplicativo veio do remote $NAME (origem atual: ${org:-nenhuma})"
}
do_finish() { fp_undo "$ID" "$NAME"; echo "limpeza: aplicativo, runtimes novos e remote $NAME removidos."; }
run "$@"

# Dominio 1 / flatpak: adicionar um remote de sistema. Params: NAME
ID=dyn-flatpak-remote
do_start() {
    fp_remote_has "$NAME" && flatpak remote-delete --system --force "$NAME" &>/dev/null
    : > "$ST/$ID.fpremote.new"
    echo "remote $NAME inexistente."
}
do_grade() {
    fp_remote_has "$NAME"; check $? "o remote de SISTEMA $NAME existe (flatpak remotes --system)"
    url=$(flatpak remotes --system --columns=name,url 2>/dev/null | awk -v n="$NAME" '$1 == n {print $2}')
    case "$url" in http://flatpak.lab.example.com:8091*) true ;; *) false ;; esac
    check $? "o remote $NAME aponta para flatpak.lab.example.com:8091 (atual: ${url:-nada})"
    flatpak remote-ls --system "$NAME" --app 2>/dev/null | grep -q .
    check $? "o remote $NAME responde e lista aplicativos"
}
do_finish() {
    flatpak remote-delete --system --force "$NAME" &>/dev/null
    rm -f "${ST:?}/$ID.fpremote.new"
    echo "limpeza: remote $NAME removido."
}
run "$@"

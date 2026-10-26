# Dominio 1 / repos: habilitar ou desabilitar um repositorio. Params: REPOID ACTION
ID=dyn-repo-enable-disable
do_start() {
    yumrepo_save "$ID"
    repo_forget "$REPOID"
    if [ "$ACTION" = enable ]; then cur=0; else cur=1; fi
    cat > "$RD/dyn-$REPOID.repo" <<REPO
[$REPOID]
name=Lab mirror $REPOID
baseurl=$MIRROR/rhel10.0/x86_64/dvd/AppStream
enabled=$cur
gpgcheck=0
REPO
    restorecon "$RD/dyn-$REPOID.repo" 2>/dev/null
    echo "repositorio $REPOID com enabled=$cur."
}
do_grade() {
    if [ "$ACTION" = enable ]; then want=1; else want=0; fi
    [ "$(repo_val "$REPOID" enabled)" = "$want" ]; check $? "enabled=$want no arquivo .repo (persistente; atual: $(repo_val "$REPOID" enabled))"
    if [ "$want" = 1 ]; then repo_listed "$REPOID" --enabled; else ! repo_listed "$REPOID" --enabled; fi
    check $? "o dnf $( [ "$want" = 1 ] && echo lista || echo nao lista ) $REPOID entre os repositorios habilitados"
}
do_finish() { yumrepo_restore "$ID"; echo "limpeza: repositorios restaurados."; }
run "$@"

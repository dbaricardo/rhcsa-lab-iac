# Dominio 1 / repos: criar um repositorio dnf. Params: REPOID REPONAME URL GPG
ID=dyn-repo-configure
do_start() {
    yumrepo_save "$ID"
    repo_forget "$REPOID"; rm -f "${RD:?}/${REPOID:?}.repo"
    echo "repositorio $REPOID inexistente."
}
do_grade() {
    [ -f "$RD/$REPOID.repo" ]; check $? "o arquivo $RD/$REPOID.repo existe"
    [ "$(repo_val "$REPOID" name)" = "$REPONAME" ]; check $? "name=$REPONAME (atual: $(repo_val "$REPOID" name))"
    u=$(repo_val "$REPOID" baseurl)
    [ "${u%/}" = "${URL%/}" ]; check $? "baseurl=$URL (atual: ${u:-vazio})"
    [ "$(repo_val "$REPOID" enabled)" = 1 ]; check $? "enabled=1"
    [ "$(repo_val "$REPOID" gpgcheck)" = "$GPG" ]; check $? "gpgcheck=$GPG (atual: $(repo_val "$REPOID" gpgcheck))"
    repo_listed "$REPOID"; check $? "o dnf lista o repositorio $REPOID (dnf repolist)"
    repo_works "$REPOID"; check $? "o repositorio $REPOID responde e tem pacotes"
}
do_finish() { yumrepo_restore "$ID"; echo "limpeza: repositorios restaurados."; }
run "$@"

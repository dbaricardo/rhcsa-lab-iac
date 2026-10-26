# Dominio 1 / repos: repositorio de terceiros + instalar pacote. Params: REPOID REPONAME
ID=dyn-repo-thirdparty
URL=$MIRROR/timer-repo
PKG=logger
do_start() {
    yumrepo_save "$ID"
    repo_forget "$REPOID"; rm -f "${RD:?}/${REPOID:?}.repo"
    pkg_orig_save "$ID" "$PKG"
    rpm -q "$PKG" &>/dev/null && rpm -e "$PKG" &>/dev/null
    echo "repositorio $REPOID inexistente; pacote $PKG ausente."
}
do_grade() {
    [ -f "$RD/$REPOID.repo" ]; check $? "o arquivo $RD/$REPOID.repo existe"
    [ "$(repo_val "$REPOID" name)" = "$REPONAME" ]; check $? "name=$REPONAME (atual: $(repo_val "$REPOID" name))"
    u=$(repo_val "$REPOID" baseurl)
    [ "${u%/}" = "$URL" ]; check $? "baseurl=$URL (atual: ${u:-vazio})"
    [ "$(repo_val "$REPOID" enabled)" = 1 ]; check $? "enabled=1"
    [ "$(repo_val "$REPOID" gpgcheck)" = 0 ]; check $? "gpgcheck=0 (os pacotes do repositorio nao sao assinados)"
    rpm -q "$PKG" &>/dev/null; check $? "o pacote $PKG foi instalado a partir do repositorio"
}
do_finish() {
    o=$(cat "$ST/$ID.pkg" 2>/dev/null)
    if [ "$o" = absent ]; then rpm -e "$PKG" &>/dev/null; fi
    rm -f "${ST:?}/$ID.pkg"
    yumrepo_restore "$ID"
    echo "limpeza: $PKG e repositorios restaurados."
}
run "$@"

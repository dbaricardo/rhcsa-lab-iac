# Dominio 1 / repos: consertar um repositorio quebrado. Params: SCEN (wrongurl|nobaseurl|disabled|badscheme)
ID=dyn-repo-troubleshoot
GOOD=$MIRROR/rhel10.0/x86_64/dvd/AppStream
REPOID=dyn-broken
do_start() {
    yumrepo_save "$ID"
    repo_forget "$REPOID"
    en=1; url="baseurl=$GOOD"
    case "$SCEN" in
        wrongurl)  url="baseurl=$MIRROR/rhel9.0/x86_64/dvd/AppStream" ;;
        nobaseurl) url="" ;;
        disabled)  en=0 ;;
        badscheme) url="baseurl=htp://content.example.com:8091/rhel10.0/x86_64/dvd/AppStream" ;;
    esac
    { echo "[$REPOID]"; echo "name=Repositorio quebrado"; [ -n "$url" ] && echo "$url"
      echo "enabled=$en"; echo "gpgcheck=0"; } > "$RD/$REPOID.repo"
    restorecon "$RD/$REPOID.repo" 2>/dev/null
    echo "repositorio $REPOID quebrado ($SCEN)."
}
do_grade() {
    u=$(repo_val "$REPOID" baseurl)
    [ "${u%/}" = "$GOOD" ]; check $? "baseurl=$GOOD (atual: ${u:-vazio})"
    [ "$(repo_val "$REPOID" enabled)" = 1 ]; check $? "enabled=1 (atual: $(repo_val "$REPOID" enabled))"
    repo_listed "$REPOID"; check $? "o dnf lista o repositorio $REPOID"
    repo_works "$REPOID"; check $? "o repositorio $REPOID responde e tem pacotes"
}
do_finish() { yumrepo_restore "$ID"; echo "limpeza: repositorios restaurados."; }
run "$@"

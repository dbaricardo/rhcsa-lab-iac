# Dominio 1 / repos: BaseOS e AppStream do mirror. Params: BASEID APPID
ID=dyn-repo-baseos-appstream
do_start() {
    yumrepo_save "$ID"
    repo_forget "$BASEID"; repo_forget "$APPID"
    echo "repositorios $BASEID e $APPID inexistentes."
}
do_grade() {
    for pair in "$BASEID:BaseOS" "$APPID:AppStream"; do
        id=${pair%%:*}; dir=${pair##*:}
        u=$(repo_val "$id" baseurl)
        [ "${u%/}" = "$MIRROR/rhel10.0/x86_64/dvd/$dir" ]; check $? "$id: baseurl aponta para o $dir do mirror (atual: ${u:-vazio})"
        [ "$(repo_val "$id" enabled)" = 1 ]; check $? "$id: enabled=1"
        repo_listed "$id"; check $? "$id: o dnf lista o repositorio"
    done
    dnf -q --disablerepo='*' --enablerepo="$BASEID,$APPID" list available tree 2>/dev/null | grep -q '^tree'
    check $? "os dois repositorios juntos entregam o pacote tree (dnf list available tree)"
}
do_finish() { yumrepo_restore "$ID"; echo "limpeza: repositorios restaurados."; }
run "$@"

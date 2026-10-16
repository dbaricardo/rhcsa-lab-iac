# Dominio 3 / permissions: umask persistente de um usuario. Params: ACCT UMASKV
ID=dyn-perm-umask
do_start() {
    if [ "$ACCT" != root ]; then user_mk "$ACCT" -m || exit 1; fi
    home=$(pw_field "$ACCT" 6)
    conf_save "$home/.bashrc" "$ID.bashrc"; conf_save "$home/.bash_profile" "$ID.profile"
    [ -e "$ST/$ID.pd" ] || { ls -1 /etc/profile.d > "$ST/$ID.pd"; }
    atual=$(su - "$ACCT" -s /bin/bash -c umask 2>/dev/null)
    [ "$atual" = "$UMASKV" ] && { echo "ERRO: o umask padrao de $ACCT ja e $UMASKV; a tarefa nasceria resolvida"; exit 1; }
    echo "o usuario $ACCT usa o umask padrao: $atual."
}
do_grade() {
    id "$ACCT" &>/dev/null; check $? "o usuario $ACCT existe"
    atual=$(su - "$ACCT" -s /bin/bash -c umask 2>/dev/null)
    [ "$atual" = "$UMASKV" ]; check $? "um login de $ACCT tem umask $UMASKV (atual: ${atual:-?})"
    # mktemp -d ignora o umask (sempre 700): cria o diretorio com mkdir
    d=$(su - "$ACCT" -s /bin/bash -c 'd=$(mktemp -u /tmp/dynumask.XXXXXX); mkdir "$d"; stat -c %a "$d"; rmdir "$d"' 2>/dev/null)
    esp=$(printf '%o' $(( 0777 & ~0$UMASKV )))
    [ "$d" = "$esp" ]; check $? "um diretorio novo nasce com modo $esp (atual: ${d:-?})"
}
do_finish() {
    local f home
    home=$(pw_field "$ACCT" 6)
    conf_restore "$home/.bashrc" "$ID.bashrc"; conf_restore "$home/.bash_profile" "$ID.profile"
    for f in /etc/profile.d/*; do
        [ -e "$f" ] || continue
        grep -qxF "${f##*/}" "$ST/$ID.pd" 2>/dev/null || rm -f -- "$f"
    done
    rm -f "${ST:?}/${ID:?}.pd"
    [ "$ACCT" != root ] && user_purge "$ACCT"
    echo "limpeza: configuracao de umask de $ACCT restaurada."
}
run "$@"

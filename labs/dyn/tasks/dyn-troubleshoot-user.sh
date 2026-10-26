# Dominio 3 / users_groups: consertar login. Params: ACCT PROBLEM(locked|nologin_shell|expired_account|expired_password)
ID=dyn-troubleshoot-user
do_start() {
    user_mk "$ACCT" -m -s /bin/bash || exit 1
    case "$PROBLEM" in
        locked)           usermod -L "$ACCT" ;;
        nologin_shell)    usermod -s /sbin/nologin "$ACCT" ;;
        expired_account)  chage -E 2020-01-01 "$ACCT" ;;
        expired_password) chage -d 2020-01-01 -M 30 "$ACCT" ;;
    esac
    echo "defeito injetado em $ACCT: $PROBLEM."
}
do_grade() {
    id "$ACCT" &>/dev/null; check $? "o usuario $ACCT existe"
    local st today exp lastchg max
    st=$(passwd -S "$ACCT" 2>/dev/null | awk '{print $2}')
    [ "$st" = PS ] || [ "$st" = P ]; check $? "a conta nao esta bloqueada (passwd -S: ${st:-?})"
    [ "$(pw_field "$ACCT" 7)" = /bin/bash ]; check $? "o shell e /bin/bash (atual: $(pw_field "$ACCT" 7))"
    today=$(( $(date +%s) / 86400 ))
    exp=$(sh_field "$ACCT" 8)
    [ -z "$exp" ] || [ "$exp" -gt "$today" ]; check $? "a conta nao esta expirada (expira: ${exp:-nunca})"
    lastchg=$(sh_field "$ACCT" 3); max=$(sh_field "$ACCT" 5)
    [ "$lastchg" != 0 ] && { [ -z "$max" ] || [ "$max" -ge 99999 ] || [ $((lastchg + max)) -gt "$today" ]; }
    check $? "a senha nao esta expirada nem com troca forcada"
    if [ "$PROBLEM" = expired_password ]; then [ "${max:-99999}" -le 90 ] ; check $? "o maximo de dias da senha e 90 ou menos (atual: ${max:-nao definido})"; fi
}
do_finish() { user_purge "$ACCT"; echo "limpeza: usuario $ACCT removido."; }
run "$@"

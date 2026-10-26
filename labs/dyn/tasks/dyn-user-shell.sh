# Dominio 3 / users_groups: trocar o shell de login. Params: ACCT NEWSHELL
ID=dyn-user-shell
do_start() {
    local ini=/bin/bash; [ "$NEWSHELL" = /bin/bash ] && ini=/bin/sh   # nunca comeca ja resolvida
    user_mk "$ACCT" -m -s "$ini" || exit 1
    echo "o usuario $ACCT existe com shell $ini."
}
do_grade() {
    id "$ACCT" &>/dev/null; check $? "o usuario $ACCT existe"
    [ "$(pw_field "$ACCT" 7)" = "$NEWSHELL" ]; check $? "o shell de $ACCT e $NEWSHELL (atual: $(pw_field "$ACCT" 7))"
}
do_finish() { user_purge "$ACCT"; echo "limpeza: usuario $ACCT removido."; }
run "$@"

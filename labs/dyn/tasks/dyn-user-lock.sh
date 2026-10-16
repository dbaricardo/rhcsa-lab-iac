# Dominio 3 / users_groups: bloquear ou desbloquear conta. Params: ACCT ACTION(lock|unlock)
ID=dyn-user-lock
do_start() {
    user_mk "$ACCT" -m || exit 1
    [ "$ACTION" = unlock ] && usermod -L "$ACCT"
    echo "a conta $ACCT existe e esta $( [ "$ACTION" = unlock ] && echo bloqueada || echo desbloqueada)."
}
do_grade() {
    id "$ACCT" &>/dev/null; check $? "a conta $ACCT continua existindo"
    local st; st=$(passwd -S "$ACCT" 2>/dev/null | awk '{print $2}')
    if [ "$ACTION" = lock ]; then [ "$st" = LK ] || [ "$st" = L ]; check $? "a conta $ACCT esta bloqueada (passwd -S: ${st:-?})"
    else [ "$st" = PS ] || [ "$st" = P ]; check $? "a conta $ACCT esta desbloqueada (passwd -S: ${st:-?})"; fi
}
do_finish() { user_purge "$ACCT"; echo "limpeza: usuario $ACCT removido."; }
run "$@"

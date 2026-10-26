# Dominio 3 / users_groups: usuario sem login interativo. Params: ACCT UIDN
ID=dyn-user-nologin
do_start() {
    user_purge "$ACCT"
    getent passwd "$UIDN" >/dev/null && { echo "ERRO: o UID $UIDN ja esta em uso; rode o lab start de novo"; exit 1; }
    echo "o usuario $ACCT nao existe."
}
do_grade() {
    id "$ACCT" &>/dev/null; check $? "o usuario $ACCT existe"
    [ "$(id -u "$ACCT" 2>/dev/null)" = "$UIDN" ]; check $? "o UID de $ACCT e $UIDN (atual: $(id -u "$ACCT" 2>/dev/null))"
    case "$(pw_field "$ACCT" 7)" in /sbin/nologin|/usr/sbin/nologin) true ;; *) false ;; esac
    check $? "o shell de $ACCT e /sbin/nologin (atual: $(pw_field "$ACCT" 7))"
    [ "$(pw_field "$ACCT" 6)" = "/home/$ACCT" ]; check $? "o home de $ACCT e /home/$ACCT"
}
do_finish() { user_purge "$ACCT"; echo "limpeza: usuario $ACCT removido."; }
run "$@"

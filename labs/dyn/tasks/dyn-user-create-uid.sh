# Dominio 3 / users_groups: usuario com UID e home. Params: ACCT UIDN
ID=dyn-user-create-uid
do_start() {
    user_purge "$ACCT"
    getent passwd "$UIDN" >/dev/null && { echo "ERRO: o UID $UIDN ja esta em uso; rode o lab start de novo"; exit 1; }
    echo "o usuario $ACCT nao existe."
}
do_grade() {
    id "$ACCT" &>/dev/null; check $? "o usuario $ACCT existe"
    [ "$(id -u "$ACCT" 2>/dev/null)" = "$UIDN" ]; check $? "o UID de $ACCT e $UIDN (atual: $(id -u "$ACCT" 2>/dev/null))"
    [ -d "/home/$ACCT" ]; check $? "o diretorio /home/$ACCT existe"
    [ "$(pw_field "$ACCT" 7)" = /bin/bash ]; check $? "o shell de $ACCT e /bin/bash (atual: $(pw_field "$ACCT" 7))"
}
do_finish() { user_purge "$ACCT"; echo "limpeza: usuario $ACCT removido."; }
run "$@"

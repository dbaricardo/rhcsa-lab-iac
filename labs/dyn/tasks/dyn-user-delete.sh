# Dominio 3 / users_groups: apagar usuario mantendo ou nao o home. Params: ACCT REMOVE_HOME(yes|no)
ID=dyn-user-delete
do_start() {
    user_mk "$ACCT" -m || exit 1
    echo "dados" > "/home/$ACCT/arquivo.txt"; chown "$ACCT" "/home/$ACCT/arquivo.txt"
    echo "o usuario $ACCT existe, com home e um arquivo."
}
do_grade() {
    ! id "$ACCT" &>/dev/null; check $? "o usuario $ACCT foi removido"
    if [ "$REMOVE_HOME" = yes ]; then [ ! -d "/home/$ACCT" ]; check $? "o home /home/$ACCT foi removido"
    else [ -f "/home/$ACCT/arquivo.txt" ]; check $? "o home /home/$ACCT foi preservado (com os dados)"; fi
}
do_finish() { user_purge "$ACCT"; echo "limpeza: usuario e home de $ACCT removidos."; }
run "$@"

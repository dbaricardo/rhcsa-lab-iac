# Dominio 3 / users_groups: conta de servico. Params: ACCT COMMENT
ID=dyn-svc-account
do_start() { user_purge "$ACCT"; echo "o usuario $ACCT nao existe."; }
do_grade() {
    id "$ACCT" &>/dev/null; check $? "o usuario $ACCT existe"
    uid=$(id -u "$ACCT" 2>/dev/null)
    [ -n "$uid" ] && [ "$uid" -lt 1000 ]; check $? "o UID de $ACCT esta na faixa de sistema, < 1000 (atual: ${uid:-?})"
    [ ! -d "$(pw_field "$ACCT" 6)" ]; check $? "nenhum diretorio home foi criado ($(pw_field "$ACCT" 6))"
    case "$(pw_field "$ACCT" 7)" in /sbin/nologin|/usr/sbin/nologin) true ;; *) false ;; esac
    check $? "o shell de $ACCT e /sbin/nologin (atual: $(pw_field "$ACCT" 7))"
    [ "$(pw_field "$ACCT" 5)" = "$COMMENT" ]; check $? "o comentario (GECOS) e \"$COMMENT\" (atual: \"$(pw_field "$ACCT" 5)\")"
}
do_finish() { user_purge "$ACCT"; echo "limpeza: usuario $ACCT removido."; }
run "$@"

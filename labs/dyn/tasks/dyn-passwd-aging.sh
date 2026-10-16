# Dominio 3 / users_groups: envelhecimento de senha (chage). Params: ACCT MAXD MIND WARN INACT FORCE
ID=dyn-passwd-aging
do_start() { user_mk "$ACCT" -m || exit 1; echo "o usuario $ACCT existe, sem politica de envelhecimento."; }
do_grade() {
    id "$ACCT" &>/dev/null; check $? "o usuario $ACCT existe"
    local lastchg min max warn inact
    lastchg=$(sh_field "$ACCT" 3); min=$(sh_field "$ACCT" 4); max=$(sh_field "$ACCT" 5); warn=$(sh_field "$ACCT" 6); inact=$(sh_field "$ACCT" 7)
    [ "$max" = "$MAXD" ]; check $? "maximo de dias entre trocas = $MAXD (atual: ${max:-nao definido})"
    [ "${min:-0}" = "$MIND" ]; check $? "minimo de dias entre trocas = $MIND (atual: ${min:-0})"
    [ "$warn" = "$WARN" ]; check $? "aviso antes de expirar = $WARN dias (atual: ${warn:-nao definido})"
    [ "$inact" = "$INACT" ]; check $? "inatividade apos expirar = $INACT dias (atual: ${inact:-nao definido})"
    if [ "$FORCE" = yes ]; then [ "$lastchg" = 0 ]; check $? "a senha deve ser trocada no proximo login (chage -d 0)"
    else [ "$lastchg" != 0 ]; check $? "a troca no proximo login NAO foi forcada (nao era pedido)"; fi
}
do_finish() { user_purge "$ACCT"; echo "limpeza: usuario $ACCT removido."; }
run "$@"

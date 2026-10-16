# Dominio 5 / networking: rota estatica persistente. Params: NAME ADDR RNET RGW
ID=dyn-net-route
do_start() { net_wipe; net_mkprof "$NAME" manual "$ADDR" yes 1 && echo "perfil $NAME ativo com $ADDR, sem rotas extras." || { echo "ERRO: nao criei o perfil"; return 1; }; }
do_grade() {
    r=$(net_prof "$NAME" ipv4.routes)
    case "$r" in "$RNET $RGW"*) true ;; *) false ;; esac
    check $? "ipv4.routes tem $RNET via $RGW (atual: ${r:-vazio})"
    ip route show dev "$NETIF" 2>/dev/null | grep -q "^$RNET via $RGW"; check $? "a rota $RNET via $RGW esta ativa agora (ip route)"
    ! ip route show default dev "$NETIF" 2>/dev/null | grep -q .; check $? "a $NETIF nao virou rota padrao"
}
do_finish() { net_wipe; echo "limpeza: perfil e interface $NETIF removidos."; }
run "$@"

# Dominio 5 / networking: enderecamento IPv6 estatico. Params: NAME ADDR ADDR6
ID=dyn-net-ipv6
do_start() { net_wipe; net_mkprof "$NAME" manual "$ADDR" yes 1 && echo "perfil $NAME ativo com $ADDR, IPv6 desligado." || { echo "ERRO: nao criei o perfil"; return 1; }; }
do_grade() {
    [ "$(net_prof "$NAME" ipv6.method)" = manual ]; check $? "ipv6.method=manual (atual: $(net_prof "$NAME" ipv6.method))"
    [ "$(net_prof "$NAME" ipv6.addresses)" = "$ADDR6" ]; check $? "ipv6.addresses=$ADDR6 (atual: $(net_prof "$NAME" ipv6.addresses))"
    [ "$(net_prof "$NAME" ipv4.addresses)" = "$ADDR" ]; check $? "o IPv4 $ADDR continua no perfil"
    ip -6 -o addr show dev "$NETIF" 2>/dev/null | grep -q "inet6 $ADDR6 "; check $? "a interface $NETIF tem $ADDR6 agora (ip -6 addr)"
}
do_finish() { net_wipe; echo "limpeza: perfil e interface $NETIF removidos."; }
run "$@"

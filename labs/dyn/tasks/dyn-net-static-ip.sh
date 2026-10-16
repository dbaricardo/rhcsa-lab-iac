# Dominio 5 / networking: IP estatico num perfil existente. Params: NAME ADDR
ID=dyn-net-static-ip
do_start() { net_wipe; net_mkprof "$NAME" auto - no 0 && echo "perfil $NAME na $NETIF (DHCP, sem autoconnect)." || { echo "ERRO: nao criei o perfil"; return 1; }; }
do_grade() {
    [ "$(net_prof "$NAME" ipv4.method)" = manual ]; check $? "ipv4.method=manual (atual: $(net_prof "$NAME" ipv4.method))"
    [ "$(net_prof "$NAME" ipv4.addresses)" = "$ADDR" ]; check $? "ipv4.addresses=$ADDR (atual: $(net_prof "$NAME" ipv4.addresses))"
    [ "$(net_prof "$NAME" connection.autoconnect)" = yes ]; check $? "connection.autoconnect=yes"
    net_is_up "$NAME"; check $? "o perfil $NAME esta ativo"
    net_has_addr "$ADDR"; check $? "a interface $NETIF tem $ADDR agora (ip addr)"
}
do_finish() { net_wipe; echo "limpeza: perfil e interface $NETIF removidos."; }
run "$@"

# Dominio 5 / networking: voltar um perfil estatico para DHCP. Params: NAME ADDR
ID=dyn-net-dhcp
do_start() { net_wipe; net_mkprof "$NAME" manual "$ADDR" no 1 && echo "perfil $NAME na $NETIF com $ADDR." || { echo "ERRO: nao criei o perfil"; return 1; }; }
do_grade() {
    [ "$(net_prof "$NAME" ipv4.method)" = auto ]; check $? "ipv4.method=auto (atual: $(net_prof "$NAME" ipv4.method))"
    [ -z "$(net_prof "$NAME" ipv4.addresses)" ]; check $? "nenhum endereco fixo no perfil (atual: $(net_prof "$NAME" ipv4.addresses))"
    [ "$(net_prof "$NAME" connection.autoconnect)" = yes ]; check $? "connection.autoconnect=yes"
}
do_finish() { net_wipe; echo "limpeza: perfil e interface $NETIF removidos."; }
run "$@"

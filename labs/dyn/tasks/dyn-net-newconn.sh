# Dominio 5 / networking: criar uma conexao nova na interface virtual. Params: NAME ADDR DNS1
ID=dyn-net-newconn
do_start() { net_wipe; echo "nenhum perfil na $NETIF."; }
do_grade() {
    nmcli -g NAME con show 2>/dev/null | grep -qxF "$NAME"; check $? "o perfil $NAME existe"
    [ "$(net_prof "$NAME" connection.interface-name)" = "$NETIF" ]; check $? "o perfil esta preso a interface $NETIF (atual: $(net_prof "$NAME" connection.interface-name))"
    [ "$(net_prof "$NAME" ipv4.method)" = manual ]; check $? "ipv4.method=manual"
    [ "$(net_prof "$NAME" ipv4.addresses)" = "$ADDR" ]; check $? "ipv4.addresses=$ADDR (atual: $(net_prof "$NAME" ipv4.addresses))"
    case "$(net_prof "$NAME" ipv4.dns)" in *"$DNS1"*) true ;; *) false ;; esac; check $? "ipv4.dns contem $DNS1"
    [ "$(net_prof "$NAME" connection.autoconnect)" = yes ]; check $? "connection.autoconnect=yes"
    net_is_up "$NAME"; check $? "o perfil $NAME esta ativo"
    net_has_addr "$ADDR"; check $? "a interface $NETIF tem $ADDR agora"
}
do_finish() { net_wipe; echo "limpeza: perfil e interface $NETIF removidos."; }
run "$@"

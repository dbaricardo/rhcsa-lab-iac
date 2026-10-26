# Dominio 5 / networking: configuracao completa de um perfil. Params: NAME ADDR DNS1 DOM RNET RGW
ID=dyn-net-full-setup
do_start() { net_wipe; echo "nenhum perfil na $NETIF."; }
do_grade() {
    nmcli -g NAME con show 2>/dev/null | grep -qxF "$NAME"; check $? "o perfil $NAME existe"
    [ "$(net_prof "$NAME" connection.interface-name)" = "$NETIF" ]; check $? "o perfil esta preso a $NETIF"
    [ "$(net_prof "$NAME" ipv4.method)" = manual ]; check $? "ipv4.method=manual"
    [ "$(net_prof "$NAME" ipv4.addresses)" = "$ADDR" ]; check $? "ipv4.addresses=$ADDR (atual: $(net_prof "$NAME" ipv4.addresses))"
    case "$(net_prof "$NAME" ipv4.dns)" in *"$DNS1"*) true ;; *) false ;; esac; check $? "ipv4.dns contem $DNS1"
    case " $(net_prof "$NAME" ipv4.dns-search | tr ',' ' ') " in *" $DOM "*) true ;; *) false ;; esac; check $? "ipv4.dns-search contem $DOM"
    case "$(net_prof "$NAME" ipv4.routes)" in "$RNET $RGW"*) true ;; *) false ;; esac; check $? "ipv4.routes tem $RNET via $RGW"
    [ "$(net_prof "$NAME" connection.autoconnect)" = yes ]; check $? "connection.autoconnect=yes"
    net_is_up "$NAME"; check $? "o perfil $NAME esta ativo"
    net_has_addr "$ADDR"; check $? "a interface $NETIF tem $ADDR agora"
    ip route show dev "$NETIF" 2>/dev/null | grep -q "^$RNET via $RGW"; check $? "a rota $RNET via $RGW esta ativa"
    ! ip route show default dev "$NETIF" 2>/dev/null | grep -q .; check $? "a $NETIF nao virou rota padrao"
}
do_finish() { net_wipe; echo "limpeza: perfil e interface $NETIF removidos."; }
run "$@"

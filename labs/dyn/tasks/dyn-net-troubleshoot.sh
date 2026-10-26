# Dominio 5 / networking: consertar um perfil quebrado. Params: NAME ADDR SCEN (badprefix|disabled|noauto|wrongif)
ID=dyn-net-troubleshoot
do_start() {
    net_wipe
    case "$SCEN" in
        badprefix) net_mkprof "$NAME" manual "${ADDR%/*}/8" yes 1 ;;
        disabled)  net_mkprof "$NAME" manual "$ADDR" yes 0 && nmcli con mod "$NAME" ipv4.method disabled ipv4.addresses "" ;;
        noauto)    net_mkprof "$NAME" manual "$ADDR" no 0 ;;
        wrongif)   net_mkprof "$NAME" manual "$ADDR" yes 0 && nmcli con mod "$NAME" connection.interface-name dyn1 ;;
    esac || { echo "ERRO: nao montei o cenario"; return 1; }
    echo "perfil $NAME quebrado ($SCEN)."
}
do_grade() {
    [ "$(net_prof "$NAME" connection.interface-name)" = "$NETIF" ]; check $? "o perfil esta preso a $NETIF (atual: $(net_prof "$NAME" connection.interface-name))"
    [ "$(net_prof "$NAME" ipv4.method)" = manual ]; check $? "ipv4.method=manual (atual: $(net_prof "$NAME" ipv4.method))"
    [ "$(net_prof "$NAME" ipv4.addresses)" = "$ADDR" ]; check $? "ipv4.addresses=$ADDR (atual: $(net_prof "$NAME" ipv4.addresses))"
    [ "$(net_prof "$NAME" connection.autoconnect)" = yes ]; check $? "connection.autoconnect=yes"
    net_is_up "$NAME"; check $? "o perfil $NAME esta ativo"
    net_has_addr "$ADDR"; check $? "a interface $NETIF tem $ADDR agora"
}
do_finish() { net_wipe; echo "limpeza: perfil e interface $NETIF removidos."; }
run "$@"

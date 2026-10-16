# Dominio 5 / networking: aplicar a mudanca de um perfil reiniciando a conexao. Params: NAME ADDR ADDR2
ID=dyn-net-restart
do_start() {
    net_wipe; net_mkprof "$NAME" manual "$ADDR" yes 1 || { echo "ERRO: nao criei o perfil"; return 1; }
    nmcli con mod "$NAME" ipv4.addresses "$ADDR2" &>/dev/null
    echo "perfil $NAME editado para $ADDR2, mas a interface ainda esta com $ADDR."
}
do_grade() {
    [ "$(net_prof "$NAME" ipv4.addresses)" = "$ADDR2" ]; check $? "o perfil continua com $ADDR2"
    net_is_up "$NAME"; check $? "o perfil $NAME esta ativo"
    net_has_addr "$ADDR2"; check $? "a interface $NETIF esta com $ADDR2 agora (conexao reiniciada)"
    ! net_has_addr "$ADDR"; check $? "o endereco antigo $ADDR saiu da interface"
}
do_finish() { net_wipe; echo "limpeza: perfil e interface $NETIF removidos."; }
run "$@"

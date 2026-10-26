# Dominio 5 / networking: dominio de busca DNS. Params: NAME ADDR DOM
ID=dyn-net-search-domain
do_start() { net_wipe; net_mkprof "$NAME" manual "$ADDR" yes 1 && echo "perfil $NAME ativo com $ADDR, sem dominio de busca." || { echo "ERRO: nao criei o perfil"; return 1; }; }
do_grade() {
    case " $(net_prof "$NAME" ipv4.dns-search | tr ',' ' ') " in *" $DOM "*) true ;; *) false ;; esac
    check $? "ipv4.dns-search contem $DOM (atual: $(net_prof "$NAME" ipv4.dns-search))"
    awk '$1 == "search" {for (i = 2; i <= NF; i++) if ($i == d) f = 1} END {exit !f}' d="$DOM" /etc/resolv.conf
    check $? "o resolv.conf tem $DOM na linha search (reative o perfil)"
}
do_finish() { net_wipe; echo "limpeza: perfil e interface $NETIF removidos."; }
run "$@"

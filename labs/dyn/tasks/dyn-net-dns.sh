# Dominio 5 / networking: servidores DNS num perfil. Params: NAME ADDR DNS1 DNS2
ID=dyn-net-dns
do_start() { net_wipe; net_mkprof "$NAME" manual "$ADDR" yes 1 && echo "perfil $NAME ativo com $ADDR, sem DNS." || { echo "ERRO: nao criei o perfil"; return 1; }; }
do_grade() {
    d=$(net_prof "$NAME" ipv4.dns)
    case "$d" in "$DNS1"*"$DNS2"*) true ;; *) false ;; esac
    check $? "ipv4.dns contem $DNS1 e $DNS2, nessa ordem (atual: ${d:-vazio})"
    n=$(awk '$1 == "nameserver" {print $2}' /etc/resolv.conf | tr '\n' ' ')
    case "$n" in *"$DNS1"*) case "$n" in *"$DNS2"*) true ;; *) false ;; esac ;; *) false ;; esac
    check $? "o resolv.conf ja usa os dois servidores (reative o perfil; atual: $n)"
}
do_finish() { net_wipe; echo "limpeza: perfil e interface $NETIF removidos."; }
run "$@"

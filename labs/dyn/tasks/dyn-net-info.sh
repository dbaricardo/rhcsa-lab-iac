# Dominio 5 / networking: salvar a informacao de rede da interface. Params: NAME ADDR OUT
ID=dyn-net-info
do_start() { net_wipe; rm -f "$OUT"; net_mkprof "$NAME" manual "$ADDR" yes 1 && echo "perfil $NAME ativo com $ADDR." || { echo "ERRO: nao criei o perfil"; return 1; }; }
do_grade() {
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    grep -qF "$NETIF" "$OUT" 2>/dev/null; check $? "o arquivo cita a interface $NETIF"
    grep -qF "${ADDR%/*}" "$OUT" 2>/dev/null; check $? "o arquivo traz o endereco ${ADDR%/*}"
}
do_finish() { net_wipe; rm -f "$OUT"; echo "limpeza: perfil, interface e $OUT removidos."; }
run "$@"

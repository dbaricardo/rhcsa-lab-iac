# Dominio 7 / selinux: booleano persistente. Params: BOOL VALUE
ID=dyn-selinux-bool
# "bool (atual , padrao) descricao" -> "atual padrao"
bool_state() {
    semanage boolean -l 2>/dev/null | awk -v b="$1" '$1==b' \
        | sed -E 's/^[^(]*\(\s*([a-z]+)\s*,\s*([a-z]+)\s*\).*/\1 \2/'
}
do_start() {
    getsebool "$BOOL" &>/dev/null || { echo "ERRO: booleano $BOOL nao existe neste host"; exit 1; }
    [ -e "$ST/$ID.orig" ] || bool_state "$BOOL" | awk '{print $2}' > "$ST/$ID.orig"
    opp=on; [ "$VALUE" = on ] && opp=off
    setsebool -P "$BOOL" "$opp" || { echo "ERRO: setsebool -P $BOOL $opp falhou"; exit 1; }
    echo "$BOOL em $opp (atual e persistente); a questao pede $VALUE."
}
do_grade() {
    set -- $(bool_state "$BOOL")
    [ "${1:-}" = "$VALUE" ]; check $? "$BOOL esta $VALUE agora (atual: ${1:-?})"
    [ "${2:-}" = "$VALUE" ]; check $? "$BOOL esta $VALUE de forma persistente, setsebool -P (padrao: ${2:-?})"
}
do_finish() {
    if [ -s "$ST/$ID.orig" ]; then
        setsebool -P "$BOOL" "$(cat "$ST/$ID.orig")"
        echo "limpeza: $BOOL restaurado para $(cat "$ST/$ID.orig")."
    fi
    rm -f "$ST/$ID.orig"
}
run "$@"

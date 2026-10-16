# Dominio 7 / selinux: diagnostico de servico (contexto, booleano e/ou porta). Params: DIR TYPE BOOL PORT PTYPE (vazio = nao se aplica)
ID=dyn-selinux-service-diag
bool_default() { semanage boolean -l | awk -v b="$1" '$1==b' | sed -E 's/^[^(]*\(\s*[a-z]+\s*,\s*([a-z]+)\s*\).*/\1/'; }
port_has() { semanage port -l 2>/dev/null | awk -v t="$PTYPE" -v p="$PORT" '$1==t && $2=="tcp" {n=split($0,a,/[ ,\t]+/); for(i=3;i<=n;i++) if (a[i]==p) f=1} END{exit !f}'; }
port_clear() {
    semanage port -l -C 2>/dev/null | awk -v p="$PORT" '$2=="tcp" {n=split($0,a,/[ ,\t]+/); for(i=3;i<=n;i++) if (a[i]==p) {print $1; break}}' \
        | while read -r t; do semanage port -d -t "$t" -p tcp "$PORT" &>/dev/null; done
}
do_start() {
    if [ -n "$DIR" ]; then fcontext_clear "$DIR"; safe_rm "$DIR"; tree_mk "$DIR" tmp_t; fi
    if [ -n "$BOOL" ]; then
        [ -e "$ST/$ID.orig" ] || bool_default "$BOOL" > "$ST/$ID.orig"
        setsebool -P "$BOOL" off
    fi
    if [ -n "$PORT" ]; then
        port_clear
        port_has && { echo "ERRO: $PORT/tcp ja e $PTYPE pela politica; rode o lab start de novo"; exit 1; }
    fi
    echo "falhas de SELinux preparadas."
}
do_grade() {
    if [ -n "$DIR" ]; then
        tree_type_ok "$DIR" "$TYPE"; check $? "$DIR e o conteudo tem o tipo $TYPE (atual: $(ctx_type "$DIR"))"
        [ "$(pol_type "$DIR")" = "$TYPE" ]; check $? "a politica define $TYPE para $DIR (correcao persistente)"
    fi
    if [ -n "$BOOL" ]; then
        [ "$(getsebool "$BOOL" | awk '{print $3}')" = on ]; check $? "o booleano $BOOL esta ligado agora"
        [ "$(bool_default "$BOOL")" = on ]; check $? "o booleano $BOOL esta ligado de forma persistente (setsebool -P)"
    fi
    if [ -n "$PORT" ]; then
        port_has; check $? "a porta $PORT/tcp esta no tipo $PTYPE"
        semanage port -l -C 2>/dev/null | awk -v p="$PORT" 'index($0, p) {f=1} END{exit !f}'; check $? "a associacao da porta e persistente (semanage port -l -C)"
    fi
}
do_finish() {
    [ -n "$DIR" ] && { fcontext_clear "$DIR"; tree_rm "$DIR"; }
    if [ -n "$BOOL" ] && [ -s "$ST/$ID.orig" ]; then setsebool -P "$BOOL" "$(cat "$ST/$ID.orig")"; rm -f "${ST:?}/${ID:?}.orig"; fi
    [ -n "$PORT" ] && port_clear
    echo "limpeza: contexto, booleano e porta restaurados."
}
run "$@"

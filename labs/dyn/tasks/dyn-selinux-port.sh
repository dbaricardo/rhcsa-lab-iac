# Dominio 7 / selinux: contexto de porta. Params: PORT PROTO TYPE
ID=dyn-selinux-port
# Remove as personalizacoes locais (semanage -C) dessa porta/protocolo.
limpa_local() {
    semanage port -l -C 2>/dev/null | awk -v pr="$PROTO" -v p="$PORT" '$2==pr {
        n=split($0,a,/[ ,\t]+/); for (i=3;i<=n;i++) if (a[i]==p) {print $1; break}}' \
    | while read -r tipo; do semanage port -d -t "$tipo" -p "$PROTO" "$PORT" &>/dev/null; done
}
atribuida() {  # a porta ja tem o tipo $TYPE?
    semanage port -l 2>/dev/null | awk -v t="$TYPE" -v pr="$PROTO" -v p="$PORT" '$1==t && $2==pr {
        n=split($0,a,/[ ,\t]+/); for (i=3;i<=n;i++) if (a[i]==p) f=1} END{exit !f}'
}
do_start() {
    limpa_local
    if atribuida; then echo "ERRO: $PORT/$PROTO ja tem $TYPE pela politica; escolha outra porta"; exit 1; fi
    echo "porta $PORT/$PROTO sem o tipo $TYPE."
}
do_grade() {
    atribuida; check $? "porta $PORT/$PROTO associada ao tipo $TYPE no SELinux"
    semanage port -l -C 2>/dev/null | awk -v t="$TYPE" -v pr="$PROTO" -v p="$PORT" '$1==t && $2==pr {
        n=split($0,a,/[ ,\t]+/); for (i=3;i<=n;i++) if (a[i]==p) f=1} END{exit !f}'
    check $? "a associacao e persistente (aparece em semanage port -l -C)"
}
do_finish() {
    limpa_local
    echo "limpeza: personalizacao SELinux da porta $PORT/$PROTO removida."
}
run "$@"

# Dominio 1 / packages: informacoes de um pacote em arquivo. Params: PKG OUT
ID=dyn-pkg-query
do_start() { rm -f "$OUT"; echo "arquivo $OUT inexistente."; }
do_grade() {
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    grep -Eq "^Name[[:space:]]*:[[:space:]]*$PKG[[:space:]]*$" "$OUT" 2>/dev/null
    check $? "o arquivo traz a linha Name: $PKG (rpm -qi ou dnf info)"
    ver=$(rpm -q --qf '%{VERSION}' "$PKG" 2>/dev/null)
    [ -n "$ver" ] && grep -q "$ver" "$OUT" 2>/dev/null
    check $? "o arquivo traz a versao instalada ($ver)"
}
do_finish() { rm -f "$OUT"; echo "limpeza: $OUT removido."; }
run "$@"

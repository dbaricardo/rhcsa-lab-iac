# Dominio 5 / networking: testar a conectividade e guardar o resultado. Params: TARGET COUNT OUT
ID=dyn-net-verify
do_start() { rm -f "$OUT"; echo "arquivo $OUT inexistente."; }
do_grade() {
    [ -s "$OUT" ]; check $? "o arquivo $OUT existe e nao esta vazio"
    grep -Eq "^$COUNT packets transmitted" "$OUT" 2>/dev/null; check $? "o teste enviou exatamente $COUNT pacotes"
    grep -Eq "bytes from $TARGET" "$OUT" 2>/dev/null; check $? "o arquivo tem respostas de $TARGET"
    grep -Eq "[[:space:]]0% packet loss" "$OUT" 2>/dev/null; check $? "o arquivo mostra 0% de perda"
}
do_finish() { rm -f "$OUT"; echo "limpeza: $OUT removido."; }
run "$@"

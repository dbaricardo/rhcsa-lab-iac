# Dominio 7 / selinux: analisar uma negacao e corrigir o tipo do diretorio. Params: DIR TYPE
ID=dyn-selinux-avc
do_start() {
    fcontext_clear "$DIR"; safe_rm "$DIR"
    tree_mk "$DIR" tmp_t
    echo "$DIR existe com o tipo errado (tmp_t)."
}
do_grade() {
    [ -d "$DIR" ]; check $? "o diretorio $DIR existe"
    tree_type_ok "$DIR" "$TYPE"; check $? "o diretorio e o conteudo tem o tipo $TYPE (atual: $(ctx_type "$DIR"))"
    [ "$(pol_type "$DIR")" = "$TYPE" ]; check $? "a politica define $TYPE para $DIR: a correcao e persistente (atual na politica: $(pol_type "$DIR"))"
}
do_finish() {
    fcontext_clear "$DIR"; tree_rm "$DIR"
    echo "limpeza: $DIR e as regras de fcontext removidos."
}
run "$@"

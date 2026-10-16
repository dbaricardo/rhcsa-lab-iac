# Dominio 7 / selinux: restorecon recursivo. Params: DIR TYPE
ID=dyn-selinux-restorecon
do_start() {
    safe_rm "$DIR"
    tree_mk "$DIR" user_home_t
    echo "$DIR existe com o tipo errado (user_home_t), como se os arquivos tivessem sido movidos com mv."
}
do_grade() {
    [ -d "$DIR" ]; check $? "o diretorio $DIR existe"
    tree_type_ok "$DIR" "$TYPE"; check $? "o diretorio e todo o conteudo tem o tipo $TYPE (atual: $(ctx_type "$DIR"))"
    [ "$(pol_type "$DIR")" = "$TYPE" ]; check $? "o contexto restaurado e o que a politica define para $DIR"
}
do_finish() {
    tree_rm "$DIR"
    echo "limpeza: $DIR removido."
}
run "$@"

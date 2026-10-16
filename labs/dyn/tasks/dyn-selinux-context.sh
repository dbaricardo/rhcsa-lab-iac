# Dominio 7 / selinux: fcontext persistente + restorecon num diretorio. Params: DIR TYPE
ID=dyn-selinux-context
do_start() {
    fcontext_clear "$DIR"; safe_rm "$DIR"
    mkdir -p "$DIR"; echo a > "$DIR/index.html"; echo b > "$DIR/dados.txt"; restorecon -R "$DIR"
    echo "$DIR existe com 2 arquivos e o tipo padrao ($(ctx_type "$DIR"))."
}
do_grade() {
    [ -d "$DIR" ]; check $? "o diretorio $DIR existe"
    tree_type_ok "$DIR" "$TYPE"; check $? "o diretorio e todos os arquivos dentro dele tem o tipo $TYPE (atual: $(ctx_type "$DIR"))"
    semanage fcontext -l -C 2>/dev/null | awk -v d="$DIR" -v t="$TYPE" 'index($1, d)==1 && index($0, t) {f=1} END{exit !f}'
    check $? "ha uma regra persistente (semanage fcontext) de $DIR para $TYPE"
}
do_finish() { fcontext_clear "$DIR"; safe_rm "$DIR"; echo "limpeza: $DIR e as regras de fcontext removidos."; }
run "$@"

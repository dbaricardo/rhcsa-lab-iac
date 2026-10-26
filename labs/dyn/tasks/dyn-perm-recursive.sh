# Dominio 3 / permissions: dono, grupo e modos recursivos. Params: DIR OWNER GRP DIRPERMS FILEPERMS
ID=dyn-perm-recursive
do_start() {
    rm -f "${ST:?}/${ID:?}.groups"
    safe_rm "$DIR"
    grp_mk "$GRP"
    mkdir -p "$DIR/docs/sub" "$DIR/bin"
    echo a > "$DIR/a.txt"; echo b > "$DIR/docs/b.txt"; echo c > "$DIR/docs/sub/c.txt"; echo d > "$DIR/bin/d.sh"
    chown -R bin:bin "$DIR"; chmod -R 777 "$DIR"
    echo "$DIR existe com 3 niveis, dono bin:bin e modo 777."
}
do_grade() {
    [ -d "$DIR" ]; check $? "o diretorio $DIR existe"
    local n
    n=$(find "$DIR" \( ! -user "$OWNER" -o ! -group "$GRP" \) 2>/dev/null | wc -l)
    [ -d "$DIR" ] && [ "$n" -eq 0 ]; check $? "tudo em $DIR e de $OWNER:$GRP ($n itens com dono/grupo diferente)"
    n=$(find "$DIR" -type d ! -perm "$DIRPERMS" 2>/dev/null | wc -l)
    [ -d "$DIR" ] && [ "$n" -eq 0 ]; check $? "todos os diretorios tem modo $DIRPERMS ($n diferentes)"
    n=$(find "$DIR" -type f ! -perm "$FILEPERMS" 2>/dev/null | wc -l)
    [ -d "$DIR" ] && [ "$n" -eq 0 ]; check $? "todos os arquivos tem modo $FILEPERMS ($n diferentes)"
}
do_finish() { safe_rm "$DIR"; rmdir /var/data 2>/dev/null; grp_purge; echo "limpeza: $DIR removido."; }
run "$@"

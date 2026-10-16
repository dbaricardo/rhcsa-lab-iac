# Dominio 3 / permissions: diretorio colaborativo SGID+sticky. Params: DIR GRP
ID=dyn-perm-shared-dir
do_start() {
    rm -f "${ST:?}/${ID:?}.groups"
    safe_rm "$DIR"
    grp_mk "$GRP"
    echo "o grupo $GRP existe e $DIR nao existe."
}
do_grade() {
    [ -d "$DIR" ]; check $? "o diretorio $DIR existe"
    [ "$(stat -c %G "$DIR" 2>/dev/null)" = "$GRP" ]; check $? "o grupo de $DIR e $GRP (atual: $(stat -c %G "$DIR" 2>/dev/null))"
    local m; m=$(stat -c %a "$DIR" 2>/dev/null)
    [ -n "$m" ] && [ $(( 0$m & 02000 )) -ne 0 ]; check $? "o SGID esta ligado (novos arquivos herdam o grupo; modo $m)"
    [ -n "$m" ] && [ $(( 0$m & 01000 )) -ne 0 ]; check $? "o sticky bit esta ligado (cada um so apaga o que e seu; modo $m)"
    [ -n "$m" ] && [ $(( 0$m & 070 )) -eq 56 ] && [ $(( 0$m & 07 )) -eq 0 ]; check $? "o grupo tem rwx e os outros nao tem acesso (modo $m)"
}
do_finish() { safe_rm "$DIR"; rmdir /shared 2>/dev/null; grp_purge; echo "limpeza: $DIR removido."; }
run "$@"

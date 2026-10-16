# Dominio 3 / permissions: ACL padrao (heranca) num diretorio. Params: DIR ACCT ACLPERMS
ID=dyn-acl-default
do_start() {
    safe_rm "$DIR"
    user_mk "$ACCT" -m || exit 1
    echo "o usuario $ACCT existe e $DIR nao existe."
}
do_grade() {
    [ -d "$DIR" ]; check $? "o diretorio $DIR existe"
    getfacl -p "$DIR" 2>/dev/null | grep -qx "default:user:$ACCT:$ACLPERMS"
    check $? "ACL padrao default:user:$ACCT:$ACLPERMS configurada (getfacl: $(getfacl -p "$DIR" 2>/dev/null | grep "^default:user:$ACCT:" | head -1))"
    if [ -d "$DIR" ]; then
        touch "$DIR/.dyn-heranca" 2>/dev/null
        getfacl -p "$DIR/.dyn-heranca" 2>/dev/null | grep -q "^user:$ACCT:"
        check $? "um arquivo novo dentro de $DIR herda a ACL de $ACCT"
        rm -f "$DIR/.dyn-heranca"
    else check 1 "um arquivo novo dentro de $DIR herda a ACL de $ACCT"; fi
}
do_finish() { safe_rm "$DIR"; user_purge "$ACCT"; echo "limpeza: $DIR e usuario $ACCT removidos."; }
run "$@"

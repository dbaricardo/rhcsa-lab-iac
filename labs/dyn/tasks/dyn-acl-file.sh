# Dominio 3 / permissions: ACL de usuario num arquivo. Params: FILE ACCT ACLPERMS
ID=dyn-acl-file
do_start() {
    mkdir -p "$(dirname "$FILE")"; echo dados > "$FILE"; chmod 640 "$FILE"; setfacl -b "$FILE"
    echo "$FILE existe sem ACL."
}
do_grade() {
    [ -f "$FILE" ]; check $? "o arquivo $FILE existe"
    getfacl -p "$FILE" 2>/dev/null | grep -qx "user:$ACCT:$ACLPERMS"
    check $? "ACL user:$ACCT:$ACLPERMS configurada (getfacl: $(getfacl -p "$FILE" 2>/dev/null | grep "^user:$ACCT:" | head -1))"
}
do_finish() { safe_rm "$FILE"; echo "limpeza: $FILE removido."; }
run "$@"

# Dominio 3 / permissions: chmod num arquivo. Params: FILE PERMS
ID=dyn-perm-basic
do_start() {
    mkdir -p "$(dirname "$FILE")"; echo dados > "$FILE"; chown root:root "$FILE"
    [ "$PERMS" = 664 ] && chmod 600 "$FILE" || chmod 664 "$FILE"
    echo "$FILE existe com modo $(stat -c %a "$FILE")."
}
do_grade() {
    [ -f "$FILE" ]; check $? "o arquivo $FILE existe"
    [ "$(stat -c %a "$FILE" 2>/dev/null)" = "$PERMS" ]; check $? "as permissoes de $FILE sao $PERMS (atual: $(stat -c %a "$FILE" 2>/dev/null))"
}
do_finish() { safe_rm "$FILE"; echo "limpeza: $FILE removido."; }
run "$@"

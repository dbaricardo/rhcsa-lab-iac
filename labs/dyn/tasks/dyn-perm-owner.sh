# Dominio 3 / permissions: chown/chgrp num arquivo. Params: FILE OWNER GROUP
ID=dyn-perm-owner
do_start() {
    mkdir -p "$(dirname "$FILE")"; echo dados > "$FILE"
    chown bin:bin "$FILE"
    echo "$FILE existe, dono bin:bin."
}
do_grade() {
    [ -f "$FILE" ]; check $? "o arquivo $FILE existe"
    [ "$(stat -c %U "$FILE" 2>/dev/null)" = "$OWNER" ]; check $? "o dono e $OWNER (atual: $(stat -c %U "$FILE" 2>/dev/null))"
    [ "$(stat -c %G "$FILE" 2>/dev/null)" = "$GROUP" ]; check $? "o grupo e $GROUP (atual: $(stat -c %G "$FILE" 2>/dev/null))"
}
do_finish() { safe_rm "$FILE"; echo "limpeza: $FILE removido."; }
run "$@"

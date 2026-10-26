# Dominio 3 / permissions: setuid, setgid ou sticky. Params: FILE KIND(setuid|setgid|sticky) MODE
ID=dyn-perm-special
do_start() {
    if [ "$KIND" = sticky ]; then mkdir -p "$FILE"; chmod 777 "$FILE"
    else mkdir -p "$(dirname "$FILE")"; printf '#!/bin/sh\necho ok\n' > "$FILE"; chmod 755 "$FILE"; fi
    echo "$FILE existe com modo $(stat -c %a "$FILE") (sem bit especial)."
}
do_grade() {
    [ -e "$FILE" ]; check $? "$FILE existe"
    [ "$(stat -c %a "$FILE" 2>/dev/null)" = "$MODE" ]; check $? "o modo de $FILE e $MODE (atual: $(stat -c %a "$FILE" 2>/dev/null))"
}
do_finish() { safe_rm "$FILE"; echo "limpeza: $FILE removido."; }
run "$@"

# Dominio 3 / users_groups: varios usuarios num grupo. Params: GRP USERS ("nome:uid:shell ...")
ID=dyn-bulk-users
do_start() {
    local spec n u
    rm -f "${ST:?}/${ID:?}.groups"
    getent group "$GRP" &>/dev/null && { echo "ERRO: o grupo $GRP ja existe; rode o lab start de novo"; exit 1; }
    for spec in $USERS; do
        n=${spec%%:*}; u=$(echo "$spec" | cut -d: -f2)
        user_purge "$n"
        getent passwd "$u" >/dev/null && { echo "ERRO: o UID $u ja esta em uso; rode o lab start de novo"; exit 1; }
    done
    echo "o grupo $GRP e os usuarios pedidos nao existem."
}
do_grade() {
    local spec n u sh
    getent group "$GRP" &>/dev/null; check $? "o grupo $GRP existe"
    for spec in $USERS; do
        n=${spec%%:*}; u=$(echo "$spec" | cut -d: -f2); sh=${spec##*:}
        id "$n" &>/dev/null; check $? "o usuario $n existe"
        [ "$(id -u "$n" 2>/dev/null)" = "$u" ]; check $? "$n tem UID $u (atual: $(id -u "$n" 2>/dev/null))"
        [ "$(pw_field "$n" 7)" = "$sh" ]; check $? "$n tem shell $sh (atual: $(pw_field "$n" 7))"
        id -nG "$n" 2>/dev/null | tr ' ' '\n' | grep -qxF "$GRP"; check $? "$n e membro suplementar de $GRP"
        [ -d "/home/$n" ]; check $? "$n tem home em /home/$n"
    done
}
do_finish() {
    local spec
    for spec in $USERS; do user_purge "${spec%%:*}"; done
    getent group "$GRP" &>/dev/null && groupdel "$GRP"
    echo "limpeza: usuarios e grupo $GRP removidos."
}
run "$@"

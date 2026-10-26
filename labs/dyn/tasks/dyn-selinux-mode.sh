# Dominio 7 / selinux: modo enforcing/permissive, em runtime e persistente. Params: MODE(Enforcing|Permissive)
ID=dyn-selinux-mode
CFG=/etc/selinux/config
do_start() {
    conf_save "$CFG" "$ID.cfg"
    [ -e "$ST/$ID.mode" ] || getenforce > "$ST/$ID.mode"
    if [ "$MODE" = Enforcing ]; then
        setenforce 0; sed -i -E 's/^SELINUX=.*/SELINUX=permissive/' "$CFG"
    fi
    echo "modo atual: $(getenforce); config: $(grep -E '^SELINUX=' "$CFG")."
}
do_grade() {
    [ "$(getenforce)" = "$MODE" ]; check $? "o modo atual do SELinux e $MODE (atual: $(getenforce))"
    local want; want=$(echo "$MODE" | tr 'A-Z' 'a-z')
    [ "$(sed -n -E 's/^SELINUX=([a-z]+).*/\1/p' "$CFG" | head -1)" = "$want" ]
    check $? "o /etc/selinux/config tem SELINUX=$want (persistente)"
}
do_finish() {
    conf_restore "$CFG" "$ID.cfg"
    [ "$(cat "$ST/$ID.mode" 2>/dev/null)" = Enforcing ] && setenforce 1 || setenforce 0
    rm -f "${ST:?}/${ID:?}.mode"
    echo "limpeza: SELinux voltou para $(getenforce) e o config foi restaurado."
}
run "$@"

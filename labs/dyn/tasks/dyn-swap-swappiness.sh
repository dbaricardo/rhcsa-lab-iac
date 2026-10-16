# Dominio 4 / swap: vm.swappiness persistente (sem disco). Params: SWAPPINESS
ID=dyn-swap-swappiness
do_start() {
    [ -e "$ST/$ID.orig" ] || sysctl -n vm.swappiness > "$ST/$ID.orig"
    conf_save /etc/sysctl.conf "$ID.sysctlconf"
    [ -e "$ST/$ID.list" ] || { ls -1 /etc/sysctl.d 2>/dev/null; true; } > "$ST/$ID.list"
    other=$((SWAPPINESS == 90 ? 91 : 90))
    sysctl -w vm.swappiness=$other &>/dev/null
    echo "vm.swappiness em $other agora; a questao pede $SWAPPINESS (agora e persistente)."
}
do_grade() {
    atual=$(sysctl -n vm.swappiness 2>/dev/null)
    [ "$atual" = "$SWAPPINESS" ]; check $? "vm.swappiness vale $SWAPPINESS agora (atual: ${atual:-?})"
    grep -rEqs "^[[:space:]]*vm\.swappiness[[:space:]]*=[[:space:]]*$SWAPPINESS[[:space:]]*$" /etc/sysctl.conf /etc/sysctl.d/
    check $? "vm.swappiness=$SWAPPINESS esta em /etc/sysctl.conf ou /etc/sysctl.d/ (persistente)"
}
do_finish() {
    local f
    for f in /etc/sysctl.d/*; do
        [ -e "$f" ] || continue
        grep -qxF "${f##*/}" "$ST/$ID.list" 2>/dev/null || rm -f "$f"
    done
    conf_restore /etc/sysctl.conf "$ID.sysctlconf"
    [ -s "$ST/$ID.orig" ] && sysctl -w vm.swappiness="$(cat "$ST/$ID.orig")" &>/dev/null
    rm -f "${ST:?}/${ID:?}.orig" "${ST:?}/${ID:?}.list"
    echo "limpeza: vm.swappiness e arquivos de sysctl restaurados."
}
run "$@"

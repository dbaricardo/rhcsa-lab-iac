# Dominio 3 / users_groups: sudo por drop-in. Params: ACCT NOPASSWD(yes|no) CMDS
ID=dyn-sudo
SUDOERS=/etc/sudoers
do_start() {
    conf_save "$SUDOERS" "$ID.sudoers"
    { ls -1 /etc/sudoers.d 2>/dev/null; true; } > "$ST/$ID.list"
    user_mk "$ACCT" -m || exit 1
    echo "o usuario $ACCT existe e nao tem regra de sudo."
}
do_grade() {
    id "$ACCT" &>/dev/null; check $? "o usuario $ACCT existe"
    local regras
    regras=$(sudo -l -U "$ACCT" 2>/dev/null)
    local ok=1 c
    if [ "$CMDS" = ALL ]; then
        echo "$regras" | grep -Eq '\(ALL( : ALL)?\)[[:space:]]+(NOPASSWD:[[:space:]]+)?ALL' && ok=0
    else
        ok=0; for c in $(echo "$CMDS" | tr ',' ' '); do echo "$regras" | grep -qF "$c" || ok=1; done
    fi
    check $ok "$ACCT pode rodar $CMDS como root (sudo -l -U)"
    if [ "$NOPASSWD" = yes ]; then echo "$regras" | grep -q 'NOPASSWD:'; else ! echo "$regras" | grep -q 'NOPASSWD:'; fi
    check $? "a regra $( [ "$NOPASSWD" = yes ] && echo 'e NOPASSWD' || echo 'exige senha (sem NOPASSWD)')"
    grep -rqsE "^[[:space:]]*$ACCT[[:space:]]" /etc/sudoers.d/; check $? "a regra esta num arquivo de /etc/sudoers.d/ (drop-in)"
    visudo -c &>/dev/null; check $? "a sintaxe do sudoers e valida (visudo -c)"
}
do_finish() {
    local f
    for f in /etc/sudoers.d/*; do
        [ -e "$f" ] || continue
        grep -qxF "${f##*/}" "$ST/$ID.list" 2>/dev/null || rm -f -- "$f"
    done
    conf_restore "$SUDOERS" "$ID.sudoers"
    user_purge "$ACCT"
    rm -f "${ST:?}/${ID:?}.list"
    echo "limpeza: regras de sudo e usuario $ACCT removidos."
}
run "$@"

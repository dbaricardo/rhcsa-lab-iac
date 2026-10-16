# Dominio 2 / boot: entrada quebrada no fstab. Params: MP DEV FS
ID=dyn-fstab-fix
do_start() {
    fstab_drop "$MP" "$DEV"
    mkdir -p "$MP"
    printf '%s %s %s defaults 0 0\n' "$DEV" "$MP" "$FS" >> /etc/fstab
    systemctl daemon-reload
    echo "fstab com a entrada quebrada: $DEV em $MP."
}
do_grade() {
    line=$(fstab_entry "$MP")
    if [ -z "$line" ]; then ok=0; msg="a entrada de $MP foi removida ou comentada"
    elif fstab_has_nofail "$MP"; then ok=0; msg="a entrada de $MP continua, com nofail"
    else ok=1; msg="a entrada de $MP continua sem nofail: $line"; fi
    check $ok "$msg"
    findmnt --verify 2>&1 | grep -F "$MP" | grep -q '\[E\]'; [ $? -ne 0 ]; check $? "o findmnt --verify nao acusa erro para $MP"
}
do_finish() {
    fstab_drop "$MP" "$DEV"
    umount "$MP" &>/dev/null; rmdir "$MP" 2>/dev/null
    echo "limpeza: entradas de $MP removidas do fstab."
}
run "$@"

# Dominio 2 / boot: duas entradas ruins no fstab. Params: MP1 UUID1 MP2 DEV2
ID=dyn-fstab-validate
do_start() {
    fstab_drop "$MP1" "$UUID1"; fstab_drop "$MP2" "$DEV2"
    mkdir -p "$MP1" "$MP2"
    printf 'UUID=%s %s xfs defaults 0 0\n%s %s ext4 defaults 0 0\n' "$UUID1" "$MP1" "$DEV2" "$MP2" >> /etc/fstab
    systemctl daemon-reload
    echo "fstab com duas entradas ruins ($MP1 e $MP2)."
}
do_grade() {
    [ -z "$(fstab_entry "$MP1")" ]; check $? "a entrada de $MP1 (UUID inexistente) foi removida ou comentada"
    [ -n "$(fstab_entry "$MP2")" ]; check $? "a entrada de $MP2 foi mantida"
    fstab_has_nofail "$MP2"; check $? "a entrada de $MP2 tem a opcao nofail"
    findmnt --verify 2>&1 | grep -E "$MP1|$MP2" | grep -q '\[E\]'; [ $? -ne 0 ]; check $? "o findmnt --verify nao acusa erro nas duas entradas"
}
do_finish() {
    fstab_drop "$MP1" "$UUID1"; fstab_drop "$MP2" "$DEV2"
    rmdir "$MP1" "$MP2" 2>/dev/null
    echo "limpeza: entradas removidas do fstab."
}
run "$@"

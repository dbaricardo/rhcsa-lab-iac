# Dominio 2 / boot: refazer o initramfs do kernel em uso. Sem params
ID=dyn-initramfs-rebuild
IMG=/boot/initramfs-$(uname -r).img
do_start() {
    [ -e "$ST/$ID.img" ] || cp -p "$IMG" "$ST/$ID.img"
    date +%s > "$ST/$ID.stamp"
    echo "initramfs de $(uname -r) guardado; o aluno deve refaze-lo."
}
do_grade() {
    start=$(cat "$ST/$ID.stamp" 2>/dev/null || echo 0)
    mt=$(stat -c %Y "$IMG" 2>/dev/null || echo 0)
    [ "$mt" -gt "$start" ]; check $? "o initramfs $IMG foi regenerado depois do inicio da prova"
    [ "$(stat -c %s "$IMG" 2>/dev/null || echo 0)" -gt 1048576 ]; check $? "o initramfs tem tamanho valido"
    lsinitrd "$IMG" 2>/dev/null | head -2 | grep -q .; check $? "o initramfs e legivel (lsinitrd)"
}
do_finish() {
    [ -s "$ST/$ID.img" ] && cp -p "$ST/$ID.img" "$IMG" && restorecon "$IMG" 2>/dev/null
    rm -f "$ST/$ID.img" "$ST/$ID.stamp"
    echo "limpeza: initramfs original restaurado."
}
run "$@"

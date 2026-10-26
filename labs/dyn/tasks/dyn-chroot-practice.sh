# Dominio 2 / boot: ambiente de chroot com bind mounts. Params: CHROOT MOUNTS (separados por virgula)
ID=dyn-chroot-practice
IFS=, read -ra MLIST <<< "$MOUNTS"
unmount_all() {
    local m
    # do mais fundo para o mais raso; nada alem de umount e' feito dentro de $CHROOT
    for m in $(findmnt -rno TARGET | grep "^$CHROOT/" | sort -r); do umount "$m" 2>/dev/null || umount -l "$m"; done
}
do_start() {
    unmount_all
    echo "diretorio $CHROOT livre (sem mounts)."
}
do_grade() {
    [ -d "$CHROOT" ]; check $? "o diretorio $CHROOT existe"
    for m in "${MLIST[@]}"; do
        [ -d "$CHROOT/$m" ]; check $? "o subdiretorio $CHROOT/$m existe"
        findmnt -rn "$CHROOT/$m" &>/dev/null; check $? "$CHROOT/$m e um ponto de montagem ativo"
        src=$(findmnt -rno SOURCE "$CHROOT/$m" 2>/dev/null | head -1)
        case "$m" in proc) want=proc ;; sys) want=sysfs ;; dev) want=devtmpfs ;; dev/pts) want=devpts ;; run) want=tmpfs ;; esac
        fs=$(findmnt -rno FSTYPE "$CHROOT/$m" 2>/dev/null | head -1)
        [ "$fs" = "$want" ]; check $? "$CHROOT/$m e um bind de /$m (tipo $want; atual: ${fs:-nada})"
    done
}
do_finish() {
    unmount_all
    if findmnt -rn "$CHROOT" &>/dev/null || findmnt -rno TARGET | grep -q "^$CHROOT/"; then
        echo "AVISO: ainda ha mounts em $CHROOT; nada foi apagado."
        return 0
    fi
    for m in "${MLIST[@]}" dev/pts dev sys proc run; do rmdir "$CHROOT/$m" 2>/dev/null; done
    rmdir "$CHROOT" 2>/dev/null
    echo "limpeza: mounts desfeitos e diretorios vazios de $CHROOT removidos."
}
run "$@"

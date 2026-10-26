# Dominio 4 / partitioning: particao + mkfs + mount + fstab UUID. Params: DSIZE FSTYPE SIZE MOUNT
ID=dyn-part-format-mount
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MOUNT" 2>/dev/null
    echo "disco $D limpo, sem tabela de particoes."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    P=$(disk_part "$D" 1)
    [ -b "$P" ]; check $? "a particao $P existe"
    mb=$(( $(blockdev --getsize64 "$P" 2>/dev/null || echo 0) / 1048576 ))
    [ "$mb" -ge $((SIZE * 85 / 100)) ] && [ "$mb" -le $((SIZE * 115 / 100)) ]
    check $? "a particao tem ~$SIZE MiB (atual: $mb MiB)"
    tipo=$(blkid -s TYPE -o value "$P" 2>/dev/null)
    [ "$tipo" = "$FSTYPE" ]; check $? "o filesystem e $FSTYPE (atual: ${tipo:-nenhum})"
    findmnt -nro TARGET -S "$P" | grep -qxF "$MOUNT"; check $? "$P esta montada em $MOUNT"
    u=$(dev_uuid "$P"); linha=$(fstab_line "$MOUNT")
    [ -n "$u" ] && case "$linha" in "UUID=$u "*) true ;; *) false ;; esac
    check $? "o /etc/fstab tem a entrada de $MOUNT identificada por UUID"
    [ -d "$MOUNT" ]; check $? "o ponto de montagem $MOUNT existe"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MOUNT" 2>/dev/null
    echo "limpeza: disco $D zerado."
}
run "$@"

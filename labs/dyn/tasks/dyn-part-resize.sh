# Dominio 4 / partitioning: crescer particao + fs ext4. Params: DSIZE NEWSIZE
ID=dyn-part-resize
MP=/mnt/dynresize
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    disk_gpt "$D" 201 || exit 1
    P=$(disk_part "$D" 1); wait_dev "$P" || { echo "ERRO: $P nao apareceu"; exit 1; }
    mkfs.ext4 -q -F "$P" || exit 1
    mkdir -p "$MP"; mount "$P" "$MP" || exit 1
    echo dados-dyn > "$MP/dyn-marker.txt"
    echo "$P (ext4, 200 MiB) montada em $MP com dados; ha espaco livre depois dela."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    P=$(disk_part "$D" 1)
    [ -b "$P" ]; check $? "a particao $P existe"
    mb=$(( $(blockdev --getsize64 "$P" 2>/dev/null || echo 0) / 1048576 ))
    [ "$mb" -ge $((NEWSIZE * 90 / 100)) ]; check $? "a particao cresceu para ~$NEWSIZE MiB (atual: $mb MiB)"
    tipo=$(blkid -s TYPE -o value "$P" 2>/dev/null)
    [ "$tipo" = ext4 ]; check $? "o filesystem ext4 continua na particao (atual: ${tipo:-nenhum})"
    fsmb=$(dumpe2fs -h "$P" 2>/dev/null | awk -F: '/^Block count/{c=$2} /^Block size/{b=$2} END{printf "%d", c*b/1048576}')
    [ "${fsmb:-0}" -ge $((NEWSIZE * 90 / 100)) ]; check $? "o filesystem acompanhou a particao (~${fsmb:-0} MiB, esperado ~$NEWSIZE MiB)"
    alvo=$(findmnt -nro TARGET -S "$P" | head -1)
    if [ -z "$alvo" ]; then mkdir -p /mnt/.dyncheck; mount -o ro "$P" /mnt/.dyncheck 2>/dev/null && alvo=/mnt/.dyncheck; tmp=1; fi
    [ -n "$alvo" ] && [ "$(cat "$alvo/dyn-marker.txt" 2>/dev/null)" = dados-dyn ]; check $? "os dados originais continuam intactos"
    [ -n "${tmp:-}" ] && { umount /mnt/.dyncheck 2>/dev/null; rmdir /mnt/.dyncheck 2>/dev/null; }
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MP" 2>/dev/null
    echo "limpeza: disco $D zerado."
}
run "$@"

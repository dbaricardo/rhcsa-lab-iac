# Dominio 4 / lvm: estender VG com um 2o disco. Params: DSIZE DSIZE2 VG
ID=dyn-lvm-vg-extend
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    D2=$(need_disk "$DSIZE2") || exit 1
    disk_clean "$D" "$D2" || exit 1
    pvcreate -ff -y "$D" &>/dev/null && vgcreate "$VG" "$D" &>/dev/null || { echo "ERRO: pvcreate/vgcreate falhou"; exit 1; }
    vgs --noheadings --nosuffix --units m -o vg_size "$VG" | awk '{printf "%d\n", $1}' > "$ST/$ID.size"
    echo "VG $VG existe em $D; $D2 esta livre."
}
do_grade() {
    D2=$(need_disk "$DSIZE2") || { check 1 "2o disco de pratica encontrado"; return; }
    pvs --noheadings -o pv_name 2>/dev/null | grep -qwF "$D2"; check $? "$D2 foi inicializado como PV"
    [ "$(pvs --noheadings -o vg_name "$D2" 2>/dev/null | tr -d ' ')" = "$VG" ]; check $? "$D2 faz parte do VG $VG"
    ini=$(cat "$ST/$ID.size" 2>/dev/null)
    now=$(vgs --noheadings --nosuffix --units m -o vg_size "$VG" 2>/dev/null | awk '{printf "%d", $1}')
    [ "${now:-0}" -gt "${ini:-999999}" ]; check $? "o VG $VG cresceu (de ${ini:-?} para ${now:-0} MB)"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    D2=$(need_disk "$DSIZE2") || exit 1
    disk_clean "$D" "$D2" || exit 1
    rm -f "${ST:?}/${ID:?}.size"
    echo "limpeza: discos $D e $D2 zerados."
}
run "$@"

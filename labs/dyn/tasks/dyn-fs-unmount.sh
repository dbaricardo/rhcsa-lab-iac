# Dominio 4 / filesystems: desmontar com processo usando (sem disco). Params: MOUNT
ID=dyn-fs-unmount
# NUNCA usar "fuser -km <dir>" num diretorio que pode nao ser ponto de montagem: com -m ele
# mira o filesystem inteiro (o "/") e mata todos os processos do host.
# Aqui so' se age em ponto de montagem verificado e dentro de /mnt.
seguro() { case "$MOUNT" in /mnt/?*) mountpoint -q "$MOUNT" ;; *) return 1 ;; esac; }
do_start() {
    case "$MOUNT" in /mnt/?*) ;; *) echo "ERRO: ponto de montagem fora de /mnt: $MOUNT"; exit 1 ;; esac
    mkdir -p "$MOUNT"
    if seguro; then fuser -k "$MOUNT" &>/dev/null; umount -l "$MOUNT"; fi
    mount -t tmpfs -o size=16m tmpfs "$MOUNT" || exit 1
    echo dados > "$MOUNT/arquivo.txt"
    ( cd "$MOUNT" && exec setsid sleep 100000 </dev/null &>/dev/null ) &
    sleep 1
    echo "$MOUNT montado e com um processo usando-o (cwd dentro dele)."
}
do_grade() {
    ! mountpoint -q "$MOUNT"; check $? "$MOUNT nao esta mais montado"
}
do_finish() {
    if seguro; then fuser -k "$MOUNT" &>/dev/null; umount "$MOUNT" 2>/dev/null || umount -l "$MOUNT"; fi
    pkill -f '^sleep 100000$' 2>/dev/null
    case "$MOUNT" in /mnt/?*) rmdir "$MOUNT" 2>/dev/null ;; esac
    echo "limpeza: $MOUNT desmontado e processo encerrado."
}
run "$@"

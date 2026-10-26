# Dominio 2 / boot: sistema de arquivos montado somente leitura. Params: FILE CONTENT
ID=dyn-ro-root
IMG=/var/lib/dyn-ro.img
MP=/mnt/dynro
cleanup() {
    umount "$MP" &>/dev/null || umount -l "$MP" &>/dev/null
    for l in $(losetup -j "$IMG" 2>/dev/null | cut -d: -f1); do losetup -d "$l" &>/dev/null; done
    rm -f "$IMG"; rmdir "$MP" 2>/dev/null
}
do_start() {
    cleanup
    truncate -s 64M "$IMG" && mkfs.ext4 -q -F "$IMG" || { echo "ERRO: nao criei a imagem"; return 1; }
    mkdir -p "$MP"
    # o loop device fica gravavel: so' o sistema de arquivos e' montado como somente leitura
    loopdev=$(losetup -f --show "$IMG") && mount -o ro "$loopdev" "$MP" || { echo "ERRO: nao montei $MP"; return 1; }
    echo "$MP montado somente leitura."
}
do_grade() {
    opts=$(findmnt -rno OPTIONS "$MP" 2>/dev/null | head -1)
    case ",$opts," in *,rw,*) true ;; *) false ;; esac; check $? "$MP esta montado em leitura e escrita (opcoes: ${opts:-desmontado})"
    [ -f "$FILE" ] && [ "$(cat "$FILE")" = "$CONTENT" ]; check $? "o arquivo $FILE existe com o conteudo \"$CONTENT\""
}
do_finish() { cleanup; echo "limpeza: $MP desmontado e a imagem removida."; }
run "$@"

# Dominio 4 / swap: swap file persistente (sem disco). Params: SIZE SWAPFILE
ID=dyn-swap-file
limpa() {
    swapoff "$SWAPFILE" 2>/dev/null
    rm -f "$SWAPFILE"
    awk -v f="$SWAPFILE" '$1 !~ /^#/ && $1==f {next} {print}' /etc/fstab > "$ST/fstab.novo" && cat "$ST/fstab.novo" > /etc/fstab
    rm -f "${ST:?}/fstab.novo"
    systemctl daemon-reload
}
do_start() { limpa; echo "$SWAPFILE nao existe e nao esta no fstab."; }
do_grade() {
    [ -f "$SWAPFILE" ]; check $? "$SWAPFILE existe"
    [ "$(stat -c %a "$SWAPFILE" 2>/dev/null)" = 600 ]; check $? "as permissoes de $SWAPFILE sao 600 (atual: $(stat -c %a "$SWAPFILE" 2>/dev/null))"
    mb=$(( $(stat -c %s "$SWAPFILE" 2>/dev/null || echo 0) / 1048576 ))
    [ "$mb" -ge $((SIZE * 90 / 100)) ]; check $? "o arquivo tem ~$SIZE MB (atual: $mb MB)"
    swapon --noheadings --show=NAME | grep -qxF "$SWAPFILE"; check $? "a swap em $SWAPFILE esta ativa"
    awk -v f="$SWAPFILE" '$1 !~ /^#/ && $1==f && $3=="swap"{ok=1} END{exit !ok}' /etc/fstab
    check $? "o /etc/fstab tem a entrada de swap de $SWAPFILE"
}
do_finish() { limpa; echo "limpeza: $SWAPFILE removido, swap desativada, fstab restaurado."; }
run "$@"

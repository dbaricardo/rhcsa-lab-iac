# Dominio 2 / boot: alvo padrao do systemd. Params: TARGET
ID=dyn-boot-default-target
do_start() {
    [ -e "$ST/$ID.orig" ] || systemctl get-default > "$ST/$ID.orig"
    other=multi-user.target; [ "$TARGET" = multi-user.target ] && other=graphical.target
    systemctl set-default "$other" &>/dev/null
    echo "alvo padrao atual: $(systemctl get-default); a questao pede $TARGET."
}
do_grade() {
    cur=$(systemctl get-default 2>/dev/null)
    [ "$cur" = "$TARGET" ]; check $? "alvo padrao do systemd e $TARGET (atual: ${cur:-nenhum})"
}
do_finish() {
    [ -s "$ST/$ID.orig" ] && systemctl set-default "$(cat "$ST/$ID.orig")" &>/dev/null
    rm -f "$ST/$ID.orig"
    echo "limpeza: alvo padrao restaurado para $(systemctl get-default)."
}
run "$@"

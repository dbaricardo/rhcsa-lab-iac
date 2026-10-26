# Dominio 2 / boot: alvo, timeout do GRUB e argumento do kernel errados. Params: TARGET WRONGT TIMEOUT WRONGTO KARG KMODE (add|remove)
ID=dyn-boot-troubleshoot
do_start() {
    boot_save "$ID"; target_save "$ID"
    systemctl set-default "$WRONGT" &>/dev/null
    sed -i '/^[[:space:]]*GRUB_TIMEOUT=/d' /etc/default/grub; echo "GRUB_TIMEOUT=$WRONGTO" >> /etc/default/grub
    grub_regen
    if [ "$KMODE" = add ]; then grubby --update-kernel=ALL --remove-args="$KARG" &>/dev/null
    else grubby --update-kernel=ALL --args="$KARG" &>/dev/null; fi
    echo "alvo $(systemctl get-default), timeout $(grub_timeout_default), argumentos: $(kargs)"
}
do_grade() {
    cur=$(systemctl get-default 2>/dev/null)
    [ "$cur" = "$TARGET" ]; check $? "alvo padrao do systemd e $TARGET (atual: ${cur:-nenhum})"
    [ "$(grub_timeout_default)" = "$TIMEOUT" ]; check $? "GRUB_TIMEOUT=$TIMEOUT em /etc/default/grub (atual: $(grub_timeout_default))"
    [ "$(grub_timeout_cfg)" = "$TIMEOUT" ]; check $? "o grub.cfg foi regenerado com set timeout=$TIMEOUT (atual: $(grub_timeout_cfg))"
    if [ "$KMODE" = add ]; then karg_has "$KARG"; else ! karg_has "$KARG"; fi
    check $? "o argumento $KARG esta $([ "$KMODE" = add ] && echo presente || echo ausente) no kernel padrao"
}
do_finish() { boot_restore "$ID"; target_restore "$ID"; echo "limpeza: GRUB, entradas de boot e alvo padrao restaurados."; }
run "$@"

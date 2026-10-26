# Dominio 2 / boot: tempo do menu do GRUB. Params: TIMEOUT
ID=dyn-grub-timeout
do_start() { boot_save "$ID"; echo "GRUB_TIMEOUT atual: $(grub_timeout_default); a questao pede $TIMEOUT."; }
do_grade() {
    [ "$(grub_timeout_default)" = "$TIMEOUT" ]; check $? "GRUB_TIMEOUT=$TIMEOUT em /etc/default/grub (atual: $(grub_timeout_default))"
    [ "$(grub_timeout_cfg)" = "$TIMEOUT" ]; check $? "o grub.cfg foi regenerado com set timeout=$TIMEOUT (atual: $(grub_timeout_cfg))"
}
do_finish() { boot_restore "$ID"; echo "limpeza: /etc/default/grub, grub.cfg e entradas de boot restaurados."; }
run "$@"

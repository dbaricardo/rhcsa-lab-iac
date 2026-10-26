# Dominio 2 / boot: remover argumento do kernel padrao. Params: KARG
ID=dyn-kernel-param-remove
do_start() {
    boot_save "$ID"
    grubby --update-kernel=ALL --args="$KARG" &>/dev/null
    karg_has "$KARG" && echo "argumento $KARG presente na linha do kernel." || { echo "ERRO: nao consegui injetar $KARG"; return 1; }
}
do_grade() {
    ! karg_has "$KARG"; check $? "o kernel padrao nao tem mais o argumento $KARG (atual: $(kargs))"
}
do_finish() { boot_restore "$ID"; echo "limpeza: entradas de boot e configuracao do GRUB restauradas."; }
run "$@"

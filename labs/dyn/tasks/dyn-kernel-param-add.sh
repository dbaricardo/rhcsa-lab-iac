# Dominio 2 / boot: adicionar argumento ao kernel padrao. Params: KARG
ID=dyn-kernel-param-add
do_start() {
    boot_save "$ID"
    grubby --update-kernel=ALL --remove-args="$KARG" &>/dev/null
    ! karg_has "$KARG" && echo "argumento $KARG ausente da linha do kernel." || { echo "ERRO: nao consegui remover $KARG"; return 1; }
}
do_grade() {
    karg_has "$KARG"; check $? "o kernel padrao tem o argumento $KARG (grubby --info=DEFAULT)"
}
do_finish() { boot_restore "$ID"; echo "limpeza: entradas de boot e configuracao do GRUB restauradas."; }
run "$@"

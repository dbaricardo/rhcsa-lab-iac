# Dominio 2 / boot: alvo padrao emergency ou rescue. Params: TARGET
ID=dyn-emergency-target
do_start() { target_save "$ID"; echo "alvo padrao atual: $(systemctl get-default); a questao pede $TARGET."; }
do_grade() {
    cur=$(systemctl get-default 2>/dev/null)
    [ "$cur" = "$TARGET" ]; check $? "alvo padrao do systemd e $TARGET (atual: ${cur:-nenhum})"
}
do_finish() { target_restore "$ID"; echo "limpeza: alvo padrao restaurado para $(systemctl get-default)."; }
run "$@"

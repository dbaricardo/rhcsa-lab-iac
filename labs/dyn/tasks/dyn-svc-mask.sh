# Dominio 6 / services: mascarar. Params: SVC
ID=dyn-svc-mask
do_start() { unit_purge "$SVC"; unit_mk "$SVC" "/usr/bin/sleep infinity"; systemctl start "$SVC"; echo "o servico $SVC.service esta em execucao."; }
do_grade() {
    [ "$(systemctl is-enabled "$SVC" 2>/dev/null)" = masked ]; check $? "o servico $SVC esta mascarado"
    [ "$(systemctl is-active "$SVC" 2>/dev/null)" != active ]; check $? "o servico $SVC nao esta em execucao"
}
do_finish() { unit_purge "$SVC"; echo "limpeza: $SVC desmascarado e removido."; }
run "$@"

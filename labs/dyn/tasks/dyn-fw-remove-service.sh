# Dominio 7 / firewall: remover um servico de uma zona. Params: SERVICE ZONE
ID=dyn-fw-remove-service
do_start() {
    fw_save "$ID"; systemctl is-active --quiet firewalld || systemctl start firewalld
    firewall-cmd --permanent --zone="$ZONE" --add-service="$SERVICE" &>/dev/null
    firewall-cmd --reload &>/dev/null
    echo "o servico $SERVICE esta na zona $ZONE (permanente e em execucao)."
}
do_grade() {
    [ "$(firewall-cmd --permanent --zone="$ZONE" --query-service="$SERVICE" 2>/dev/null)" = no ]
    check $? "o servico $SERVICE saiu da configuracao permanente da zona $ZONE"
    [ "$(firewall-cmd --zone="$ZONE" --query-service="$SERVICE" 2>/dev/null)" = no ]
    check $? "o servico $SERVICE saiu da zona $ZONE em execucao (firewall-cmd --reload)"
}
do_finish() { fw_restore "$ID"; echo "limpeza: configuracao do firewalld restaurada."; }
run "$@"

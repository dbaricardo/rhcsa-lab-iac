# Dominio 7 / firewall: servico inacessivel. Params: SERVICE ZONE SCENARIO(not_added|wrong_zone|not_reloaded|stopped) PORT
ID=dyn-fw-troubleshoot
do_start() {
    fw_save "$ID"; systemctl is-active --quiet firewalld || systemctl start firewalld
    firewall-cmd --permanent --zone="$ZONE" --remove-service="$SERVICE" &>/dev/null
    firewall-cmd --permanent --zone="$ZONE" --remove-port="$PORT" &>/dev/null
    firewall-cmd --reload &>/dev/null
    case "$SCENARIO" in
        wrong_zone)   firewall-cmd --permanent --zone=dmz --add-service="$SERVICE" &>/dev/null; firewall-cmd --reload &>/dev/null ;;
        not_reloaded) firewall-cmd --permanent --zone="$ZONE" --add-service="$SERVICE" &>/dev/null ;;
        stopped)      systemctl stop firewalld ;;
    esac
    echo "defeito de firewall injetado: $SCENARIO."
}
do_grade() {
    [ "$(systemctl is-active firewalld 2>/dev/null)" = active ]; check $? "o firewalld esta em execucao"
    [ "$(firewall-cmd --permanent --zone="$ZONE" --query-service="$SERVICE" 2>/dev/null)" = yes ]
    check $? "o servico $SERVICE esta na zona $ZONE na configuracao permanente"
    local run_svc run_port
    run_svc=$(firewall-cmd --zone="$ZONE" --query-service="$SERVICE" 2>/dev/null)
    run_port=$(firewall-cmd --zone="$ZONE" --query-port="$PORT" 2>/dev/null)
    [ "$run_svc" = yes ] || [ "$run_port" = yes ]; check $? "a porta $PORT esta aberta agora na zona $ZONE (pelo servico ou por regra de porta)"
}
do_finish() { fw_restore "$ID"; echo "limpeza: configuracao do firewalld restaurada."; }
run "$@"

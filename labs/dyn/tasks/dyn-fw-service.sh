# Dominio 7 / firewall: liberar servico. Params: SERVICE ZONE
ID=dyn-fw-service
do_start() {
    systemctl is-active --quiet firewalld || systemctl enable --now firewalld &>/dev/null
    if [ ! -e "$ST/$ID.orig" ]; then
        p=$(firewall-cmd --permanent --zone="$ZONE" --query-service="$SERVICE" 2>/dev/null)
        r=$(firewall-cmd --zone="$ZONE" --query-service="$SERVICE" 2>/dev/null)
        echo "${p:-no} ${r:-no}" > "$ST/$ID.orig"
    fi
    firewall-cmd --permanent --zone="$ZONE" --remove-service="$SERVICE" &>/dev/null
    firewall-cmd --zone="$ZONE" --remove-service="$SERVICE" &>/dev/null
    echo "servico $SERVICE fora da zona $ZONE."
}
do_grade() {
    [ "$(firewall-cmd --permanent --zone="$ZONE" --query-service="$SERVICE" 2>/dev/null)" = yes ]
    check $? "servico $SERVICE na configuracao permanente da zona $ZONE"
    [ "$(firewall-cmd --zone="$ZONE" --query-service="$SERVICE" 2>/dev/null)" = yes ]
    check $? "servico $SERVICE ativo agora na zona $ZONE (firewall-cmd --reload)"
}
do_finish() {
    read -r p r < "$ST/$ID.orig" 2>/dev/null || { p=no; r=no; }
    if [ "$p" = yes ]; then firewall-cmd --permanent --zone="$ZONE" --add-service="$SERVICE" &>/dev/null
    else firewall-cmd --permanent --zone="$ZONE" --remove-service="$SERVICE" &>/dev/null; fi
    if [ "$r" = yes ]; then firewall-cmd --zone="$ZONE" --add-service="$SERVICE" &>/dev/null
    else firewall-cmd --zone="$ZONE" --remove-service="$SERVICE" &>/dev/null; fi
    rm -f "$ST/$ID.orig"
    echo "limpeza: servico $SERVICE na zona $ZONE restaurado."
}
run "$@"

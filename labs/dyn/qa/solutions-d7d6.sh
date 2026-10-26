# Solucoes e retratos das tarefas dos dominios 7 (SELinux/firewall) e 6 (servicos/timers).
# Usado por validate-ported.sh. Cada solucao roda no host com os params da tarefa, sob "set -e".
sol dyn-selinux-mode <<'EOS'
if [ "$MODE" = Enforcing ]; then setenforce 1; else setenforce 0; fi
sed -i -E "s/^SELINUX=.*/SELINUX=$(echo $MODE | tr A-Z a-z)/" /etc/selinux/config
EOS
sol dyn-selinux-context <<'EOS'
semanage fcontext -a -t $TYPE "$DIR(/.*)?"
restorecon -Rv $DIR
EOS
sol dyn-selinux-denial <<'EOS'
if [ "$KIND" = boolean ]; then
    setsebool -P $TARGET on
else
    restorecon -R $TARGET
    if [ "$(matchpathcon -n $TARGET | cut -d: -f3)" != "$TYPE" ]; then
        semanage fcontext -a -t $TYPE "$TARGET(/.*)?"
        restorecon -R $TARGET
    fi
fi
EOS
sol dyn-selinux-avc <<'EOS'
restorecon -R $DIR
if [ "$(matchpathcon -n $DIR | cut -d: -f3)" != "$TYPE" ]; then
    semanage fcontext -a -t $TYPE "$DIR(/.*)?"
    restorecon -R $DIR
fi
EOS
sol dyn-selinux-restorecon <<'EOS'
restorecon -Rv $DIR
EOS
sol dyn-selinux-service-diag <<'EOS'
if [ -n "$DIR" ]; then semanage fcontext -a -t $TYPE "$DIR(/.*)?"; restorecon -R $DIR; fi
if [ -n "$BOOL" ]; then setsebool -P $BOOL on; fi
if [ -n "$PORT" ]; then semanage port -a -t $PTYPE -p tcp $PORT 2>/dev/null || semanage port -m -t $PTYPE -p tcp $PORT; fi
EOS
sol dyn-selinux-relabel <<'EOS'
touch /.autorelabel
EOS
sol dyn-fw-enable <<'EOS'
systemctl enable --now firewalld
EOS
sol dyn-fw-remove-service <<'EOS'
firewall-cmd --permanent --zone=$ZONE --remove-service=$SERVICE
firewall-cmd --reload
EOS
sol dyn-fw-default-zone <<'EOS'
firewall-cmd --set-default-zone=$ZONE
EOS
sol dyn-fw-rich-rule <<'EOS'
firewall-cmd --permanent --zone=$ZONE --add-rich-rule="$RULE"
firewall-cmd --reload
EOS
sol dyn-fw-reload <<'EOS'
firewall-cmd --reload
EOS
sol dyn-fw-troubleshoot <<'EOS'
systemctl start firewalld
firewall-cmd --permanent --zone=$ZONE --add-service=$SERVICE
firewall-cmd --reload
EOS
sol dyn-fw-full-setup <<'EOS'
systemctl enable --now firewalld
firewall-cmd --set-default-zone=$ZONE
for s in $SERVICES; do firewall-cmd --permanent --zone=$ZONE --add-service=$s; done
for p in $PORTS; do firewall-cmd --permanent --zone=$ZONE --add-port=$p; done
firewall-cmd --reload
EOS
sol dyn-svc-start <<'EOS'
systemctl start $SVC
EOS
sol dyn-svc-enable <<'EOS'
systemctl enable $SVC
EOS
sol dyn-svc-start-enable <<'EOS'
systemctl enable --now $SVC
EOS
sol dyn-svc-stop-disable <<'EOS'
systemctl disable --now $SVC
EOS
sol dyn-svc-mask <<'EOS'
systemctl stop $SVC
systemctl mask $SVC
EOS
sol dyn-svc-troubleshoot <<'EOS'
u=$(systemctl show -p FragmentPath --value $SVC)
case "$SCENARIO" in
    badpath) sed -i "s#^ExecStart=.*#ExecStart=/usr/local/bin/${SVC}d#" $u ;;
    noexec) chmod +x /usr/local/bin/${SVC}d ;;
    baduser) sed -i '/^User=/d' $u ;;
    envfile) touch /etc/sysconfig/$SVC ;;
esac
systemctl daemon-reload
systemctl restart $SVC
EOS
sol dyn-svc-list-failed <<'EOS'
systemctl --failed > $OUTFILE
EOS
sol dyn-svc-dependencies <<'EOS'
systemctl list-dependencies $SVC > $OUTFILE
EOS
sol dyn-svc-restart-policy <<'EOS'
mkdir -p /etc/systemd/system/$SVC.service.d
printf '[Service]\nRestart=always\nRestartSec=%s\n' $RESTARTSEC > /etc/systemd/system/$SVC.service.d/override.conf
systemctl daemon-reload
systemctl restart $SVC
EOS
sol dyn-svc-manage-proc <<'EOS'
systemctl start $SVC
systemctl show $SVC -p MainPID --value > $PIDFILE
EOS
sol dyn-timer-create <<'EOS'
printf '[Unit]\nDescription=lab\n\n[Service]\nType=oneshot\nExecStart=%s\n' "$CMD" > /etc/systemd/system/$NAME.service
printf '[Unit]\nDescription=lab\n\n[Timer]\nOnCalendar=%s\nPersistent=true\n\n[Install]\nWantedBy=timers.target\n' "$SCHEDULE" > /etc/systemd/system/$NAME.timer
systemctl daemon-reload
systemctl enable --now $NAME.timer
EOS
SOL[dyn-timer-oncalendar]=${SOL[dyn-timer-create]}
sol dyn-timer-onboot <<'EOS'
printf '[Unit]\nDescription=lab\n\n[Service]\nType=oneshot\nExecStart=%s\n' "$CMD" > /etc/systemd/system/$NAME.service
printf '[Unit]\nDescription=lab\n\n[Timer]\nOnBootSec=%s\n\n[Install]\nWantedBy=timers.target\n' "$DELAY" > /etc/systemd/system/$NAME.timer
systemctl daemon-reload
systemctl enable --now $NAME.timer
EOS
sol dyn-timer-monotonic <<'EOS'
printf '[Unit]\nDescription=lab\n\n[Service]\nType=oneshot\nExecStart=%s\n' "$CMD" > /etc/systemd/system/$NAME.service
printf '[Unit]\nDescription=lab\n\n[Timer]\nOnBootSec=%s\nOnUnitActiveSec=%s\n\n[Install]\nWantedBy=timers.target\n' "$INTERVAL" "$INTERVAL" > /etc/systemd/system/$NAME.timer
systemctl daemon-reload
systemctl enable --now $NAME.timer
EOS
sol dyn-timer-list <<'EOS'
systemctl list-timers --all > $OUTFILE
EOS
sol dyn-timer-enable <<'EOS'
systemctl enable --now $NAME.timer
EOS
sol dyn-timer-cron-convert <<'EOS'
printf '[Unit]\nDescription=lab\n\n[Service]\nType=oneshot\nExecStart=%s\n' "$CMD" > /etc/systemd/system/$NAME.service
printf '[Unit]\nDescription=lab\n\n[Timer]\nOnCalendar=%s\n\n[Install]\nWantedBy=timers.target\n' "$ONCAL" > /etc/systemd/system/$NAME.timer
systemctl daemon-reload
systemctl enable --now $NAME.timer
EOS
sol dyn-timer-troubleshoot <<'EOS'
s=/etc/systemd/system/$NAME.service
t=/etc/systemd/system/$NAME.timer
case "$SCENARIO" in
    bad_oncalendar) sed -i 's/^OnCalendar=.*/OnCalendar=*-*-* 03:30:00/' $t ;;
    missing_service) printf '[Unit]\nDescription=lab\n\n[Service]\nType=oneshot\nExecStart=%s\n' "$CMD" > $s ;;
    wrong_unit) sed -i '/^Unit=/d' $t ;;
esac
systemctl daemon-reload
systemctl enable --now $NAME.timer
EOS
# Retrato do estado que deve voltar IGUAL depois do finish.
RETD7=$(cat <<'EOS'
echo "selinux=$(getenforce) cfg=$(md5sum < /etc/selinux/config | cut -c1-8) bools=$(semanage boolean -l | md5sum | cut -c1-8) ports=$(semanage port -l -C | wc -l) fctx=$(semanage fcontext -l -C | wc -l) relabel=$(ls /.autorelabel 2>&1 | tail -1 | cut -c1-24)"
echo "fwstate=$(systemctl is-enabled firewalld 2>&1)/$(systemctl is-active firewalld 2>&1) fwconf=$(find /etc/firewalld -type f -exec md5sum {} \; | sort -k2 | md5sum | cut -c1-8)"
echo "units=$(ls /etc/systemd/system /usr/lib/systemd/system | grep -E '^(lab|dyn)' | tr '\n' ' ') dropins=$(ls -d /etc/systemd/system/*.d 2>/dev/null | grep -E '/(lab|dyn)' | tr '\n' ' ') failed=$(systemctl --failed --no-legend | wc -l)"
echo "dirs=$(ls -d /srv/* /opt/* /var/www/* /var/log/dyn* /etc/dyn* 2>&1 | tr '\n' ' ')"
echo "rotulos=$(restorecon -nR /etc /srv /opt /var/www /usr/local 2>&1 | wc -l)"
echo "tmp=$(ls /tmp | grep -E '^(failed|deps|timers|active_timers|labproc|service-)' | tr '\n' ' ') sysconfig=$(ls /etc/sysconfig | md5sum | cut -c1-8) bin=$(ls /usr/local/bin | tr '\n' ' ') passwd=$(getent passwd | md5sum | cut -c1-8)"
EOS
)
for id in dyn-selinux-mode dyn-selinux-context dyn-selinux-denial dyn-selinux-avc dyn-selinux-restorecon dyn-selinux-service-diag \
          dyn-selinux-relabel dyn-fw-enable dyn-fw-remove-service dyn-fw-default-zone dyn-fw-rich-rule dyn-fw-reload \
          dyn-fw-troubleshoot dyn-fw-full-setup dyn-svc-start dyn-svc-enable dyn-svc-start-enable dyn-svc-stop-disable \
          dyn-svc-mask dyn-svc-troubleshoot dyn-svc-list-failed dyn-svc-dependencies dyn-svc-restart-policy dyn-svc-manage-proc \
          dyn-timer-create dyn-timer-oncalendar dyn-timer-onboot dyn-timer-monotonic dyn-timer-list dyn-timer-enable \
          dyn-timer-cron-convert dyn-timer-troubleshoot; do
    RET[$id]=$RETD7
done

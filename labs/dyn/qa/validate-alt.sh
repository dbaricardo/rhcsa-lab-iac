#!/bin/bash
# QA de CAMINHOS ALTERNATIVOS do aluno: resolve cada tarefa de formas diferentes da solucao de
# referencia e confere que o grade aceita (e o finish restaura o retrato).
# Uso (workstation, como student): validate-alt.sh [id-da-tarefa ...]
DYN=${DYN:-/usr/local/lib/lab-dyn}
# shellcheck disable=SC1091
source "$DYN/qa/validate-ported.sh"
set -u
declare -A ALT
alt() { ALT[$1]+="$(cat)"$'\x1e'; }   # alt <id> <<'EOS' ... EOS  (uma chamada por alternativa)

alt dyn-net-hostname <<'EOS'
nmcli general hostname $NEWNAME
EOS
alt dyn-net-hostname <<'EOS'
echo $NEWNAME > /etc/hostname; hostname $NEWNAME
EOS
alt dyn-fw-service <<'EOS'
firewall-cmd --zone=$ZONE --add-service=$SERVICE; firewall-cmd --runtime-to-permanent
EOS
alt dyn-fw-port <<'EOS'
firewall-cmd --zone=$ZONE --add-port=$PORT/$PROTO; firewall-cmd --runtime-to-permanent
EOS
alt dyn-selinux-bool <<'EOS'
setsebool $BOOL $VALUE; setsebool -P $BOOL $VALUE
EOS
alt dyn-selinux-bool <<'EOS'
if [ "$VALUE" = on ]; then f=--on; else f=--off; fi; semanage boolean -m $f $BOOL; setsebool $BOOL $VALUE
EOS
alt dyn-user-create-uid <<'EOS'
useradd $ACCT; usermod -u $UIDN -s /bin/bash $ACCT
EOS
alt dyn-user-create-uid <<'EOS'
useradd -m -d /home/$ACCT -u $UIDN -s /bin/bash $ACCT
EOS
alt dyn-acl-file <<'EOS'
setfacl -m user:$ACCT:$ACLPERMS $FILE
EOS
alt dyn-acl-file <<'EOS'
setfacl -m u:$ACCT:$ACLPERMS,m::rwx $FILE
EOS
alt dyn-sudo <<'EOS'
tag=""; [ "$NOPASSWD" = yes ] && tag="NOPASSWD: "
echo "$ACCT ALL=(ALL:ALL) ${tag}$CMDS" | EDITOR=tee visudo -f /etc/sudoers.d/90-$ACCT
chmod 440 /etc/sudoers.d/90-$ACCT; visudo -c
EOS
alt dyn-sudo <<'EOS'
tag=""; [ "$NOPASSWD" = yes ] && tag="NOPASSWD: "
cat > /etc/sudoers.d/$ACCT <<EOF
$ACCT ALL=(ALL) ${tag}$CMDS
EOF
chmod 0440 /etc/sudoers.d/$ACCT; visudo -c
EOS
alt dyn-svc-enable <<'EOS'
systemctl enable $SVC.service
EOS
alt dyn-svc-enable <<'EOS'
systemctl enable --now $SVC
EOS
alt dyn-timer-oncalendar <<'EOS'
printf '[Unit]\nDescription=%s\n[Service]\nType=oneshot\nExecStart=%s\n' $NAME "$CMD" > /etc/systemd/system/$NAME.service
printf '[Timer]\nOnCalendar = %s\nPersistent=true\n[Install]\nWantedBy=timers.target\n' "$SCHEDULE" > /etc/systemd/system/$NAME.timer
systemctl daemon-reload; systemctl enable --now $NAME.timer
EOS
alt dyn-swap-file <<'EOS'
dd if=/dev/zero of=$SWAPFILE bs=1M count=$SIZE status=none; chmod 600 $SWAPFILE; mkswap $SWAPFILE; swapon $SWAPFILE
echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab; systemctl daemon-reload
EOS
alt dyn-swap-file <<'EOS'
fallocate -l ${SIZE}M $SWAPFILE; chmod 0600 $SWAPFILE; mkswap -f $SWAPFILE; echo "$SWAPFILE swap swap defaults 0 0" >> /etc/fstab; systemctl daemon-reload; swapon -a
EOS

[ -f "$DYN/qa/alts-d4d7.sh" ] && source "$DYN/qa/alts-d4d7.sh"
ids=" ${*:-${!ALT[*]}} "
ok=0; bad=0
res() { if [ "$1" -eq 0 ]; then ok=$((ok+1)); printf '  PASS %s\n' "$2"; else bad=$((bad+1)); printf '  FAIL %s\n' "$2"; [ -n "${3:-}" ] && printf '%s\n' "$3" | sed 's/^/    | /' | head -${QA_LINES:-10}; fi; }
while IFS=$'\t' read -r id host envw srv; do
    case "$ids" in *" $id "*) ;; *) continue ;; esac
    [ -n "${ALT[$id]:-}" ] || continue
    n=0
    while IFS= read -r -d $'\x1e' sol; do
        n=$((n+1)); echo "== $id #$n @ $host [$envw]"
        antes=$(host_cmd "$host" "$envw" "${RET[$id]}")
        if [ "$srv" = 1 ]; then passo localhost "$id" server-start "$envw"; res $? "server-start (workstation)" "$SAIDA"; fi
        passo "$host" "$id" start "$envw"; res $? "start" "$SAIDA"
        passo "$host" "$id" grade "$envw"; [ $? -ne 0 ]; res $? "grade antes falha" "$SAIDA"
        out=$(host_cmd "$host" "$envw" "$sol" estrito); res $? "alternativa aplicada" "$out"
        passo "$host" "$id" grade "$envw"; res $? "grade depois passa" "$SAIDA"
        passo "$host" "$id" finish "$envw"; res $? "finish" "$SAIDA"
        if [ "$srv" = 1 ]; then passo localhost "$id" server-finish "$envw"; res $? "server-finish (workstation)" "$SAIDA"; fi
        depois=$(host_cmd "$host" "$envw" "${RET[$id]}")
        [ "$antes" = "$depois" ]; res $? "retrato igual" "ANTES: $antes
DEPOIS: $depois"
    done <<< "${ALT[$id]}"
done < <(casos $ids)
echo; echo "RESUMO ALT: $ok passaram, $bad falharam"; [ "$bad" -eq 0 ]

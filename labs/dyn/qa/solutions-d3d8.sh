# Solucoes e retratos das tarefas dos dominios 3 (usuarios/permissoes) e 8 (agendamento/scripts).
# Usado por validate-ported.sh. Cada solucao roda no host com os params da tarefa, sob "set -e".
sol() { SOL[$1]=$(cat); }
sol dyn-user-create-uid <<'EOS'
useradd -u $UIDN -m -s /bin/bash $ACCT
EOS
sol dyn-user-nologin <<'EOS'
useradd -u $UIDN -s /sbin/nologin -m $ACCT
EOS
sol dyn-user-groups <<'EOS'
for g in $GROUPS_LIST; do groupadd $g; done
usermod -aG $(echo $GROUPS_LIST | tr ' ' ,) $ACCT
EOS
sol dyn-passwd-aging <<'EOS'
chage -M $MAXD -m $MIND -W $WARN -I $INACT $ACCT
if [ "$FORCE" = yes ]; then chage -d 0 $ACCT; fi
EOS
sol dyn-group-create <<'EOS'
groupadd -g $GIDN $GRP
EOS
sol dyn-sudo <<'EOS'
tag=""; if [ "$NOPASSWD" = yes ]; then tag="NOPASSWD: "; fi
echo "$ACCT ALL=(ALL) ${tag}$CMDS" > /etc/sudoers.d/$ACCT
chmod 440 /etc/sudoers.d/$ACCT
visudo -cf /etc/sudoers.d/$ACCT
EOS
sol dyn-user-lock <<'EOS'
if [ "$ACTION" = lock ]; then usermod -L $ACCT; else usermod -U $ACCT; fi
EOS
sol dyn-user-delete <<'EOS'
if [ "$REMOVE_HOME" = yes ]; then userdel -r $ACCT; else userdel $ACCT; fi
EOS
sol dyn-user-shell <<'EOS'
usermod -s $NEWSHELL $ACCT
EOS
sol dyn-svc-account <<'EOS'
useradd -r -M -s /sbin/nologin -c "$COMMENT" $ACCT
EOS
sol dyn-bulk-users <<'EOS'
groupadd $GRP
for spec in $USERS; do
    n=${spec%%:*}; u=$(echo $spec | cut -d: -f2); sh=${spec##*:}
    useradd -u $u -s $sh -G $GRP -m $n
done
EOS
sol dyn-troubleshoot-user <<'EOS'
case "$PROBLEM" in
    locked) usermod -U $ACCT ;;
    nologin_shell) usermod -s /bin/bash $ACCT ;;
    expired_account) chage -E -1 $ACCT ;;
    expired_password) chage -d $(date +%F) -M 90 $ACCT ;;
esac
EOS
sol dyn-perm-basic <<'EOS'
chmod $PERMS $FILE
EOS
sol dyn-perm-owner <<'EOS'
chown $OWNER:$GROUP $FILE
EOS
sol dyn-acl-file <<'EOS'
setfacl -m u:$ACCT:$ACLPERMS $FILE
EOS
sol dyn-perm-special <<'EOS'
chmod $MODE $FILE
EOS
sol dyn-perm-shared-dir <<'EOS'
mkdir -p $DIR
chown :$GRP $DIR
chmod 3770 $DIR
EOS
sol dyn-acl-default <<'EOS'
mkdir -p $DIR
setfacl -d -m u:$ACCT:$ACLPERMS $DIR
EOS
sol dyn-perm-recursive <<'EOS'
chown -R $OWNER:$GRP $DIR
find $DIR -type d -exec chmod $DIRPERMS {} \;
find $DIR -type f -exec chmod $FILEPERMS {} \;
EOS
sol dyn-perm-umask <<'EOS'
h=$(getent passwd $ACCT | cut -d: -f6)
echo "umask $UMASKV" >> $h/.bashrc
EOS
sol dyn-cron-user <<'EOS'
echo "$SCHEDULE $CMD" | crontab -u root -
EOS
sol dyn-cron-expr <<'EOS'
echo "$EXPR $CMD" | crontab -u root -
EOS
sol dyn-cron-system <<'EOS'
echo "$SCHEDULE $RUNAS $CMD" > /etc/cron.d/$JOB
chmod 644 /etc/cron.d/$JOB
EOS
sol dyn-at-job <<'EOS'
echo 'echo "At job executed" >> /tmp/atjob.log' | at "$SPEC"
EOS
sol dyn-cron-list <<'EOS'
crontab -l -u $ACCT > $OUTFILE
EOS
sol dyn-cron-access <<'EOS'
if [ "$METHOD" = deny ]; then echo $ACCT >> /etc/cron.deny; else echo $ACCT > /etc/cron.allow; fi
EOS
sol dyn-cron-dir <<'EOS'
printf '#!/bin/bash\nlogger "dyn cron job %s"\n' $SCRIPT > $CRONDIR/$SCRIPT
chmod +x $CRONDIR/$SCRIPT
EOS
sol dyn-script-basic <<'EOS'
case "$PURPOSE" in
    list_users) body='cut -d: -f1 /etc/passwd' ;;
    disk_usage) body='du -sh /home' ;;
    system_info) body='hostname; uname -r' ;;
esac
printf '#!/bin/bash\n%s\n' "$body" > $SCRIPT
chmod +x $SCRIPT
EOS
sol dyn-script-args <<'EOS'
case "$TASK" in
    greet) body='echo "Hello, $1!"' ;;
    file_check) body='if [ -e "$1" ]; then echo exists; else echo "not found"; fi' ;;
    user_info) body='getent passwd "$1" || exit 1' ;;
esac
printf '#!/bin/bash\nif [ $# -lt 1 ]; then echo "usage: $0 arg" >&2; exit 1; fi\n%s\n' "$body" > $SCRIPT
chmod +x $SCRIPT
EOS
sol dyn-script-cond <<'EOS'
case "$CONDITION" in
    file_type) body='if [ -f "$1" ]; then echo file; elif [ -d "$1" ]; then echo directory; else echo "does not exist"; fi' ;;
    user_exists) body='if id "$1" &>/dev/null; then echo exists; else echo "does not exist"; fi' ;;
    service_status) body='if systemctl is-active --quiet "$1"; then echo running; else echo "not running"; fi' ;;
esac
printf '#!/bin/bash\n%s\n' "$body" > $SCRIPT
chmod +x $SCRIPT
EOS
sol dyn-script-loop <<'EOS'
case "$LOOP" in
    for_files) body='n=0; for f in /etc/*.conf; do n=$((n+1)); done; echo $n' ;;
    for_users) body='while IFS=: read -r u _; do echo "$u"; done < /etc/passwd' ;;
    for_args) body='for a in "$@"; do echo "$a"; done' ;;
esac
printf '#!/bin/bash\n%s\n' "$body" > $SCRIPT
chmod +x $SCRIPT
EOS
sol dyn-script-exit <<'EOS'
cat > $SCRIPT <<'EOF'
#!/bin/bash
if [ ! -e "$1" ]; then echo "does not exist"; exit 1; fi
if [ ! -r "$1" ]; then echo "not readable"; exit 2; fi
echo "ok"; exit 0
EOF
chmod 755 $SCRIPT
EOS
sol dyn-script-cmdsub <<'EOS'
case "$TASK" in
    count_users) body='total=$(wc -l < /etc/passwd); echo "Total users: $total"' ;;
    current_date) body='d=$(date +%F); echo "backup-$d.tar.gz"' ;;
    disk_free) body='free=$(df -BM --output=avail / | tail -1 | tr -dc 0-9); if [ "$free" -lt "$1" ]; then echo LOW; else echo OK; fi' ;;
esac
printf '#!/bin/bash\n%s\n' "$body" > $SCRIPT
chmod +x $SCRIPT
EOS
# Retrato do estado do host que deve voltar IGUAL depois do finish.
RETD3=$(cat <<'EOS'
echo "passwd=$(getent passwd | md5sum | cut -c1-10) group=$(getent group | md5sum | cut -c1-10) shadow=$(md5sum < /etc/shadow | cut -c1-10) gshadow=$(md5sum < /etc/gshadow | cut -c1-10)"
echo "sudoers=$(md5sum < /etc/sudoers | cut -c1-10) dropins=$(ls /etc/sudoers.d | tr '\n' ' ')"
echo "spool=$(ls /var/spool/cron | tr '\n' ' ') rootcron=$(cat /var/spool/cron/root 2>/dev/null | md5sum | cut -c1-10)"
echo "crond=$(ls /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly | tr '\n' ' ')"
echo "access=$(ls /etc/cron.allow /etc/cron.deny 2>&1 | tr '\n' ' ') deny=$(md5sum < /etc/cron.deny | cut -c1-10)"
echo "at=$(atq | wc -l) home=$(ls /home | tr '\n' ' ') mail=$(ls /var/spool/mail | tr '\n' ' ')"
echo "praticas=$(ls /shared /srv /var/data 2>&1 | tr '\n' ' ') bin=$(ls /usr/local/bin | tr '\n' ' ')"
echo "tmp=$(ls /tmp | grep -E '^(testfile|ownertest|acltest|specialperm|cron|atjob|dyn)' | tr '\n' ' ')"
echo "rotulos=$(restorecon -nR /etc /srv /opt /var/www /usr/local 2>&1 | wc -l)"
echo "rootrc=$(md5sum < /root/.bashrc | cut -c1-10) rootprofile=$(md5sum < /root/.bash_profile | cut -c1-10) profiled=$(ls /etc/profile.d | md5sum | cut -c1-10)"
EOS
)
for id in dyn-user-create-uid dyn-user-nologin dyn-user-groups dyn-passwd-aging dyn-group-create dyn-sudo dyn-user-lock \
          dyn-user-delete dyn-user-shell dyn-svc-account dyn-bulk-users dyn-troubleshoot-user dyn-perm-basic dyn-perm-owner \
          dyn-acl-file dyn-perm-special dyn-perm-shared-dir dyn-acl-default dyn-perm-recursive dyn-perm-umask dyn-cron-user \
          dyn-cron-expr dyn-cron-system dyn-at-job dyn-cron-list dyn-cron-access dyn-cron-dir dyn-script-basic dyn-script-args \
          dyn-script-cond dyn-script-loop dyn-script-exit dyn-script-cmdsub; do
    RET[$id]=$RETD3
done

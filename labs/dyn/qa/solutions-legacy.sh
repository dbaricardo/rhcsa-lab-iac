# Solucoes de referencia das 24 questoes LEGADAS (examsim-*), no mesmo molde das portadas.
# Usado por solve-legacy.sh: cada solucao roda como root no host da questao, sob "set -e".
# Os discos de pratica da serverb sao achados pelo tamanho (D1 = 1 GiB, D6 = 6 GiB).
LPRE='D1=$(lsblk -bdnro NAME,SIZE | awk "\$2==1073741824{print \"/dev/\"\$1; exit}"); D6=$(lsblk -bdnro NAME,SIZE | awk "\$2==6442450944{print \"/dev/\"\$1; exit}"); '
declare -A LSOL
lsol() { LSOL[$1]=$(cat); }
lsol examsim-flatpak <<'EOS'
flatpak remote-add --system examrepo http://flatpak.lab.example.com:8091/myrepo.flatpakrepo
flatpak install --system -y --noninteractive examrepo com.vscodium.codium
EOS
lsol examsim-network <<'EOS'
hostnamectl set-hostname primary.net1.example.com
nmcli con add type ethernet ifname ens19 con-name qa-ens19 ipv4.method manual ipv4.addresses 192.168.56.91/24 ipv4.gateway 192.168.56.1 ipv4.dns 192.168.56.1 ipv6.method ignore connection.autoconnect yes
nmcli con up qa-ens19
EOS
for n in node1 node2; do
lsol examsim-repo-$n <<'EOS'
printf '[qa-baseos]\nname=BaseOS\nbaseurl=http://content.example.com:8091/rhel10.0/x86_64/dvd/BaseOS\nenabled=1\ngpgcheck=0\n[qa-appstream]\nname=AppStream\nbaseurl=http://content.example.com:8091/rhel10.0/x86_64/dvd/AppStream\nenabled=1\ngpgcheck=0\n' > /etc/yum.repos.d/qa-lab.repo
EOS
done
lsol examsim-selinux-httpd <<'EOS'
semanage port -a -t http_port_t -p tcp 82
restorecon -v /var/www/html/file1
firewall-cmd --permanent --add-port=82/tcp; firewall-cmd --reload
systemctl enable --now httpd
EOS
lsol examsim-grupos <<'EOS'
groupadd -f sysadmin
for u in natasha harry; do id $u &>/dev/null || useradd $u; usermod -aG sysadmin $u; done
id sarah &>/dev/null || useradd -s /sbin/nologin sarah
for u in natasha harry sarah; do echo "$u:atenorth" | chpasswd; done
EOS
lsol examsim-dir-colaborativo <<'EOS'
groupadd -f sysadmin
mkdir -p /common/admin; chgrp sysadmin /common/admin; chmod 2770 /common/admin
EOS
lsol examsim-cron <<'EOS'
echo "23 14 * * * /bin/echo hello" | crontab -u natasha -
echo '*/3 * * * * /usr/bin/logger "EX200 in progress"' | crontab -u harry -
EOS
lsol examsim-backup <<'EOS'
tar -cjf /home/backup.tar.bz2 /etc 2>/dev/null || true
EOS
lsol examsim-ntp <<'EOS'
echo "server classroom.example.com iburst" >> /etc/chrony.conf
systemctl enable --now chronyd; systemctl restart chronyd; sleep 3
EOS
lsol examsim-find-simone <<'EOS'
mkdir -p /root/found
find / -xdev \( -path /root/found \) -prune -o -user Simone -type f -exec cp -p {} /root/found/ \;
EOS
lsol examsim-find-strato <<'EOS'
grep strato /usr/share/dict/words > /searchfile
EOS
lsol examsim-autofs-remoteuser2 <<'EOS'
printf '/- /etc/auto.examsim12\n' > /etc/auto.master.d/examsim12.autofs
printf '/home/remoteuser2 -rw,sync workstation.lab.example.com:/ourhome/remoteuser2\n' > /etc/auto.examsim12
systemctl enable --now autofs; systemctl restart autofs
EOS
lsol examsim-user-barry <<'EOS'
useradd -u 2112 barry; echo barry:atenorth | chpasswd
EOS
lsol examsim-script-suid-umask <<'EOS'
printf '#!/bin/bash\nfind /usr -type f -perm -4000 -size +30k -size -50k > /root/myoutput 2>/dev/null\n' > /usr/local/bin/newsearch
chmod +x /usr/local/bin/newsearch; /usr/local/bin/newsearch
echo 'umask 0222' >> /home/alex/.bashrc
EOS
lsol examsim-timer-acl <<'EOS'
dnf -y install logger
printf '#!/bin/bash\necho "$(date) ex200" >> /var/tmp/ex200\nmkdir -p /root/lookup_directory\necho "$(date) ok" >> /root/lookup_directory/ex200\n' > /usr/local/bin/logger
chmod +x /usr/local/bin/logger
printf '[Unit]\nDescription=ex200 logger\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/logger\n' > /etc/systemd/system/logger-ex200.service
printf '[Unit]\nDescription=ex200 logger timer\n[Timer]\nOnCalendar=*-*-* *:*:00\n[Install]\nWantedBy=timers.target\n' > /etc/systemd/system/logger-ex200.timer
systemctl daemon-reload; systemctl enable --now logger-ex200.timer
cp /etc/fstab /var/tmp/fstab; chown root:root /var/tmp/fstab; chmod 644 /var/tmp/fstab
setfacl -m u:natasha:rw,u:harry:--- /var/tmp/fstab
EOS
lsol examsim-script-args <<'EOS'
cat > /usr/local/bin/userinfo <<'EOF2'
#!/bin/bash
[ $# -eq 0 ] && { echo "uso: userinfo usuario..." >&2; exit 1; }
rc=0
for u in "$@"; do
    if id "$u" &>/dev/null; then echo "$u:$(id -u "$u"):$(getent passwd "$u" | cut -d: -f6)"
    else echo "$u: inexistente" >&2; rc=2; fi
done
exit $rc
EOF2
chmod +x /usr/local/bin/userinfo
EOS
lsol examsim-tuned-servera <<'EOS'
# o start remove o tuned; a solucao nao pode depender do repo de outra questao: usa um temporario
printf '[qa-tmp-app]\nname=tmp\nbaseurl=http://content.example.com:8091/rhel10.0/x86_64/dvd/AppStream\nenabled=1\ngpgcheck=0\n[qa-tmp-base]\nname=tmp\nbaseurl=http://content.example.com:8091/rhel10.0/x86_64/dvd/BaseOS\nenabled=1\ngpgcheck=0\n' > /etc/yum.repos.d/qa-tmp.repo
dnf -y install tuned; rm -f /etc/yum.repos.d/qa-tmp.repo
systemctl enable --now tuned; tuned-adm profile throughput-performance
EOS
lsol examsim-tuned <<'EOS'
systemctl enable --now tuned; tuned-adm profile "$(tuned-adm recommend)"
EOS
lsol examsim-rootpw-recover-node2 <<'EOS'
# O procedimento real (rd.break no console) nao e' automatizavel por SSH: aqui so' se aplica o
# resultado, o que valida start/grade/finish mas NAO o procedimento de recuperacao.
echo 'root:atenorth' | chpasswd
EOS
lsol examsim-swap <<'EOS'
P=${D1}1; mkswap $P; swapon $P
echo "UUID=$(blkid -s UUID -o value $P) none swap defaults 0 0" >> /etc/fstab; systemctl daemon-reload
EOS
lsol examsim-lvm-mydatabase <<'EOS'
E=$(parted -sm $D6 unit MiB print | awk -F: '$1 ~ /^[0-9]+$/ {e=$3} END{sub("MiB","",e); print int(e)+1}')
parted -s $D6 mkpart dbpart ${E}MiB $((E+600))MiB; partprobe $D6; udevadm settle
N=$(lsblk -nrpo NAME,TYPE $D6 | awk '$2=="part"' | wc -l); P=${D6}$N
pvcreate -y $P; vgcreate -s 8M myvg $P; lvcreate -y -l 50 -n mydatabase myvg
mkfs.vfat /dev/myvg/mydatabase; mkdir -p /database
echo "/dev/mapper/myvg-mydatabase /database vfat defaults 0 0" >> /etc/fstab; systemctl daemon-reload; mount /database
EOS
lsol examsim-lvm-resize-home <<'EOS'
lvresize -r -l 38 /dev/vg_home/home
EOS
lsol examsim-vgextend <<'EOS'
E=$(parted -sm $D6 unit MiB print | awk -F: '$1 ~ /^[0-9]+$/ {e=$3} END{sub("MiB","",e); print int(e)+1}')
parted -s $D6 mkpart extra ${E}MiB $((E+400))MiB; partprobe $D6; udevadm settle
N=$(lsblk -nrpo NAME,TYPE $D6 | awk '$2=="part"' | wc -l); P=${D6}$N
pvcreate -y $P; vgextend vg_data $P; lvextend -r -L 600M vg_data/lv_data
EOS

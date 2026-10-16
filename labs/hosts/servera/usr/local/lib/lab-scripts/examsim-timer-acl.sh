#!/bin/bash
# Item 15: (a) instalar pacote logger de timer.repo (content.example.com),
# editar /usr/local/bin/logger, criar service+timer systemd. (b) ACL em
# /var/tmp/fstab (copia de /etc/fstab): natasha rw, harry sem acesso,
# demais leitura (atuais e futuros).
set -u
rpm -q logger &>/dev/null && dnf -y remove logger &>/dev/null
rm -f /etc/yum.repos.d/timer.repo
# Units do aluno podem ter qualquer nome com examsim15/logger (o grader aceita
# ambos); sobra de prova anterior deixaria a questao meio resolvida.
for f in /etc/systemd/system/*examsim15*.service /etc/systemd/system/*examsim15*.timer \
         /etc/systemd/system/*logger*.service /etc/systemd/system/*logger*.timer; do
    [ -e "$f" ] || continue
    systemctl disable --now "${f##*/}" &>/dev/null
    rm -f "$f"
done
systemctl daemon-reload 2>/dev/null
rm -f /var/tmp/ex200 /root/lookup_directory/ex200
rm -f /var/tmp/fstab

state=/var/lib/rhcsa-lab/examsim15-created-users
mkdir -p "$(dirname "$state")"
touch "$state"
for u in natasha harry; do
    if ! id "$u" &>/dev/null; then
        useradd -m "$u"
        echo "$u" >> "$state"
    fi
done

cat > /etc/yum.repos.d/timer.repo <<EOF
[timer]
name=timer.repo (item 15)
baseurl=http://content.example.com:8091/timer-repo
enabled=1
gpgcheck=0
EOF

cp /etc/fstab /var/tmp/fstab
chown root:root /var/tmp/fstab
chmod 600 /var/tmp/fstab
setfacl -b /var/tmp/fstab 2>/dev/null

echo "OK: timer.repo criado, natasha/harry garantidos, /var/tmp/fstab recriado sem ACL -- item 15 pronto."

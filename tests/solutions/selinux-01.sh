#!/bin/bash
# Solução de referência para selinux-01 (host: servera). Idempotente.
# Requer o pacote policycoreutils-python-utils (semanage) -- já instalado
# pelo role servera, ver ansible/roles/servera/tasks/main.yml.
set -euo pipefail

mkdir -p /srv/portal-noturno
printf 'Portal Noturno OK\n' > /srv/portal-noturno/index.html

semanage fcontext -l | grep -q '/srv/portal-noturno' \
  || semanage fcontext -a -t httpd_sys_content_t '/srv/portal-noturno(/.*)?'
restorecon -Rv /srv/portal-noturno

semanage port -l | awk '$1=="http_port_t"' | grep -qw 8585 \
  || semanage port -a -t http_port_t -p tcp 8585

setsebool -P httpd_can_network_connect on

cat > /etc/httpd/conf.d/portal-noturno.conf <<'EOF'
Listen 8585
<VirtualHost *:8585>
    DocumentRoot /srv/portal-noturno
    <Directory /srv/portal-noturno>
        Require all granted
    </Directory>
</VirtualHost>
EOF

systemctl enable --now httpd
if systemctl is-active --quiet httpd; then
  systemctl reload httpd
else
  systemctl restart httpd
fi

echo "selinux-01: solução aplicada em $(hostname -s)."

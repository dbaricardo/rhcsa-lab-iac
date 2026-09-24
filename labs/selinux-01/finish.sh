#!/bin/bash
# Ação inversa explícita, nunca reinvoca start.sh. httpd foi instalado só
# para este exercício (nenhum outro lab deste lote depende dele), então a
# reversão completa remove o pacote também.
set -uo pipefail

systemctl stop httpd >/dev/null 2>&1 || true
systemctl disable httpd >/dev/null 2>&1 || true

rm -f /etc/httpd/conf.d/portal-noturno.conf
rm -rf /srv/portal-noturno

semanage port -d -t http_port_t -p tcp 8585 >/dev/null 2>&1 || true
semanage fcontext -d "/srv/portal-noturno(/.*)?" >/dev/null 2>&1 || true
restorecon -R /srv >/dev/null 2>&1 || true

setsebool -P httpd_can_network_connect off >/dev/null 2>&1 || true

dnf remove -y httpd >/dev/null 2>&1 || true

echo "Ambiente de 'selinux-01' limpo em $(hostname -s)."
exit 0

#!/bin/bash
set -u
systemctl stop httpd 2>/dev/null
systemctl disable httpd 2>/dev/null
rm -f /etc/httpd/conf.d/examsim-porta82.conf
rm -f /var/www/html/file1
semanage port -d -t http_port_t -p tcp 82 2>/dev/null
firewall-cmd --permanent --remove-port=82/tcp &>/dev/null
firewall-cmd --reload &>/dev/null
echo "OK: item 4 limpo (httpd parado/desabilitado, porta 82 revertida)."

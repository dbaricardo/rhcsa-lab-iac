#!/bin/bash
# Item 4: httpd deve servir na porta 82 (nao-padrao), sem alterar o
# contexto de /var/www/html. Prepara o cenario quebrado de proposito --
# SELinux/firewall NAO liberam a porta 82 ainda.
set -u
dnf install -y httpd &>/dev/null
mkdir -p /etc/httpd/conf.d
cat > /etc/httpd/conf.d/examsim-porta82.conf <<'EOF'
Listen 82
<VirtualHost *:82>
    DocumentRoot /var/www/html
</VirtualHost>
EOF
echo "conteudo-examsim-item4" > /var/www/html/file1
# A fixture é o problema adicional: o diretório permanece no contexto padrão.
chcon -t user_home_t /var/www/html/file1
semanage port -d -t http_port_t -p tcp 82 2>/dev/null
firewall-cmd --permanent --remove-port=82/tcp &>/dev/null
firewall-cmd --reload &>/dev/null
systemctl stop httpd 2>/dev/null
systemctl disable httpd &>/dev/null
echo "OK: httpd com Listen 82 e file1/user_home_t preparado; serviço, SELinux e firewall ainda precisam ser corrigidos -- item 4 pronto."

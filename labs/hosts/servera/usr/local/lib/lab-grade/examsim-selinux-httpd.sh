#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

curl -s --max-time 3 http://localhost:82/file1 2>/dev/null | grep -q "conteudo-examsim-item4"
check $? "curl http://localhost:82/file1 retorna o conteudo esperado"

semanage port -l 2>/dev/null | grep -E '^http_port_t' | grep -qw 82
check $? "porta 82 associada ao tipo http_port_t no SELinux"

default_ctx=$(matchpathcon -n /var/www/html 2>/dev/null)
current_ctx=$(stat -c %C /var/www/html 2>/dev/null)
[ -n "$default_ctx" ] && [ "$current_ctx" = "$default_ctx" ]
check $? "contexto de /var/www/html permanece o default do policy (esperado: $default_ctx, atual: $current_ctx)"

file_default_type=$(matchpathcon -n /var/www/html/file1 2>/dev/null | cut -d: -f3)
file_current_type=$(stat -c %C /var/www/html/file1 2>/dev/null | cut -d: -f3)
[ -n "$file_default_type" ] && [ "$file_current_type" = "$file_default_type" ]
check $? "tipo SELinux de /var/www/html/file1 retorna ao default do policy (esperado: $file_default_type, atual: $file_current_type)"

systemctl is-enabled httpd &>/dev/null
check $? "httpd habilitado no boot"

systemctl is-active httpd &>/dev/null
check $? "httpd ativo"

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL

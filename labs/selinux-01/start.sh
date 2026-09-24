#!/bin/bash
# Idempotente: garante que o pacote httpd esteja instalado (pré-requisito de
# infraestrutura, não o que está sendo avaliado neste exercício de SELinux).
set -euo pipefail

dnf install -y httpd >/dev/null

echo "Ambiente pronto para 'selinux-01' em $(hostname -s)."
echo "httpd instalado. Configure DocumentRoot/porta/contexto/boolean e rode: lab grade selinux-01"

#!/bin/bash
# Verificacao real acontece do lado cliente (servera); aqui so confirma
# que o export continua de pe.
set -u
grep -q '/ourhome/remoteuser2' /etc/exports 2>/dev/null && exportfs | grep -q remoteuser2
if [ $? -eq 0 ]; then echo 'OK: export /ourhome/remoteuser2 ativo'; echo 'RESULTADO: PASSOU'; exit 0
else echo 'FALHOU: export /ourhome/remoteuser2 ausente'; echo 'RESULTADO: FALHOU'; exit 1; fi

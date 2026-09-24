#!/bin/bash
# Não-destrutivo. Cada host emite seu próprio bloco OK:/FALHOU: + RESULTADO:
# -- o dispatcher da workstation já imprime o banner "==> lab grade ... (host)"
# entre um host e outro, não repita isso aqui.
set -uo pipefail
host="$(hostname -s)"
pass=true

case "$host" in
  servera)
    if [ -d /export/dados-equipe ]; then
      echo "OK: diretório /export/dados-equipe existe"
    else
      echo "FALHOU: diretório /export/dados-equipe não existe"
      pass=false
    fi

    if exportfs -v 2>/dev/null | grep -q '/export/dados-equipe'; then
      echo "OK: /export/dados-equipe está exportado via NFS"
    else
      echo "FALHOU: /export/dados-equipe não está exportado (ver exportfs -v)"
      pass=false
    fi

    if systemctl is-active --quiet nfs-server; then
      echo "OK: serviço nfs-server ativo"
    else
      echo "FALHOU: serviço nfs-server não está ativo"
      pass=false
    fi
    ;;
  serverb)
    if systemctl is-active --quiet autofs; then
      echo "OK: serviço autofs ativo"
    else
      echo "FALHOU: serviço autofs não está ativo"
      pass=false
    fi

    if timeout 10 ls /mnt/dados-equipe/leia-me.txt >/dev/null 2>&1; then
      echo "OK: /mnt/dados-equipe monta sob demanda e contém o arquivo esperado"
    else
      echo "FALHOU: /mnt/dados-equipe não montou o compartilhamento esperado"
      pass=false
    fi

    if mount | grep -q 'servera:/export/dados-equipe'; then
      echo "OK: montagem NFS de servera confirmada em serverb"
    else
      echo "FALHOU: montagem NFS de servera não encontrada em serverb"
      pass=false
    fi
    ;;
  *)
    echo "FALHOU: host desconhecido '$host'"
    pass=false
    ;;
esac

if $pass; then
  echo "RESULTADO: PASSOU"
else
  echo "RESULTADO: FALHOU"
fi
exit 0

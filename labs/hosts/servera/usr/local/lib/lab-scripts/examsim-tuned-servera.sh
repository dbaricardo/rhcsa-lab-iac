#!/bin/bash
# Questao 23 (extra): instalar tuned, habilitar e ativar throughput-performance.
# Sem repositorio no servera ate a questao 3 ser resolvida -- como na prova real,
# instalar exige ter configurado BaseOS/AppStream antes.
set -u
systemctl disable --now tuned &>/dev/null
# rpm -e e nao "dnf remove": o dnf apaga junto as dependencias orfas (hdparm,
# python3-pyudev, perl inteiro via python3-perf...) e o mirror do homelab nao
# as tem -- a questao ficaria impossivel. So o pacote tuned sai.
rpm -e tuned &>/dev/null
rm -rf /etc/tuned/active_profile /etc/tuned/profile_mode
rpm -q tuned &>/dev/null && { echo "ERRO: nao consegui remover o pacote tuned"; exit 1; }
echo "OK: pacote tuned removido do servera -- questao 23 pronta."

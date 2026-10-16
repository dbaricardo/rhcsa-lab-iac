#!/bin/bash
# Devolve o servera ao estado de antes do start: tuned instalado, ativo e no
# perfil recomendado. Instala direto do mirror para nao depender da questao 3.
set -u
MIRROR=http://content.example.com:8091/rhel10.0/x86_64/dvd
if ! rpm -q tuned &>/dev/null; then
    dnf -y --disablerepo='*' --setopt=gpgcheck=0 \
        --repofrompath=examsim23-baseos,$MIRROR/BaseOS \
        --repofrompath=examsim23-appstream,$MIRROR/AppStream \
        install tuned &>/dev/null || { echo "ERRO: nao consegui reinstalar tuned pelo mirror"; exit 1; }
fi
systemctl enable --now tuned &>/dev/null
tuned-adm profile "$(tuned-adm recommend 2>/dev/null)" &>/dev/null
echo "OK: questao 23 limpa (tuned reinstalado no perfil recomendado: $(tuned-adm active 2>/dev/null | sed -n 's/^Current active profile: //p'))."

#!/bin/bash
# Item 16 (node2/serverb): recuperar acesso de root via boot em modo
# single-user/rescue e redefinir a senha para 'atenorth'.
#
# Mesmo padrao do lab oficial 'rootpw-recover' (servera): nenhum estado
# previo em disco -- o proprio cenario (senha esquecida) e reproduzido
# reiniciando a VM e interrompendo o GRUB2 no console da VM (virsh console rhcsa-lab-serverb ou virt-viewer)
# (dominio libvirt rhcsa-lab-serverb). SSH cai durante o procedimento.
echo "Nenhum estado previo necessario -- reinicie a serverb (virsh reboot rhcsa-lab-serverb) e use o console (virsh console rhcsa-lab-serverb ou virt-viewer) pra interromper o GRUB2, entrar em modo rescue/single-user e redefinir a senha de root para 'atenorth'."
echo "ATENCAO: SSH cai durante o procedimento. So volta a responder apos o boot normal terminar."

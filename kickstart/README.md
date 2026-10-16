# Kickstart da imagem golden

`ks.cfg.tpl` é o kickstart usado por `scripts/build-image.sh` para instalar o
RHEL 10 de forma 100% desassistida, direto contra a ISO que você aponta em
`.env` (`RHEL_ISO_PATH`) — sem Packer, sem builder externo.

## Como é renderizado

`scripts/build-image.sh` roda `envsubst` restrito a 3 variáveis (a senha já
convertida para hash SHA-512 antes de entrar no arquivo final — nunca texto
plano):

| Placeholder | Origem |
|---|---|
| `${STUDENT_USER}` | `machines.yaml` → `student.username` |
| `${STUDENT_PASSWORD_HASH}` | hash de `.env` → `STUDENT_PASSWORD` |
| `${STUDENT_SSH_PUBKEY}` | `output/student_key.pub`, gerada pelo próprio script |

O resultado (`ks.cfg` renderizado) fica só em `output/`, que está no
`.gitignore` — nunca é commitado.

## O que o kickstart faz, em ordem

1. Rede via DHCP. Nas VMs finais o IP fixo de cada uma vem de uma reserva
   DHCP na rede libvirt criada pelo Terraform — a imagem golden fica
   agnóstica da topologia, para poder ser clonada 3 vezes.
2. Particiona só o disco de instalação (`autopart --type=lvm --fstype=xfs`).
   Discos extra de storage/LVM são anexados depois pelo Terraform, sempre
   brutos.
3. Cria o usuário `student` (senha vinda de `.env`) com sudo sem senha e a
   chave pública SSH usada pelo Ansible; login root fica bloqueado por senha
   (`rootpw --lock`), igual ao ambiente real.
4. `%post`: importa a 4ª chave GPG de release do RHEL10 (bug conhecido, ver
   `../docs/troubleshooting.md`), habilita os serviços base e zera
   `/etc/machine-id` (mitigação preventiva do bug de SELinux `unlabeled_t`
   em VMs clonadas). **Não** registra a subscription: cada VM é registrada
   depois, individualmente, pelo Ansible (ou por você) — registrar na imagem
   faria as 3 VMs compartilharem a mesma identidade na Red Hat.
5. Termina com `poweroff` (não `reboot`) — `scripts/build-image.sh` usa
   `virt-install --wait -1` esperando o domínio desligar sozinho, de forma
   determinística.

## Testar isoladamente

Se quiser inspecionar só o kickstart sem rodar o pipeline completo:

```bash
export STUDENT_USER=student STUDENT_SSH_PUBKEY="$(cat ~/.ssh/id_ed25519.pub)"
export STUDENT_PASSWORD_HASH="$(openssl passwd -6 'senha-de-teste')"
envsubst '${STUDENT_USER} ${STUDENT_PASSWORD_HASH} ${STUDENT_SSH_PUBKEY}' \
  < ks.cfg.tpl
```

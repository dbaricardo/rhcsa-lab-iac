# Kickstart do box golden

`ks.cfg.tpl` é o kickstart usado por `scripts/build-box.sh` para instalar o
RHEL 10 de forma 100% desassistida, direto contra a ISO que você aponta em
`.env` (`RHEL_ISO_PATH`) — sem Packer, sem builder externo.

## Como é renderizado

`scripts/build-box.sh` roda `envsubst` restrito a 4 variáveis, lidas do
`.env` (a senha já convertida para hash SHA-512 antes de entrar no arquivo
final — nunca texto plano):

| Placeholder | Origem |
|---|---|
| `${RHSM_ORG_ID}` | `.env` → `RHSM_ORG_ID` |
| `${RHSM_ACTIVATION_KEY}` | `.env` → `RHSM_ACTIVATION_KEY` |
| `${STUDENT_USER}` | `machines.yaml` → `student.username` (via `.env`/script) |
| `${STUDENT_PASSWORD_HASH}` | hash de `.env` → `STUDENT_PASSWORD` |

O resultado (`ks.cfg` renderizado) fica só em `output/`, que está no
`.gitignore` — nunca é commitado com credenciais reais.

## O que o kickstart faz, em ordem

1. Rede via DHCP só para a instalação (a topologia real com IP fixo por VM é
   aplicada depois pelo Vagrant/Ansible — o box golden fica agnóstico da
   topologia final, para poder ser clonado 3 vezes).
2. Particiona só o disco de instalação (`autopart --type=lvm --fstype=xfs`).
   Discos extra de storage/LVM são anexados depois pelo Vagrant/libvirt,
   sempre brutos.
3. Cria o usuário `student` (senha vinda de `.env`) com sudo sem senha; login
   root fica bloqueado por senha (`rootpw --lock`), igual ao ambiente real.
4. `%post`: importa a 4ª chave GPG de release do RHEL10 (bug conhecido, ver
   `../docs/troubleshooting.md`), registra a subscription via
   `subscription-manager` com a activation key, habilita os serviços base, e
   zera `/etc/machine-id` (mitigação preventiva do bug de SELinux
   `unlabeled_t` em VMs clonadas).
5. Termina com `poweroff` (não `reboot`) — `scripts/build-box.sh` usa
   `virt-install --wait -1` esperando o domínio desligar sozinho, de forma
   determinística.

## Testar isoladamente

Se quiser inspecionar só o kickstart sem rodar o pipeline completo:

```bash
export RHSM_ORG_ID=... RHSM_ACTIVATION_KEY=... STUDENT_USER=student
export STUDENT_PASSWORD_HASH="$(openssl passwd -6 'senha-de-teste')"
envsubst '${RHSM_ORG_ID} ${RHSM_ACTIVATION_KEY} ${STUDENT_USER} ${STUDENT_PASSWORD_HASH}' \
  < ks.cfg.tpl
```

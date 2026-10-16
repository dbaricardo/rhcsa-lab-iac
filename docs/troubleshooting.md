# Troubleshooting

Bugs reais, encontrados em produção durante o uso deste tipo de ambiente.
Todos já estão **mitigados no código** (kickstart, `image/finalize.sh`,
role `common`), mas ficam documentados aqui porque:

- quem clonar/adaptar este repositório para outra imagem RHEL10 (fora do fluxo
  `scripts/build-image.sh`) pode reintroduzir algum deles;
- é útil entender a causa raiz se o sintoma aparecer mesmo assim.

Formato: problema -> causa -> fix.

## GPG key mismatch / "SIGNATURE: NOT OK" ao instalar qualquer pacote

**Problema:** `dnf install` (ou qualquer operação de pacote) falha com uma
mensagem de assinatura inválida, mesmo em uma instalação limpa do RHEL10.

**Causa:** o RHEL10.0/10.x assina pacotes com uma **4ª chave de release**
da Red Hat, de tipo pós-quântico (key ID `05707a62`), que **não vem
pré-instalada** por padrão no sistema. Sem essa chave importada, o RPM não
consegue validar a assinatura de nenhum pacote novo.

**Fix:**

```bash
rpm --import https://security.access.redhat.com/data/6afedf8f.txt
```

**Onde já está mitigado:** no `%post` do
[`kickstart/ks.cfg.tpl`](../kickstart/ks.cfg.tpl) (importada durante o build
da imagem golden) e, em defesa de profundidade, de novo no role
[`common`](../ansible/roles/common/tasks/main.yml) (para proteger qualquer
imagem RHEL10 genérica que não tenha passado por `scripts/build-image.sh`).

## Enumeração de disco instável (`/dev/sdb`/`/dev/sdc` trocando de ordem)

**Problema:** um exercício que depende de um disco extra específico (por
tamanho, ex.: o disco de 6GB de `serverb`) às vezes resolve o disco errado
entre um boot e outro.

**Causa:** a ordem de enumeração `/dev/sdb`, `/dev/sdc`, etc. **não é
garantida** entre boots — já foi observado invertendo em produção real.
Qualquer script que referencie um nome de disco fixo é frágil por
construção.

**Fix:** nunca referenciar o nome do disco diretamente. Os helpers
`disco_do_so()` e `resolve_disco()` em
[`ansible/roles/lab_common/files/lab-common.sh`](../ansible/roles/lab_common/files/lab-common.sh)
resolvem o disco correto **por tamanho** (com tolerância configurável),
excluindo explicitamente o disco onde está a raiz do sistema. Todo exercício
que precisar de um disco extra deve `source /usr/local/lib/lab-common.sh` e
usar `resolve_disco <tamanho_gb>` — ver
[docs/exercises-authoring-guide.md](exercises-authoring-guide.md).

## VM clonada perdendo rede por SELinux `unlabeled_t`

**Problema:** depois de clonar a imagem golden (é isso que o Terraform faz para
criar `workstation`/`servera`/`serverb`), uma ou mais VMs sobem sem rede
funcional, e **não aparece nenhum AVC** em `ausearch`.

**Causa:** o clone pode deixar arquivos como `/etc/machine-id` (ou perfis de
NetworkManager) com o contexto SELinux `unlabeled_t`. Isso derruba
`journald`, que derruba `dbus`, que derruba o `NetworkManager` em cascata —
uma falha silenciosa do ponto de vista de auditoria padrão. O AVC real só
aparece em:

```bash
dmesg | grep -i avc
```

nunca em `ausearch` (que depende do próprio `auditd`/`journald` estarem
saudáveis para registrar o evento — exatamente o que está quebrado).

**Fix:**

```bash
restorecon -Rv /etc
```

seguido de reboot.

**Onde já está mitigado:** em
[`image/finalize.sh`](../image/finalize.sh) (roda `restorecon -Rv
/etc` offline via `virt-customize`, antes mesmo do primeiro boot de qualquer
clone) e, de novo, como defesa em profundidade idempotente, no role
[`common`](../ansible/roles/common/tasks/main.yml) a cada provisionamento.
O kickstart também zera `/etc/machine-id` (`truncate -s 0`) para forçar a
regeneração correta no primeiro boot de cada clone.

## Anti-padrão: "finish chama start" para limpar

**Problema:** um exercício "limpo" (`lab finish <id>`) deixa o host num
estado inesperado, ou contamina o exercício seguinte.

**Causa:** um `finish.sh` que reinvoca `start.sh` para "resetar" o ambiente.
`start.sh` é **idempotente por contrato** — ele garante que o estado exista,
não que ele seja removido. Reinvocá-lo dentro de `finish.sh` recria o estado
em vez de limpá-lo.

**Fix:** `finish.sh` precisa ser a ação inversa **explícita** do que
`start.sh` fez (se `start.sh` cria um usuário, `finish.sh` remove esse
usuário — nunca chama `start.sh` de novo). Regra não negociável, ver
[docs/exercises-authoring-guide.md](exercises-authoring-guide.md).

## Configuração compartilhada entre exercícios

**Problema:** um exercício passa (ou falha de forma estranha) por causa de
configuração deixada por outro exercício anterior — o exemplo clássico é
`httpd.conf` ou uma porta usada por mais de um exercício de rede/SELinux.

**Causa:** `finish.sh` do exercício anterior não revertia explicitamente a
configuração compartilhada, deixando o host "sujo" para o próximo
exercício.

**Fix:** todo exercício que toca configuração compartilhada precisa
reverter essa configuração especificamente no seu próprio `finish.sh` —
nunca assumir que o próximo exercício vai lidar com o estado deixado.

## `lab start storage-lvm-01` para de encontrar o disco depois de um `finish`

**Problema:** depois de rodar `lab finish storage-lvm-01` uma vez, um `lab
start storage-lvm-01` seguinte falha dizendo que não encontrou um disco de
~6GB livre em `serverb`, mesmo com o disco extra devidamente anexado pelo
Terraform/libvirt.

**Causa:** a versão antiga de `finish.sh` só limpava o PV/LV (via
`pvremove`/`wipefs` no path do PV) depois que o estudante já tinha
particionado o disco. A tabela de partições em si continuava no disco.
`resolve_disco()` (usada por `start.sh`) exige explicitamente um disco
**cru** (sem partições) — com a tabela de partições ainda presente, esse
disco nunca mais era considerado "livre".

**Fix:** `finish.sh` agora também localiza o disco pai por tamanho, via
`disco_por_tamanho()` de `lab-common.sh` (a mesma função que
`filesystems-01/finish.sh` já usava para o mesmo problema), e roda
`wipefs -a` em cada partição e no disco inteiro — não só no PV.

## Limite de sistemas simultâneos da subscription gratuita

**Problema:** `subscription-manager register` (rodado pelo Ansible em cada
VM, ou à mão) falha dizendo que o
limite de sistemas registrados foi atingido.

**Causa:** a **Red Hat Developer Subscription for Individuals** (gratuita)
tem um limite de sistemas simultâneos registrados por conta. Como cada uma
das 3 VMs (`workstation`/`servera`/`serverb`) se registra individualmente
com seu próprio consumer ID — deliberado, ver a seção abaixo — cada ciclo
`make deploy` + `make destroy` consome 3 slots, e slots de VMs já destruídas
continuam contando até serem revogados.

**Fix:** acesse <https://console.redhat.com> com sua conta Red Hat, vá até
a lista de sistemas registrados ("Inventory" / "Systems") e revogue/remova
os sistemas de VMs que você já destruiu (`make destroy`) para liberar
slots. Considere rodar `sudo subscription-manager unregister` em cada VM
antes de `make destroy`, para não depender de fazer essa limpeza depois
pelo console web.

## `make provision` falha com "não está registrado na Red Hat subscription"

**Problema:** o role [`common`](../ansible/roles/common/tasks/main.yml) para
logo no início, antes de qualquer `dnf install`, dizendo que a VM não está
registrada.

**Causa:** `RHSM_ORG_ID`/`RHSM_ACTIVATION_KEY` estão vazias no `.env` e a VM
também não foi registrada à mão. A subscription **nunca** é embutida na
imagem golden (nem no `%post` do kickstart): as 3 VMs clonadas da mesma
imagem compartilhariam o mesmo consumer ID na Red Hat, o que já causou
conflito real. Por isso o registro acontece no Ansible, **uma VM por vez,
depois de clonada** — cada uma ganha identidade própria. Sem as variáveis, o
role confere `subscription-manager identity` e falha cedo com esta
mensagem, em vez de um erro genérico de repositório vazio mais adiante.

**Fix:** preencha no `.env` o Organization ID e a activation key da sua
conta Red Hat Developer (ver [tutorial](tutorial-fim-a-fim.md), passo 2) e
rode `make provision` de novo. Alternativa: registre à mão em cada VM
(`make ssh-workstation`, `make ssh-servera`, `make ssh-serverb`) com

```bash
sudo subscription-manager register --org=<ORG_ID> --activationkey=<ACTIVATION_KEY>
```

e rode `make provision`. Para testar sem conta Red Hat, use `make
deploy-offline` (ver "Modo offline via ISO" abaixo).

## `virt-install` falha no final com "Cannot access storage file... Permission denied"

**Problema:** `make build-image` roda a instalação inteira (baixa `vmlinuz`,
`initrd.img`, começa o boot do instalador) e só falha **no final**, com
`ERROR Cannot access storage file '.../output/<imagem>.qcow2.partial' (as uid:107,
gid:107): Permission denied`.

**Causa:** `qemu:///system` executa o domínio como o usuário de sistema
`qemu` (uid/gid variam, mas nunca é root), mesmo quando você roda
`virt-install`/`build-image.sh` como root ou com sudo. Esse usuário `qemu`
precisa de permissão de **busca** (`x`) em **todo diretório pai**, do `/`
até o arquivo -- tanto o disco de build (`output/<imagem>.qcow2.partial`) quanto a
`RHEL_ISO_PATH`. Isso costuma passar despercebido porque:

- `/root` vem com modo `0700`/`0550` por padrão em praticamente toda
  distribuição -- se você clonar o repositório ali (ex.: testando como
  root), o `qemu` nunca vai conseguir atravessar.
- Em alguns distros, o próprio `$HOME` de um usuário comum também vem sem
  `o+x` por padrão (ex.: Ubuntu Desktop recente).

**Fix:**

```bash
# troque o diretório pelo pai que a mensagem de erro/check-env apontar --
# repita subindo a árvore se o pai também não tiver o bit x para "outros"
setfacl -m u:qemu:--x /caminho/do/diretorio
```

**Onde já está mitigado:** `make check-env` (via `scripts/check-env.sh`)
detecta isso **antes** de gastar tempo com `build-image` -- ele resolve o
caminho absoluto do repositório e de `RHEL_ISO_PATH`, sobe a árvore de
diretórios checando o bit `x` de "outros" (e também reconhece uma ACL
`user:qemu:--x` já aplicada, não só o modo octal tradicional) e aponta
exatamente qual diretório precisa do `setfacl` acima.

## Modo offline via ISO

**O que é:** um caminho alternativo de deploy, `make deploy-offline` (ou só
`make provision-offline`, com as VMs já criadas), que existe **só para testar a infraestrutura sem
gastar um slot de subscription** (ex.: validar este repositório do zero em
CI ou num host descartável) -- não é um substituto do fluxo normal.

**Como funciona:**
[`scripts/offline-repo.sh`](../scripts/offline-repo.sh) monta a DVD ISO
(`RHEL_ISO_PATH`) em modo somente leitura e serve `BaseOS/`/`AppStream/` via
`python3 -m http.server`, só no gateway da rede do lab (`192.168.56.1`, a
interface que o Terraform cria). O role [`common`](../ansible/roles/common/tasks/main.yml)
recebe a variável `lab_offline_repo_url` (passada pelo `Makefile` com `-e`)
e, quando ela está preenchida, aponta
`BaseOS`/`AppStream` para esse HTTP local via `yum_repository`, **pulando
inteiramente** o assert de `subscription-manager identity` -- ele é a forma
explícita de dizer "sem subscription de propósito", não um bug.

**Limitações, de propósito:**

- Sem updates/erratas -- só o conteúdo congelado da ISO no momento do
  download. Não roda `dnf -y update`.
- Não valida o registro real na subscription -- só valida que o resto do
  provisionamento (pacotes, roles, exercícios) funciona.

**Uso:**

```bash
make deploy-offline        # imagem (se faltar) + VMs + Ansible com repos da ISO
# ... quando terminar de testar:
make offline-repo-stop     # para o HTTP e desmonta a ISO (make destroy também para)
```

**Se `RHEL_ISO_PATH` for a boot ISO (netinstall) em vez da DVD ISO
completa**, `scripts/offline-repo.sh` falha cedo dizendo que não encontrou
`BaseOS/repodata`/`AppStream/repodata` -- mesma checagem que `make
check-env` já faz preventivamente (ver `scripts/check-env.sh`).

## `make infra` falha com "unsupported configuration: ... video model 'cirrus'"

**Problema:** a criação dos domínios falha com `domain configuration does
not support video model 'cirrus'`.

**Causa:** o libvirt/QEMU do RHEL/Rocky 10 removeram o modelo de vídeo
`cirrus`, que era o padrão de ferramentas antigas (o `vagrant-libvirt`, que
este projeto usava antes, caía exatamente nisso).

**Onde já está mitigado:** `terraform/main.tf` declara `video { type =
"virtio" }` e `machine = "q35"` (o tipo `pc`/i440fx também está deprecated
nesses hosts). Se adaptar o módulo, mantenha os dois.

## `make build-image` falha com "Unable to find 'bios' firmware"

**Problema:** o `virt-install` baixa `vmlinuz`/`initrd.img` e aborta em
seguida com `operation failed: Unable to find 'bios' firmware that is
compatible with the current configuration`.

**Causa:** `--boot firmware=bios` pede ao libvirt para *autoselecionar* um
firmware BIOS a partir dos descritores JSON em `/usr/share/qemu/firmware/`.
No RHEL/Rocky 10 só o `edk2-ovmf` (UEFI) instala descritores; o `seabios`
não -- então `virsh domcapabilities` lista apenas `efi` e a autoseleção de
BIOS falha, mesmo com o SeaBIOS presente.

**Onde já está mitigado:** `scripts/build-image.sh` passa só `--machine q35`
e **não** passa `--boot`: sem `<os firmware=...>` no XML, o libvirt usa o
SeaBIOS embutido do QEMU (BIOS) em qualquer distro. É o mesmo firmware dos
domínios que o Terraform cria, então a imagem nasce com partição biosboot e
dá boot nas 3 VMs. Não troque para UEFI só na imagem: as VMs não bootariam.

## Sobras de VMs ou volumes depois de um teste interrompido

**Problema:** um deploy interrompido (Ctrl+C, queda do host) deixa domínios
ou volumes `rhcsa-lab-*` no libvirt, e o próximo `make infra` reclama que
algo "already exists".

**Fix:** `make destroy` remove tudo que está no estado do Terraform. Se o
estado se perdeu (`terraform/terraform.tfstate` apagado), limpe à mão:

```bash
for d in $(virsh -c qemu:///system list --all --name | grep '^rhcsa-lab-'); do
  virsh -c qemu:///system destroy "$d"; virsh -c qemu:///system undefine "$d"
done
for v in $(virsh -c qemu:///system vol-list default | awk '/rhcsa-lab-/ {print $1}'); do
  virsh -c qemu:///system vol-delete "$v" default
done
virsh -c qemu:///system net-destroy rhcsa_lab; virsh -c qemu:///system net-undefine rhcsa_lab
```

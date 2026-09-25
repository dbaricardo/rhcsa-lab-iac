# Troubleshooting

Bugs reais, encontrados em produção durante o uso deste tipo de ambiente.
Todos já estão **mitigados no código** (kickstart, `image/box-finalize.sh`,
role `common`), mas ficam documentados aqui porque:

- quem clonar/adaptar este repositório para outro box RHEL10 (fora do fluxo
  `scripts/build-box.sh`) pode reintroduzir algum deles;
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
do box golden) e, em defesa de profundidade, de novo no role
[`common`](../ansible/roles/common/tasks/main.yml) (para proteger qualquer
box RHEL10 genérico que não tenha passado por `scripts/build-box.sh`).

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

**Problema:** depois de clonar o box golden (é isso que o Vagrant faz para
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
[`image/box-finalize.sh`](../image/box-finalize.sh) (roda `restorecon -Rv
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
Vagrant/libvirt.

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

**Problema:** `subscription-manager register` (rodado manualmente em cada
VM, ver [tutorial](tutorial-fim-a-fim.md) passo 8) falha dizendo que o
limite de sistemas registrados foi atingido.

**Causa:** a **Red Hat Developer Subscription for Individuals** (gratuita)
tem um limite de sistemas simultâneos registrados por conta. Como cada uma
das 3 VMs (`workstation`/`servera`/`serverb`) se registra individualmente
com seu próprio consumer ID — deliberado, ver a seção abaixo — cada ciclo
`make up` + `make destroy` consome 3 slots, e slots de VMs já destruídas
continuam contando até serem revogados.

**Fix:** acesse <https://console.redhat.com> com sua conta Red Hat, vá até
a lista de sistemas registrados ("Inventory" / "Systems") e revogue/remova
os sistemas de VMs que você já destruiu (`make destroy`) para liberar
slots. Considere rodar `sudo subscription-manager unregister` em cada VM
antes de `make destroy`, para não depender de fazer essa limpeza depois
pelo console web.

## Subscription não é registrada automaticamente

**Problema:** os roles Ansible (`servera`, `serverb`, `workstation`) falham
em qualquer task `dnf install` com erro de repositório vazio/indisponível.

**Causa:** deliberado — este projeto **não** registra a subscription
automaticamente (nem no `%post` do kickstart, nem via Ansible). Registrar
as 3 VMs clonadas do mesmo box golden com a mesma identidade faria elas
compartilharem o mesmo consumer ID na Red Hat, o que já causou conflito
real em produção. Por isso o role [`common`](../ansible/roles/common/tasks/main.yml)
falha cedo com `subscription-manager identity` antes de qualquer
`dnf install`, com uma mensagem apontando o comando manual.

**Fix:** depois de `make up` (que sobe as VMs com `--no-provision`), entre
em cada uma (`vagrant ssh workstation`/`servera`/`serverb`) e rode:

```bash
sudo subscription-manager register --org=<ORG_ID> --activationkey=<ACTIVATION_KEY>
```

com o Organization ID e a activation key da sua conta Red Hat Developer
(ver [tutorial](tutorial-fim-a-fim.md), passos 2 e 8). Só então rode `make
reprovision`.

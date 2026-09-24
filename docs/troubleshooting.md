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

## Limite de sistemas simultâneos da subscription gratuita

**Problema:** `subscription-manager register` (no `%post` do kickstart, ou
manualmente) falha dizendo que o limite de sistemas registrados foi
atingido.

**Causa:** a **Red Hat Developer Subscription for Individuals** (gratuita)
tem um limite de sistemas simultâneos registrados por conta. Rebuilds
frequentes do box golden (cada build registra um sistema novo) podem
esgotar esse limite.

**Fix:** acesse <https://console.redhat.com> com sua conta Red Hat, vá até
a lista de sistemas registrados ("Inventory" / "Systems") e revogue/remova
um sistema antigo (por exemplo, de um build anterior do box golden que você
já destruiu) para liberar um slot.

# Tutorial fim a fim

Este tutorial assume que você nunca viu este repositório antes. Ele cobre
tudo, do zero: instalar os pré-requisitos no seu computador, conseguir uma
ISO do RHEL 10, construir o ambiente e resolver seu primeiro exercício.

Se você já tem tudo instalado e só quer o resumo rápido, veja o
[README.md](../README.md).

## 1. Pré-requisitos do host

Você precisa de uma máquina Linux com suporte a virtualização de hardware
(VT-x/AMD-V habilitado na BIOS/UEFI). As VMs deste laboratório rodam via
**KVM/libvirt**: o **Terraform** cria a rede, os discos e as VMs, e o
**Ansible** configura tudo dentro delas.

Confirme que a virtualização está disponível antes de instalar qualquer
coisa:

```bash
grep -E 'vmx|svm' /proc/cpuinfo | head -1
```

Se não retornar nada, habilite VT-x/AMD-V na BIOS/UEFI antes de continuar.

### Fedora / RHEL / CentOS Stream / Rocky (dnf)

```bash
sudo dnf install -y @virtualization libvirt libvirt-daemon-kvm \
  virt-install guestfs-tools qemu-img ansible-core gettext python3 \
  python3-pyyaml openssh-clients xorriso

sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt "$USER"
```

> O pacote que fornece `virt-customize` mudou de nome no RHEL/Rocky 10:
> `guestfs-tools` (não mais `libguestfs-tools`, nome usado em versões
> anteriores e ainda válido em Fedora/CentOS Stream mais recentes -- se
> `guestfs-tools` não existir no seu repositório, tente `libguestfs-tools`).

Instale o Terraform a partir do repositório oficial da HashiCorp:

```bash
sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf install -y terraform
```

(Em RHEL/Rocky, troque `fedora` por `RHEL` na URL do repofile.)

### Debian / Ubuntu (apt)

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
  virtinst libguestfs-tools qemu-utils ansible gettext-base python3 \
  python3-yaml openssh-client xorriso

sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt,kvm "$USER"
```

Instale o Terraform a partir do repositório oficial da HashiCorp:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
```

### Nas duas distribuições

Depois de instalar, **saia e entre de novo na sessão** (ou rode `newgrp
libvirt`) para o grupo `libvirt` (e `kvm`, no Debian/Ubuntu) fazer efeito.

Instale as collections Ansible usadas pelos roles (não vêm no
`ansible-core`):

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

O provider do Terraform para libvirt (`dmacvicar/libvirt`) **não** precisa
ser instalado à mão: o `make deploy` roda `terraform init`, que o baixa
sozinho na primeira vez.

Confirme que o libvirt está acessível para o seu usuário:

```bash
virsh -c qemu:///system list
```

Se retornar uma lista vazia sem erro, está tudo certo.

## 2. Conta Red Hat Developer + activation key

Este laboratório usa RHEL 10 real, registrado com uma **Red Hat Developer
Subscription for Individuals** (gratuita).

1. Crie (ou use) uma conta em <https://developers.redhat.com/> — a inscrição
   é gratuita.
2. Acesse <https://console.redhat.com/insights/connector/activation-keys>
   com essa conta.
3. Crie uma **activation key** nova (ou use uma existente). Anote:
   - o **nome/valor da activation key**;
   - o **Organization ID** da sua conta (aparece na mesma página, ou em
     `console.redhat.com` -> ícone de perfil -> "My User Access" /
     "Account settings").

Os dois vão para o `.env` no passo 4. O Ansible registra **cada VM
individualmente, depois de clonada** — nunca a imagem golden. Isso é
deliberado: se a imagem já saísse registrada, as 3 VMs clonadas
compartilhariam o mesmo consumer ID na Red Hat (já causou conflito real).

Sem conta Red Hat? Dá para testar a infraestrutura com `make
deploy-offline` (passo 7), que serve os pacotes a partir da própria ISO.

## 3. Baixar a ISO do RHEL 10

Baixe a ISO **DVD, x86_64** do RHEL 10 na página oficial de downloads da sua
conta Red Hat:

<https://access.redhat.com/downloads/content/rhel>

(faça login com a mesma conta Red Hat Developer do passo 2). Este
repositório **nunca** baixa, inclui ou redistribui a ISO por você — anote o
caminho local completo do arquivo baixado, você vai precisar dele no próximo
passo.

## 4. Clonar o repositório e configurar `.env`

```bash
git clone <url-deste-repositorio> rhcsa-lab-iac
cd rhcsa-lab-iac
cp .env.example .env
```

Edite `.env` e preencha:

| Variável | Valor |
|---|---|
| `RHEL_ISO_PATH` | Caminho absoluto da ISO baixada no passo 3 |
| `RHSM_ORG_ID` | Organization ID anotado no passo 2 |
| `RHSM_ACTIVATION_KEY` | Activation key anotada no passo 2 |
| `STUDENT_PASSWORD` | Senha do usuário `student` nas VMs (uso local apenas) |
| `APPLY_SECURITY_UPDATES` | `false` (padrão, build mais rápido) ou `true` |

`RHSM_ORG_ID` e `RHSM_ACTIVATION_KEY` podem ficar vazias se você for usar
só o modo offline (`make deploy-offline`).

`.env` nunca é commitado (está no `.gitignore`) — pode conter suas
credenciais reais com segurança.

## 5. `make check-env`

```bash
make check-env
```

Esse comando valida, em modo relatório (não para no primeiro erro): binários
necessários (`virt-install`, `virt-customize`, `qemu-img`, `virsh`,
`terraform`, `ansible`, `envsubst`, `python3`, `ssh-keygen`, `xorriso`),
presença de `/dev/kvm`, acesso a `qemu:///system`, o storage pool `default`
do libvirt e todas as variáveis do `.env` (incluindo se `RHEL_ISO_PATH` de
fato existe no disco).

Só avance quando a saída terminar com `Tudo certo. Pode seguir com 'make
deploy'`. Se algo falhar, a própria saída indica o comando de correção.

## 6. `make deploy`

```bash
make deploy
```

Um único comando, sem interação, que encadeia três etapas:

1. **Imagem golden** (`make build-image`, só se `output/` ainda não tiver a
   imagem):
   - gera um par de chaves SSH novo em `output/student_key` (nunca
     commitado), usado pelo Ansible e pelos atalhos `make ssh-*`;
   - renderiza o kickstart (`kickstart/ks.cfg.tpl`) com as variáveis do
     `.env` e a chave pública (a senha entra como hash SHA-512, nunca em
     texto plano);
   - cria um disco qcow2 e roda `virt-install` contra a sua ISO, injetando
     o kickstart — instalação 100% desassistida, que termina com
     `poweroff`;
   - roda um sysprep leve offline (`image/finalize.sh`, via
     `virt-customize`): remove chaves SSH de host, limpa logs (incluindo
     `anaconda-ks.cfg`, que carrega o hash da senha), corrige contexto
     SELinux.
2. **Infraestrutura** (`make infra`): `terraform apply` cria a rede NAT
   `192.168.56.0/24`, os discos (clones copy-on-write da imagem golden + discos
   extras da `serverb`) e as 3 VMs, cada uma com IP estático conforme
   `machines.yaml`, e gera o inventário do Ansible em
   `output/inventory.yml`.
3. **Configuração** (`make provision`): o playbook `ansible/site.yml`
   registra cada VM na subscription, cria o usuário `student`, configura o
   SSH cruzado entre as VMs, instala os pacotes de cada papel, os
   exercícios atribuídos a cada host e o dashboard web na `workstation`.

**Tempo estimado:** na primeira vez, entre 15 e 30 minutos — a maior parte
é a instalação desassistida do RHEL (10 a 20 minutos). Nas vezes seguintes,
com a imagem já pronta, só as etapas 2 e 3 rodam (poucos minutos).

O que esperar no terminal: linhas `==> ...` marcando cada etapa da imagem,
a saída do `terraform apply` e, por fim, a saída do Ansible task a task. O
`make deploy` termina chamando `make status`, que lista as VMs e imprime a
URL do dashboard.

Se algo falhar, cada etapa pode ser rodada de novo isoladamente (`make
build-image`, `make infra`, `make provision`) — o Terraform e o Ansible são
idempotentes, então reaplicar não duplica nada.

## 7. Modo offline (opcional, sem subscription)

Para testar a infraestrutura sem gastar um slot de subscription:

```bash
make deploy-offline
```

É o mesmo fluxo do passo 6, mas o Ansible não registra as VMs: os pacotes
vêm da própria DVD ISO, servida por HTTP a partir do host. Não é um
substituto de produção (sem updates/erratas) — ver
[docs/troubleshooting.md](troubleshooting.md#modo-offline-via-iso).

## 8. Conferir o acesso às VMs

```bash
make status
```

Deve listar `rhcsa-lab-workstation`, `rhcsa-lab-servera` e
`rhcsa-lab-serverb` em estado `running`, seguido da URL do dashboard.

Entre na `workstation`:

```bash
make ssh-workstation
```

Dentro dela, liste o catálogo de exercícios:

```bash
lab list
```

Isso deve imprimir a lista de exercícios disponíveis (número, id, host(s),
título). Se `lab list` falhar ou vier vazia, confirme que o Ansible rodou
até o fim sem erros (`make provision` de novo mostra o que falta).

Saia da sessão SSH (`exit` ou `Ctrl+D`) quando terminar. Os atalhos `make
ssh-servera` e `make ssh-serverb` funcionam da mesma forma.

## 9. Acessar o dashboard

A URL impressa pelo `make status` é, por padrão:

```
http://192.168.56.10:8421
```

Abra essa URL no navegador do seu host (a máquina onde você rodou `make
deploy`, não dentro de nenhuma VM). Você deve ver a lista de exercícios e o
status de progresso de cada um (inicialmente, todos pendentes).

Se a página não carregar, confirme a origem permitida em `machines.yaml` ->
`dashboard.allowed_source` — por padrão é a própria rede privada do lab
(`192.168.56.0/24`), que já inclui a interface do libvirt no seu host.

## 10. Resolver um exercício de ponta a ponta

Vamos usar `users-groups-01` como exemplo — um exercício simples, de um
único host (`servera`).

Tudo começa e termina na `workstation`:

```bash
make ssh-workstation
lab start users-groups-01
```

Isso prepara o ambiente do exercício em `servera` (o dispatcher `lab`
resolve automaticamente qual host usar, olhando o catálogo). A saída mostra
`==> lab start users-groups-01 (servera)` seguido do resultado.

Agora resolva o exercício de verdade. De dentro da própria `workstation`
(como no exame), entre na `servera`:

```bash
ssh servera
```

(ou, a partir do seu host, `make ssh-servera`). Leia as instruções do
exercício no dashboard e resolva com os comandos reais do RHEL
(`useradd`, `groupadd`, `chage`, etc. — para este exercício específico).
Quando terminar, saia da `servera`.

De volta na `workstation`, avalie o resultado:

```bash
lab grade users-groups-01
```

A saída mostra uma linha `OK:`/`FALHOU:` por critério avaliado, terminando
com `RESULTADO: PASSOU` ou `RESULTADO: FALHOU`. Rode `lab grade` quantas
vezes quiser — é uma operação somente leitura, não altera nada.

Atualize o dashboard no navegador (passo 9): o exercício `users-groups-01`
deve aparecer com o resultado mais recente.

Quando terminar de estudar esse exercício, limpe o ambiente:

```bash
lab finish users-groups-01
```

Isso reverte explicitamente o que `lab start` preparou (nunca reinvoca
`start.sh` para isso — ver [troubleshooting.md](troubleshooting.md)),
deixando `servera` pronta para o próximo exercício.

## 11. `make destroy`

Antes de destruir, se sua subscription gratuita tiver poucos slots, libere-os
primeiro (opcional, mas evita ter que limpar depois pelo console web):

```bash
for h in workstation servera serverb; do
  bash scripts/lab-ssh.sh "$h" 'sudo subscription-manager unregister' || true
done
```

Quando terminar a sessão de estudo:

```bash
make destroy
```

Isso roda `terraform destroy`: remove as 3 VMs, os discos e a rede do lab —
nada fica para trás no libvirt. **A imagem golden em `output/` não é
removida**, então da próxima vez basta `make deploy` de novo, que pula a
construção da imagem e só recria VMs + Ansible. Para recomeçar com uma
imagem base nova, rode `make build-image` antes.

## Onde ir depois

- [docs/architecture.md](architecture.md) — como as peças se encaixam e por
  quê.
- [docs/troubleshooting.md](troubleshooting.md) — bugs conhecidos, caso
  encontre algum sintoma parecido.
- [docs/exercises-authoring-guide.md](exercises-authoring-guide.md) — como
  escrever seus próprios exercícios em `labs/`.
- [docs/rocky-linux-fallback.md](rocky-linux-fallback.md) — se quiser testar
  a infraestrutura sem uma ISO RHEL.
- [NOTICE.md](../NOTICE.md) / [docs/copyright-notice.md](copyright-notice.md)
  — contexto sobre direitos autorais e o que este repositório
  deliberadamente não inclui.

# Tutorial: do zero ao primeiro exercício resolvido

Neste tutorial você vai montar o laboratório RHCSA no seu computador e
resolver um exercício de ponta a ponta. Não precisa conhecer este
repositório, Terraform nem Ansible: siga os passos na ordem.

No fim você terá:

- três VMs RHEL 10 (`workstation`, `servera`, `serverb`) rodando;
- o dashboard de progresso aberto no navegador;
- o exercício `examsim-grupos` resolvido e corrigido, e o caminho para as
  provas completas (`examsim-full`, `examsim-dinamico`).

Tempo total: cerca de 1 hora, a maior parte esperando a instalação do RHEL.

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
  python3-pyyaml openssh-clients xorriso openssl

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
  python3-yaml openssh-client xorriso openssl

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

Os dois vão para o `.env` no passo 4. O deploy registra cada VM sozinho
([por que cada VM, e não a imagem](../explanation/arquitetura.md#subscription-e-modo-offline)).

Sem conta Red Hat? Siga o tutorial mesmo assim e, no passo 6, use `make
deploy-offline` no lugar de `make deploy`.

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
| `LAB_ROOT_PASSWORD` | Opcional: senha de root das VMs (login de console) |

As demais (`FLATPAK_MIRROR_ENABLED`, `RHCSA_RECORDING_ENABLED`,
`AI_REVIEW_*`) podem ficar no padrão — ver
[Configuração](../reference/configuracao.md).

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

Um único comando, sem interação. Ele vai, nesta ordem:

1. instalar o RHEL 10 da sua ISO numa imagem base (só na primeira vez);
2. criar a rede e as 3 VMs a partir dessa imagem (Terraform);
3. configurar as VMs (Ansible): subscription, rede e pacotes iguais ao lab
   de referência, o "classroom" na workstation (mirror de pacotes e
   flatpak), exercícios, provas e dashboard — e, no fim, desabilitar todos
   os repositórios, porque os exercícios de repositório partem do zero.

Quer saber o que acontece em cada etapa? Leia depois a
[Arquitetura](../explanation/arquitetura.md) e a
[Imagem golden](../explanation/imagem-golden.md) — não é preciso agora.

**Tempo estimado:** na primeira vez, entre 30 e 60 minutos — a instalação
desassistida do RHEL (10 a 20 minutos) e o download do mirror flatpak
(~1,6 GB) são as partes longas. Nas vezes seguintes, com a imagem pronta,
só as etapas 2 e 3 rodam.

O que esperar no terminal: linhas `==> ...` marcando cada etapa da imagem,
a saída do `terraform apply` e, por fim, a saída do Ansible task a task. O
`make deploy` termina chamando `make status`, que lista as VMs e imprime a
URL do dashboard.

Se algo falhar, rode `make check-env` e veja
[Resolver problemas](../how-to/resolver-problemas.md). Depois de corrigir,
rodar `make deploy` de novo é seguro: ele continua de onde parou.

## 7. Conferir o acesso às VMs

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

Isso deve imprimir os 25 exercícios `examsim-*` com o(s) host(s) de cada um
(as provas `examsim-full` e `examsim-dinamico` aparecem no dashboard). Se `lab list` falhar ou vier vazia, confirme que o Ansible rodou
até o fim sem erros (`make provision` de novo mostra o que falta).

Saia da sessão SSH (`exit` ou `Ctrl+D`) quando terminar. Os atalhos `make
ssh-servera` e `make ssh-serverb` funcionam da mesma forma.

## 8. Acessar o dashboard

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

## 9. Resolver um exercício de ponta a ponta

Vamos usar `examsim-grupos` como exemplo — um exercício simples, de um
único host (`servera`).

Tudo começa e termina na `workstation`:

```bash
make ssh-workstation
lab start examsim-grupos
```

Isso prepara o ambiente do exercício em `servera` (o dispatcher `lab` sabe
qual host usar). A saída mostra `==> start examsim-grupos em servera`
seguido de `==> Pronto.`.

Agora resolva o exercício de verdade. De dentro da própria `workstation`
(como no exame), entre na `servera`:

```bash
ssh servera
```

(ou, a partir do seu host, `make ssh-servera`). Leia as instruções do
exercício no dashboard e resolva com os comandos reais do RHEL
(`groupadd`, `useradd`, `usermod -aG`, `passwd`… — para este exercício).
Quando terminar, saia da `servera`.

De volta na `workstation`, avalie o resultado:

```bash
lab grade examsim-grupos
```

A saída mostra uma linha `OK:`/`FALHOU:` por critério avaliado, terminando
com `RESULTADO: PASSOU` ou `RESULTADO: FALHOU`. Rode `lab grade` quantas
vezes quiser — é uma operação somente leitura, não altera nada.

Atualize o dashboard no navegador (passo 8): o exercício `examsim-grupos`
deve aparecer com o resultado mais recente.

Quando terminar de estudar esse exercício, limpe o ambiente:

```bash
lab finish examsim-grupos
```

O `finish` avalia mais uma vez e depois desfaz o que o `lab start` preparou
e o que você criou, deixando a `servera` pronta para o próximo exercício.

Quando estiver pronto para uma prova inteira, use `lab start examsim-full`
(24 questões fixas) ou `lab start examsim-dinamico` (24 sorteadas). As duas
só dão nota no `lab finish` (`Nota X/24`, aprovação com 17) e o enunciado
fica em `~/examsim-full/` ou `~/examsim-dinamico/` e no dashboard.

## 10. Desligar o lab

Antes de destruir, libere as vagas da sua subscription gratuita (se usou
`make deploy-offline`, pule este comando):

```bash
for h in workstation servera serverb; do
  bash scripts/lab-ssh.sh "$h" 'sudo subscription-manager unregister' || true
done
```

Quando terminar a sessão de estudo:

```bash
make destroy
```

Isso remove as 3 VMs, os discos e a rede. A imagem base fica guardada em
`output/`: da próxima vez, `make deploy` leva poucos minutos.

## Pronto

Você montou o lab do zero e resolveu um exercício completo. Daqui em
diante:

- **Estudar:** `lab list` mostra todos os exercícios
  ([catálogo](../reference/catalogo-exercicios.md)); o ciclo é sempre
  `lab start` → resolver → `lab grade` → `lab finish`.
- **Operar o lab** (religar, reaplicar, recriar):
  [guia de operação](../how-to/operar-o-lab.md).
- **Algo quebrou:** [Resolver problemas](../how-to/resolver-problemas.md).
- **Entender como funciona:** [Arquitetura](../explanation/arquitetura.md).
- **Escrever seus exercícios:** [Criar um exercício](../how-to/criar-exercicio.md).
- Índice completo da documentação: [docs/README.md](../README.md).

# Referência: alvos do `Makefile`

Todos os comandos rodam na raiz do repositório, no host libvirt. `make help`
imprime esta mesma lista de forma resumida.

O `Makefile` carrega o `.env` (se existir) e exporta suas variáveis para os
scripts, o Terraform e o Ansible — ver [configuração](configuracao.md).

## Deploy

| Alvo | O que faz | Pré-requisito | Idempotente |
|---|---|---|---|
| `deploy` | `build-image` (só se a imagem não existir) → `infra` → `provision` → `status` | `.env` com `RHSM_*` (ou VMs registradas à mão) | sim |
| `deploy-offline` | Igual a `deploy`, mas com `provision-offline` (sem subscription) | DVD ISO em `RHEL_ISO_PATH` | sim |
| `build-image` | Roda `check-env` e (re)constrói a imagem golden com `scripts/build-image.sh`. **Sempre reconstrói**, mesmo que a imagem exista | ISO, `.env` | — (sobrescreve) |
| `infra` | `catalog` + `terraform init` + `terraform apply -auto-approve`: rede, volumes, 3 domínios e `output/inventory.yml` | imagem em `output/` | sim |
| `provision` | `catalog` + `ansible-playbook -i output/inventory.yml ansible/site.yml` | VMs no ar (`infra`) | sim |
| `provision-offline` | `scripts/offline-repo.sh start` + playbook com `-e lab_offline_repo_url=http://<gateway>:8080` | VMs no ar, DVD ISO | sim |

## Operação

| Alvo | O que faz |
|---|---|
| `status` | Lista os domínios `rhcsa-lab-*` (`virsh list --all`) e imprime a URL do dashboard (output `dashboard_url` do Terraform) |
| `ssh-workstation`, `ssh-servera`, `ssh-serverb` | Shell interativo como `student`, via `scripts/lab-ssh.sh` |
| `destroy` | `offline-repo-stop` + `terraform destroy -auto-approve` + remove `output/inventory.yml`. **Mantém** a imagem golden |
| `offline-repo-stop` | Para o HTTP do modo offline e desmonta a ISO |

## Desenvolvimento

| Alvo | O que faz |
|---|---|
| `check-env` | Valida binários, `/dev/kvm`, acesso a `qemu:///system`, pool `default`, `.env`, DVD ISO e permissões do usuário `qemu`. Modo relatório: lista todos os problemas, não para no primeiro |
| `catalog` | Gera `labs/catalog.json` a partir de `labs/*/meta.json` (`scripts/build-catalog.py`) |
| `lint` | `terraform fmt -check` + `terraform validate` + `ansible-lint` + `shellcheck` |
| `test-dashboard` | Suíte `pytest` do backend do dashboard |

## Arquivos gerados (todos em `output/`, fora do git)

| Arquivo | Gerado por | Uso |
|---|---|---|
| `rhel10-rhcsa-base.qcow2` | `build-image` | Disco base das 3 VMs |
| `rhel10-rhcsa-base.qcow2.partial` | `build-image` (durante) | Build em andamento; renomeado só no fim |
| `student_key`, `student_key.pub` | `build-image` (1ª vez) | SSH do Ansible e de `make ssh-*` |
| `ks.cfg` | `build-image` | Kickstart renderizado |
| `inventory.yml` | `infra` (Terraform) | Inventário do Ansible |
| `acceptance-*.log`, `acceptance-tN.out` | `tests/acceptance/run-all.sh` | Logs da homologação |

O estado do Terraform fica em `terraform/terraform.tfstate` (também fora do
git).

## Veja também

- [Configuração](configuracao.md) — variáveis que esses alvos leem
- [Resolver problemas](../how-to/resolver-problemas.md) — quando um alvo falha

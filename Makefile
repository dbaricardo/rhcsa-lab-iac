SHELL := /bin/bash
.DEFAULT_GOAL := help

ifneq (,$(wildcard .env))
include .env
export
endif

IMAGE_NAME  := $(shell python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['image'])")
IMAGE       := output/$(IMAGE_NAME).qcow2
INVENTORY   := output/inventory.yml
TF          := terraform -chdir=terraform
PLAYBOOK    := ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i $(INVENTORY) ansible/site.yml
OFFLINE_URL := http://$(shell python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['network']['gateway'])"):8080

.PHONY: help check-env catalog build-image infra provision provision-offline \
	deploy deploy-offline status destroy offline-repo-stop \
	ssh-workstation ssh-servera ssh-serverb ai-reviewer lint test-dashboard

help: ## Lista os targets disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

deploy: $(IMAGE) infra provision ## TUDO: imagem (se faltar) + VMs (Terraform) + Ansible, com subscription
	@$(MAKE) --no-print-directory status

deploy-offline: $(IMAGE) infra provision-offline ## TUDO sem subscription (repos da ISO, modo teste)
	@$(MAKE) --no-print-directory status

check-env: ## Valida .env, libvirt, terraform, virt-install, ansible
	@bash scripts/check-env.sh

catalog: ## Valida labs/catalog.json (27 entradas, escrito à mão como no homelab)
	@python3 scripts/build-catalog.py

$(IMAGE):
	@bash scripts/check-env.sh
	@bash scripts/build-image.sh

build-image: check-env ## (Re)constrói a imagem golden RHEL10 via virt-install + kickstart
	@bash scripts/build-image.sh

infra: catalog ## Cria/atualiza rede, discos e as 3 VMs via Terraform (sem Ansible)
	@test -f $(IMAGE) || { echo "ERRO: $(IMAGE) não existe -- rode 'make build-image'." >&2; exit 1; }
	@$(TF) init -input=false
	@$(TF) apply -input=false -auto-approve

# Nos dois modos a ISO é servida pelo host: é dela que o role `classroom`
# monta o mirror parcial BaseOS/AppStream de content.example.com:8091.
provision: catalog ## Roda o Ansible (registra a subscription se RHSM_* estiver no .env)
	@bash scripts/offline-repo.sh start
	@$(PLAYBOOK) -e lab_iso_url=$(OFFLINE_URL)

provision-offline: catalog ## Roda o Ansible SEM subscription (repos servidos da ISO)
	@bash scripts/offline-repo.sh start
	@$(PLAYBOOK) -e lab_offline_repo_url=$(OFFLINE_URL) -e lab_iso_url=$(OFFLINE_URL)

ai-reviewer: ## Liga a revisão por IA usando este host como revisor (Claude CLI ou API OpenAI-compatível)
	@bash scripts/setup-ai-reviewer.sh $(MODE)

status: ## Mostra o estado das VMs e a URL do dashboard
	@virsh -c qemu:///system list --all | grep -E 'Id|---|rhcsa-lab' || true
	@echo ""
	@$(TF) output -raw dashboard_url 2>/dev/null | sed 's/^/Dashboard: /' && echo "" || \
		echo "Sem estado do Terraform ainda -- rode 'make deploy'."

destroy: offline-repo-stop ## Destrói as 3 VMs, discos e rede (mantém a imagem golden)
	@$(TF) init -input=false >/dev/null
	@$(TF) destroy -input=false -auto-approve
	@rm -f $(INVENTORY)

offline-repo-stop: ## Para o servidor HTTP do modo offline e desmonta a ISO
	@bash scripts/offline-repo.sh stop

ssh-workstation: ## SSH na workstation
	@bash scripts/lab-ssh.sh workstation

ssh-servera: ## SSH na servera
	@bash scripts/lab-ssh.sh servera

ssh-serverb: ## SSH na serverb
	@bash scripts/lab-ssh.sh serverb

lint: ## terraform fmt/validate + ansible-lint + shellcheck
	@$(TF) fmt -check -recursive
	@$(TF) init -backend=false -input=false >/dev/null && $(TF) validate
	@ansible-lint ansible/ || true
	@find labs scripts image tests ansible/roles -name '*.sh' -print0 | xargs -0 shellcheck -S warning || true

test-dashboard: ## Roda a suíte de testes do dashboard portado
	@cd ansible/roles/dashboard/files && python3 -m pytest tests -v

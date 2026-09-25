SHELL := /bin/bash
.DEFAULT_GOAL := help

ifneq (,$(wildcard .env))
include .env
export
endif

.PHONY: help check-env build-box up status destroy reprovision \
	reprovision-offline offline-repo-stop \
	ssh-workstation ssh-servera ssh-serverb lint catalog test-dashboard

help: ## Lista os targets disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

check-env: ## Valida .env, libvirt, vagrant-libvirt, virt-install, ansible
	@bash scripts/check-env.sh

catalog: ## Gera labs/catalog.json a partir de labs/*/meta.json
	@python3 scripts/build-catalog.py

build-box: check-env ## Constrói o box RHEL10 golden via virt-install + kickstart
	@bash scripts/build-box.sh

up: catalog ## Sobe as 3 VMs SEM provisionar (registre a subscription e rode 'make reprovision')
	@vagrant up --no-provision
	@echo ""
	@echo "VMs no ar, ainda SEM Ansible. Registre a subscription manualmente"
	@echo "em cada uma (workstation/servera/serverb) -- ver"
	@echo "docs/tutorial-fim-a-fim.md, passo 8 -- e então rode 'make reprovision'."

status: ## Mostra o estado das VMs e a URL do dashboard
	@vagrant status
	@echo ""
	@echo "Dashboard: http://$$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['machines'][yaml.safe_load(open('machines.yaml'))['dashboard']['host']]['ip'])"):$$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['dashboard']['port'])")"

reprovision: catalog ## Roda o Ansible novamente sem recriar as VMs
	@vagrant provision

reprovision-offline: catalog ## Roda o Ansible SEM subscription real (modo teste, ver docs/troubleshooting.md)
	@bash scripts/offline-repo.sh start
	@LAB_OFFLINE_REPO_URL="http://192.168.56.1:8080" vagrant provision

offline-repo-stop: ## Para o servidor HTTP do modo offline e desmonta a ISO
	@bash scripts/offline-repo.sh stop

destroy: ## Destroi as 3 VMs (não remove o box)
	@vagrant destroy -f

ssh-workstation: ## SSH na workstation
	@vagrant ssh workstation

ssh-servera: ## SSH na servera
	@vagrant ssh servera

ssh-serverb: ## SSH na serverb
	@vagrant ssh serverb

lint: ## ansible-lint + shellcheck em roles e labs
	@ansible-lint ansible/ || true
	@shellcheck labs/*/*.sh scripts/*.sh image/*.sh || true

test-dashboard: ## Roda a suíte de testes do dashboard portado
	@cd ansible/roles/dashboard/files && python3 -m pytest tests -v

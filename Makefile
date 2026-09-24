SHELL := /bin/bash
.DEFAULT_GOAL := help

ifneq (,$(wildcard .env))
include .env
export
endif

.PHONY: help check-env build-box up status destroy reprovision \
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

up: catalog ## Sobe as 3 VMs e roda o Ansible (vagrant up)
	@vagrant up

status: ## Mostra o estado das VMs e a URL do dashboard
	@vagrant status
	@echo ""
	@echo "Dashboard: http://$$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['machines'][yaml.safe_load(open('machines.yaml'))['dashboard']['host']]['ip'])"):$$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['dashboard']['port'])")"

reprovision: catalog ## Roda o Ansible novamente sem recriar as VMs
	@vagrant provision

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

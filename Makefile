.DEFAULT_GOAL := help
.PHONY: help tools lint iso bootstrap check apply plan secrets
ANSIBLE := cd metal/ansible && ANSIBLE_CONFIG=$$PWD/ansible.cfg mise exec --
TOFU := mise exec -- metal/tofu/run.sh

help: ## Show targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "}{printf "  %-12s %s\n",$$1,$$2}'

tools: ## Install pinned toolchain + git hooks
	mise trust && mise install
	mise exec -- pre-commit install

lint: ## Run every linter + secret scan (same as CI)
	mise exec -- pre-commit run --all-files
	mise exec -- gitleaks git --redact --no-banner

iso: ## Build the Proxmox auto-install ISO -> metal/proxmox/out/
	mise exec -- metal/proxmox/build-iso.sh

bootstrap: ## First-time Proxmox host setup over LAN (afterwards CI applies changes)
	$(ANSIBLE) ansible-galaxy collection install -r requirements.yml
	$(ANSIBLE) ansible-playbook playbooks/pve.yml

check: ## Dry run everything CI would apply: ansible --check --diff + tofu plan
	$(ANSIBLE) ansible-galaxy collection install -r requirements.yml
	$(ANSIBLE) ansible-playbook playbooks/pve.yml --check --diff
	$(TOFU) init -input=false
	$(TOFU) plan -input=false

plan: ## tofu plan only
	$(TOFU) init -input=false
	$(TOFU) plan -input=false

apply: ## Apply ansible + tofu (CI does this on merge to main; never run it while CI does)
	$(ANSIBLE) ansible-galaxy collection install -r requirements.yml
	$(ANSIBLE) ansible-playbook playbooks/pve.yml
	$(TOFU) init -input=false
	$(TOFU) apply -input=false -auto-approve

secrets: ## Edit metal/secrets.sops.yaml in $$EDITOR
	mise exec -- sops metal/secrets.sops.yaml

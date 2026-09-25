.DEFAULT_GOAL := help
.PHONY: help tools lint

help: ## Show targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "}{printf "  %-12s %s\n",$$1,$$2}'

tools: ## Install pinned toolchain + git hooks
	mise trust && mise install
	mise exec -- pre-commit install

lint: ## Run every linter + secret scan (same as CI)
	mise exec -- pre-commit run --all-files
	mise exec -- gitleaks git --redact --no-banner

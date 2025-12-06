# Makefile for Data Processor Infrastructure Management
# Usage: make <target>

.PHONY: help init plan apply destroy test clean format validate

# Variables
PROJECT_ID ?= your-gcp-project-id
REGION ?= us-central1
ENV ?= dev

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(GREEN)Data Processor - Infrastructure Management$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make [target]"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# Terraform Commands
init: ## Initialize Terraform
	@echo "$(GREEN)Initializing Terraform...$(NC)"
	cd terraform && terraform init

plan: ## Run Terraform plan
	@echo "$(GREEN)Running Terraform plan for $(ENV) environment...$(NC)"
	cd terraform && terraform plan -var-file="environments/$(ENV).tfvars"

apply: ## Apply Terraform changes
	@echo "$(GREEN)Applying Terraform for $(ENV) environment...$(NC)"
	cd terraform && terraform apply -var-file="environments/$(ENV).tfvars"

apply-auto: ## Apply Terraform without confirmation
	@echo "$(GREEN)Auto-applying Terraform for $(ENV) environment...$(NC)"
	cd terraform && terraform apply -auto-approve -var-file="environments/$(ENV).tfvars"

destroy: ## Destroy Terraform resources
	@echo "$(RED)Destroying Terraform resources for $(ENV) environment...$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform && terraform destroy -var-file="environments/$(ENV).tfvars"; \
	fi

format: ## Format Terraform files
	@echo "$(GREEN)Formatting Terraform files...$(NC)"
	cd terraform && terraform fmt -recursive

validate: ## Validate Terraform configuration
	@echo "$(GREEN)Validating Terraform configuration...$(NC)"
	cd terraform && terraform validate

output: ## Show Terraform outputs
	@echo "$(GREEN)Terraform outputs:$(NC)"
	cd terraform && terraform output

# Docker Commands
build-api: ## Build API Docker image
	@echo "$(GREEN)Building API Docker image...$(NC)"
	cd api && docker build -t $(REGION)-docker.pkg.dev/$(PROJECT_ID)/data-processor/data-processor-api:latest .

build-worker: ## Build Worker Docker image
	@echo "$(GREEN)Building Worker Docker image...$(NC)"
	cd worker && docker build -t $(REGION)-docker.pkg.dev/$(PROJECT_ID)/data-processor/data-processor-worker:latest .

build: build-api build-worker ## Build all Docker images

push-api: ## Push API Docker image
	@echo "$(GREEN)Pushing API Docker image...$(NC)"
	docker push $(REGION)-docker.pkg.dev/$(PROJECT_ID)/data-processor/data-processor-api:latest

push-worker: ## Push Worker Docker image
	@echo "$(GREEN)Pushing Worker Docker image...$(NC)"
	docker push $(REGION)-docker.pkg.dev/$(PROJECT_ID)/data-processor/data-processor-worker:latest

push: push-api push-worker ## Push all Docker images

# GCP Commands
gcp-auth: ## Authenticate with GCP
	@echo "$(GREEN)Authenticating with GCP...$(NC)"
	gcloud auth login
	gcloud auth application-default login
	gcloud config set project $(PROJECT_ID)

gcp-services: ## Enable required GCP services
	@echo "$(GREEN)Enabling required GCP services...$(NC)"
	gcloud services enable cloudbuild.googleapis.com \
		run.googleapis.com \
		pubsub.googleapis.com \
		firestore.googleapis.com \
		containerregistry.googleapis.com \
		artifactregistry.googleapis.com

gcp-setup: gcp-auth gcp-services ## Complete GCP setup

# Testing Commands
test-api: ## Run API unit tests
	@echo "$(GREEN)Running API tests...$(NC)"
	cd api && python -m pytest tests/ -v

test-worker: ## Run Worker unit tests
	@echo "$(GREEN)Running Worker tests...$(NC)"
	cd worker && python -m pytest tests/ -v

test: test-api test-worker ## Run all unit tests

test-integration: ## Run integration tests
	@echo "$(GREEN)Running integration tests...$(NC)"
	@API_URL=$$(cd terraform && terraform output -raw api_service_url 2>/dev/null); \
	if [ -z "$$API_URL" ]; then \
		echo "$(RED)Error: API URL not found. Run 'make apply' first.$(NC)"; \
		exit 1; \
	fi; \
	echo "Testing API at $$API_URL"; \
	curl -f $$API_URL/health && echo "$(GREEN)✓ Health check passed$(NC)"; \
	curl -f -X POST $$API_URL/ingest \
		-H 'Content-Type: application/json' \
		-d '{"tenant_id": "test", "text": "test"}' && echo "$(GREEN)✓ Ingestion test passed$(NC)"

# Deployment Commands
deploy-dev: ## Deploy to development environment
	@$(MAKE) ENV=dev apply

deploy-staging: ## Deploy to staging environment
	@$(MAKE) ENV=staging apply

deploy-prod: ## Deploy to production environment
	@$(MAKE) ENV=prod apply

deploy-all: build push apply ## Build, push, and deploy

# Monitoring Commands
logs-api: ## View API logs
	@echo "$(GREEN)Fetching API logs...$(NC)"
	gcloud run services logs read data-processor-api --region=$(REGION) --limit=50

logs-worker: ## View Worker logs
	@echo "$(GREEN)Fetching Worker logs...$(NC)"
	gcloud run services logs read data-processor-worker --region=$(REGION) --limit=50

logs: logs-api logs-worker ## View all logs

status: ## Check status of all services
	@echo "$(GREEN)Service Status:$(NC)"
	@gcloud run services list --region=$(REGION)
	@echo ""
	@echo "$(GREEN)Pub/Sub Topics:$(NC)"
	@gcloud pubsub topics list
	@echo ""
	@echo "$(GREEN)Pub/Sub Subscriptions:$(NC)"
	@gcloud pubsub subscriptions list

# Cleanup Commands
clean-images: ## Remove local Docker images
	@echo "$(RED)Cleaning local Docker images...$(NC)"
	docker image prune -f

clean-terraform: ## Clean Terraform files
	@echo "$(RED)Cleaning Terraform files...$(NC)"
	cd terraform && rm -rf .terraform .terraform.lock.hcl

clean: clean-images clean-terraform ## Clean all temporary files

# Development Commands
dev-setup: ## Setup development environment
	@echo "$(GREEN)Setting up development environment...$(NC)"
	cd api && python -m venv venv && . venv/bin/activate && pip install -r requirements.txt pytest
	cd worker && python -m venv venv && . venv/bin/activate && pip install -r requirements.txt pytest

run-api-local: ## Run API locally
	@echo "$(GREEN)Running API locally...$(NC)"
	cd api && python main.py

run-worker-local: ## Run Worker locally
	@echo "$(GREEN)Running Worker locally...$(NC)"
	cd worker && python main.py

# Quick Commands
quick-deploy: ## Quick deploy (build, push, apply)
	@echo "$(GREEN)Quick deploy starting...$(NC)"
	@$(MAKE) build
	@$(MAKE) push
	@$(MAKE) apply
	@$(MAKE) test-integration
	@echo "$(GREEN)Quick deploy complete!$(NC)"

quick-test: ## Quick test (API URL from Terraform)
	@API_URL=$$(cd terraform && terraform output -raw api_service_url 2>/dev/null) && \
	echo "$(GREEN)Testing $$API_URL$(NC)" && \
	curl -f $$API_URL/health && \
	curl -f -X POST $$API_URL/ingest \
		-H 'Content-Type: application/json' \
		-d '{"tenant_id": "test", "text": "Quick test message"}'

# Version and Info
version: ## Show versions of tools
	@echo "$(GREEN)Tool Versions:$(NC)"
	@echo "Terraform: $$(terraform version | head -1)"
	@echo "Docker: $$(docker --version)"
	@echo "gcloud: $$(gcloud version | head -1)"
	@echo "Make: $$(make --version | head -1)"

info: ## Show project information
	@echo "$(GREEN)Project Information:$(NC)"
	@echo "Project ID: $(PROJECT_ID)"
	@echo "Region: $(REGION)"
	@echo "Environment: $(ENV)"
	@cd terraform 2>/dev/null && terraform output 2>/dev/null || echo "Run 'make apply' first to see outputs"

# First-time setup
first-time-setup: gcp-setup init dev-setup ## Complete first-time setup
	@echo "$(GREEN)First-time setup complete!$(NC)"
	@echo "Next steps:"
	@echo "1. Update terraform/terraform.tfvars with your project ID"
	@echo "2. Run: make plan"
	@echo "3. Run: make apply"
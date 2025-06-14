.PHONY: help deploy-dev deploy-staging deploy-prod infra-dev infra-staging infra-prod content-dev content-staging content-prod validate outputs-dev outputs-staging outputs-prod delete-dev delete-staging delete-prod serve clean

# Default target
help:
	@echo "AWS Static Website Hosting - Available Commands:"
	@echo ""
	@echo "Deployment Commands:"
	@echo "  make deploy-dev        - Deploy complete dev environment"
	@echo "  make deploy-staging    - Deploy complete staging environment"
	@echo "  make deploy-prod       - Deploy complete production environment"
	@echo ""
	@echo "Infrastructure Commands:"
	@echo "  make infra-dev         - Deploy only dev infrastructure"
	@echo "  make infra-staging     - Deploy only staging infrastructure"
	@echo "  make infra-prod        - Deploy only production infrastructure"
	@echo ""
	@echo "Content Commands:"
	@echo "  make content-dev       - Deploy only dev content"
	@echo "  make content-staging   - Deploy only staging content"
	@echo "  make content-prod      - Deploy only production content"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make validate          - Validate CloudFormation template"
	@echo "  make outputs-dev       - Show dev stack outputs"
	@echo "  make outputs-staging   - Show staging stack outputs"
	@echo "  make outputs-prod      - Show production stack outputs"
	@echo "  make serve             - Serve website locally for testing"
	@echo "  make clean             - Clean temporary files"
	@echo ""
	@echo "Cleanup Commands:"
	@echo "  make delete-dev        - Delete dev stack (with confirmation)"
	@echo "  make delete-staging    - Delete staging stack (with confirmation)"
	@echo "  make delete-prod       - Delete production stack (with confirmation)"
	@echo ""
	@echo "Example Usage:"
	@echo "  make deploy-dev        # Deploy to development"
	@echo "  make content-prod      # Update production content only"
	@echo "  make serve             # Test locally before deployment"

# Deployment targets
deploy-dev:
	@echo "🚀 Deploying to development environment..."
	./scripts/deploy.sh dev deploy

deploy-staging:
	@echo "🚀 Deploying to staging environment..."
	./scripts/deploy.sh staging deploy

deploy-prod:
	@echo "🚀 Deploying to production environment..."
	@read -p "Are you sure you want to deploy to PRODUCTION? (y/N): " confirm && \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		./scripts/deploy.sh prod deploy; \
	else \
		echo "Production deployment cancelled."; \
	fi

# Infrastructure-only deployments
infra-dev:
	@echo "🏗️ Deploying dev infrastructure..."
	./scripts/deploy.sh dev infra

infra-staging:
	@echo "🏗️ Deploying staging infrastructure..."
	./scripts/deploy.sh staging infra

infra-prod:
	@echo "🏗️ Deploying production infrastructure..."
	@read -p "Deploy production infrastructure? (y/N): " confirm && \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		./scripts/deploy.sh prod infra; \
	else \
		echo "Production infrastructure deployment cancelled."; \
	fi

# Content-only deployments
content-dev:
	@echo "📄 Deploying dev content..."
	./scripts/deploy.sh dev content

content-staging:
	@echo "📄 Deploying staging content..."
	./scripts/deploy.sh staging content

content-prod:
	@echo "📄 Deploying production content..."
	@read -p "Deploy production content? (y/N): " confirm && \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		./scripts/deploy.sh prod content; \
	else \
		echo "Production content deployment cancelled."; \
	fi

# Utility targets
validate:
	@echo "✅ Validating CloudFormation template..."
	./scripts/deploy.sh dev validate

outputs-dev:
	@echo "📊 Development stack outputs:"
	./scripts/deploy.sh dev outputs

outputs-staging:
	@echo "📊 Staging stack outputs:"
	./scripts/deploy.sh staging outputs

outputs-prod:
	@echo "📊 Production stack outputs:"
	./scripts/deploy.sh prod outputs

serve:
	@echo "🌍 Starting local development server..."
	@echo "Visit http://localhost:8000 to view your website"
	@echo "Press Ctrl+C to stop the server"
	python3 -m http.server 8000 --directory src

clean:
	@echo "🧩 Cleaning temporary files..."
	find . -name "*.tmp" -delete 2>/dev/null || true
	find . -name "*.temp" -delete 2>/dev/null || true
	find . -name ".DS_Store" -delete 2>/dev/null || true
	@echo "Clean complete!"

# Cleanup targets
delete-dev:
	@echo "⚠️  Deleting development stack..."
	./scripts/deploy.sh dev delete

delete-staging:
	@echo "⚠️  Deleting staging stack..."
	./scripts/deploy.sh staging delete

delete-prod:
	@echo "⚠️  Deleting production stack..."
	@echo "This will permanently delete the PRODUCTION environment!"
	@read -p "Type 'DELETE' to confirm: " confirm && \
	if [ "$$confirm" = "DELETE" ]; then \
		./scripts/deploy.sh prod delete; \
	else \
		echo "Production deletion cancelled."; \
	fi

# Quick development workflow
dev: validate deploy-dev
	@echo "🎉 Development deployment complete!"
	@make outputs-dev

# Full staging workflow
staging: validate deploy-staging
	@echo "🎉 Staging deployment complete!"
	@make outputs-staging

# Check dependencies
check-deps:
	@echo "🔍 Checking dependencies..."
	@command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed."; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed."; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required but not installed."; exit 1; }
	@echo "✅ All dependencies are installed!"

# Setup target for first-time users
setup: check-deps
	@echo "🚀 Setting up AWS Static Website Hosting..."
	@echo "Please ensure your AWS CLI is configured with appropriate credentials."
	@echo "Run 'aws configure' if you haven't already."
	@echo ""
	@echo "Next steps:"
	@echo "1. Edit deploy-config.json with your domain settings"
	@echo "2. Run 'make validate' to check your CloudFormation template"
	@echo "3. Run 'make dev' to deploy to development environment"
	@echo "4. Run 'make serve' to test your website locally"

# Install development tools (optional)
install-tools:
	@echo "🔧 Installing development tools..."
	@if command -v brew >/dev/null 2>&1; then \
		echo "Installing tools via Homebrew..."; \
		brew install awscli jq cfn-lint; \
	elif command -v apt-get >/dev/null 2>&1; then \
		echo "Installing tools via apt..."; \
		sudo apt-get update && sudo apt-get install -y awscli jq; \
	elif command -v pip3 >/dev/null 2>&1; then \
		echo "Installing tools via pip..."; \
		pip3 install awscli cfn-lint; \
	else \
		echo "Please install AWS CLI and jq manually."; \
	fi


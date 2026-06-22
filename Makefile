SHELL := /bin/bash

DEMO_DIR := demo
AWS_DEMO_DIR := demo-aws
AZURE_DEMO_DIR := demo-azure
TYPES_DIR := types
TYPE_MANIFEST := $(TYPES_DIR)/deployments.yaml
AWS_TYPE_MANIFEST := $(TYPES_DIR)/buckets.yaml
AZURE_TYPE_MANIFEST := $(TYPES_DIR)/storageaccounts.yaml
USER_EXT := $(DEMO_DIR)/deployments-extension.tgz
AWS_USER_EXT := $(AWS_DEMO_DIR)/buckets-extension.tgz
AZURE_USER_EXT := $(AZURE_DEMO_DIR)/storageaccounts-extension.tgz

# The generated Radius core Bicep type index, shared by every demo's
# radius-extension.tgz (the expensive `generate-radius-types` step runs once).
RADIUS_TYPES_INDEX := radius/hack/bicep-types-radius/generated/index.json

.PHONY: help \
	register-types register-types-aws register-types-azure \
	generate-radius-types \
	build build-aws build-azure \
	radius-extension radius-extension-aws radius-extension-azure \
	user-extension aws-extension azure-extension \
	setup clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[34;1m%-20s\033[0m %s\n", $$1, $$2}'

register-types: ## Register the Kubernetes demo resource type with Radius
	@echo "==> Registering Demo.Kubernetes/deployments..."
	rad resource-type create -f $(TYPE_MANIFEST) || \
		(echo "    Retrying after 5s..." && sleep 5 && rad resource-type create -f $(TYPE_MANIFEST))
	@echo "Resource type registered"

register-types-aws: ## Register the AWS demo resource type with Radius
	@echo "==> Registering Demo.AWS/buckets..."
	rad resource-type create -f $(AWS_TYPE_MANIFEST) || \
		(echo "    Retrying after 5s..." && sleep 5 && rad resource-type create -f $(AWS_TYPE_MANIFEST))
	@echo "Resource type registered"

register-types-azure: ## Register the Azure demo resource type with Radius
	@echo "==> Registering Demo.Azure/storageAccounts..."
	rad resource-type create -f $(AZURE_TYPE_MANIFEST) || \
		(echo "    Retrying after 5s..." && sleep 5 && rad resource-type create -f $(AZURE_TYPE_MANIFEST))
	@echo "Resource type registered"

build: radius-extension user-extension ## Build both Bicep extensions into demo/

build-aws: radius-extension-aws aws-extension ## Build both Bicep extensions into demo-aws/

build-azure: radius-extension-azure azure-extension ## Build both Bicep extensions into demo-azure/

generate-radius-types: ## Generate the Radius core Bicep types from the submodule (adds the new `outputs` field)
	@echo "==> Generating Radius Bicep types from the radius submodule (includes the new 'outputs' field)..."
	$(MAKE) -C radius generate-bicep-types VERSION=latest

radius-extension: generate-radius-types ## Publish the Radius core Bicep extension into demo/
	@echo "==> Publishing Radius extension to $(DEMO_DIR)/radius-extension.tgz..."
	bicep publish-extension $(RADIUS_TYPES_INDEX) --target $(DEMO_DIR)/radius-extension.tgz --force
	@echo "Radius extension built at $(DEMO_DIR)/radius-extension.tgz"

radius-extension-aws: generate-radius-types ## Publish the Radius core Bicep extension into demo-aws/
	@echo "==> Publishing Radius extension to $(AWS_DEMO_DIR)/radius-extension.tgz..."
	bicep publish-extension $(RADIUS_TYPES_INDEX) --target $(AWS_DEMO_DIR)/radius-extension.tgz --force
	@echo "Radius extension built at $(AWS_DEMO_DIR)/radius-extension.tgz"

radius-extension-azure: generate-radius-types ## Publish the Radius core Bicep extension into demo-azure/
	@echo "==> Publishing Radius extension to $(AZURE_DEMO_DIR)/radius-extension.tgz..."
	bicep publish-extension $(RADIUS_TYPES_INDEX) --target $(AZURE_DEMO_DIR)/radius-extension.tgz --force
	@echo "Radius extension built at $(AZURE_DEMO_DIR)/radius-extension.tgz"

user-extension: ## Build the Kubernetes demo resource-type Bicep extension into demo/
	@echo "==> Building demo resource-type Bicep extension..."
	rad bicep publish-extension -f $(TYPE_MANIFEST) --target $(USER_EXT) --force 2>&1 | grep -v WARNING || true
	@echo "Demo extension built at $(USER_EXT)"

aws-extension: ## Build the AWS demo resource-type Bicep extension into demo-aws/
	@echo "==> Building AWS demo resource-type Bicep extension..."
	rad bicep publish-extension -f $(AWS_TYPE_MANIFEST) --target $(AWS_USER_EXT) --force 2>&1 | grep -v WARNING || true
	@echo "Demo extension built at $(AWS_USER_EXT)"

azure-extension: ## Build the Azure demo resource-type Bicep extension into demo-azure/
	@echo "==> Building Azure demo resource-type Bicep extension..."
	rad bicep publish-extension -f $(AZURE_TYPE_MANIFEST) --target $(AZURE_USER_EXT) --force 2>&1 | grep -v WARNING || true
	@echo "Demo extension built at $(AZURE_USER_EXT)"

setup: register-types build ## Register the type and build the extensions
	@echo "Setup complete. Deploy with:"
	@echo "  rad deploy $(DEMO_DIR)/platform.bicep"
	@echo "  rad deploy $(DEMO_DIR)/app.bicep"

clean: ## Remove generated extension files
	@rm -f $(DEMO_DIR)/*.tgz $(AWS_DEMO_DIR)/*.tgz $(AZURE_DEMO_DIR)/*.tgz
	@echo "Cleaned generated files"

SHELL := /bin/bash

DEMO_DIR := demo
TYPES_DIR := types

.PHONY: help register-types build radius-extension user-extension setup clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[34;1m%-20s\033[0m %s\n", $$1, $$2}'

register-types: ## Register the demo resource type with Radius
	@echo "==> Registering Demo.Datastores/redisCaches..."
	rad resource-type create -f $(TYPES_DIR)/redisCaches.yaml || \
		(echo "    Retrying after 5s..." && sleep 5 && rad resource-type create -f $(TYPES_DIR)/redisCaches.yaml)
	@echo "Resource type registered"

build: radius-extension user-extension ## Build both Bicep extensions into demo/

radius-extension: ## Generate + publish the Radius core Bicep extension (adds the new `outputs` field) from the submodule
	@echo "==> Generating Radius Bicep types from the radius submodule (includes the new 'outputs' field)..."
	$(MAKE) -C radius generate-bicep-types VERSION=latest
	@echo "==> Publishing Radius extension to $(DEMO_DIR)/radius-extension.tgz..."
	bicep publish-extension radius/hack/bicep-types-radius/generated/index.json --target $(DEMO_DIR)/radius-extension.tgz --force
	@echo "Radius extension built at $(DEMO_DIR)/radius-extension.tgz"

user-extension: ## Build the demo resource-type Bicep extension into demo/
	@echo "==> Building demo resource-type Bicep extension..."
	rad bicep publish-extension -f $(TYPES_DIR)/redisCaches.yaml --target $(DEMO_DIR)/redisCaches-extension.tgz --force 2>&1 | grep -v WARNING || true
	@echo "Demo extension built at $(DEMO_DIR)/redisCaches-extension.tgz"

setup: register-types build ## Register the type and build the extension
	@echo "Setup complete. Deploy with:"
	@echo "  rad deploy $(DEMO_DIR)/platform.bicep -p moduleTemplatePath='git::https://github.com/<org>/<repo>.git//modules/redis?ref=<sha>'"
	@echo "  rad deploy $(DEMO_DIR)/app.bicep"

clean: ## Remove generated extension files
	@rm -f $(DEMO_DIR)/*.tgz
	@echo "Cleaned generated files"

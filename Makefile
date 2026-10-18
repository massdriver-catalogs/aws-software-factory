.PHONY: help repos publish-platforms publish-resource-types publish-bundles build validate clean

PLATFORMS      = $(notdir $(wildcard platforms/*))
RESOURCE_TYPES = $(notdir $(wildcard resource-types/*))
BUNDLES        = $(notdir $(wildcard bundles/*))

help:
	@echo "make repos                   Create missing OCI repositories"
	@echo "make publish-platforms       Publish credential types"
	@echo "make publish-resource-types  Publish resource types"
	@echo "make build                   Build every bundle"
	@echo "make validate                tofu init + validate every bundle"
	@echo "make publish-bundles         Publish every bundle"
	@echo "make clean                   Remove generated and OpenTofu working files"

# Repositories must exist before the first publish. Re-running is safe: an
# existing repository makes `create` exit non-zero, which is ignored.
repos:
	@for d in $(PLATFORMS); do mass repository create $$d -t resource-type 2>&1 || true; done
	@for d in $(RESOURCE_TYPES); do mass repository create $$d -t resource-type 2>&1 || true; done
	@for d in $(BUNDLES); do mass repository create $$d -t bundle 2>&1 || true; done

publish-platforms: repos
	@for d in $(PLATFORMS); do mass resource-type publish platforms/$$d; done

publish-resource-types: repos
	@for d in $(RESOURCE_TYPES); do mass resource-type publish resource-types/$$d; done

build:
	@for d in $(BUNDLES); do mass bundle build --bundle-directory bundles/$$d; done

validate: build
	@for d in $(BUNDLES); do (cd bundles/$$d/src && tofu init -backend=false -input=false >/dev/null && tofu validate); done

publish-bundles: repos validate
	@for d in $(BUNDLES); do mass bundle publish --bundle-directory bundles/$$d; done

clean:
	@find . -name _massdriver_variables.tf -delete
	@find . -name 'schema-*.json' -delete
	@find . -name .terraform -type d -prune -exec rm -rf {} +

export DOCKER_ORG ?= mcalhoun
export DOCKER_TAG ?= latest
export DOCKER_IMAGE ?= $(DOCKER_ORG)/infra-live
export DOCKER_IMAGE_NAME ?= $(DOCKER_IMAGE):$(DOCKER_TAG)

# Name for app (used in banner and name of wrapper script)
export APP_NAME = mcal

# Default install path, if lacking permissions, ~/.local/bin will be used instead
export INSTALL_PATH ?= /usr/local/bin


export TARGET_DOCKER_REGISTRY := 552533042161.dkr.ecr.us-east-2.amazonaws.com
export TARGET_DOCKER_REPO := $(TARGET_DOCKER_REGISTRY)/$(DOCKER_IMAGE)
export TARGET_VERSION ?= $(DOCKER_TAG)
export TARGET_IMAGE_NAME := $(TARGET_DOCKER_REPO):$(TARGET_VERSION)

export ADR_DOCS_DIR = docs/adr
export ADR_DOCS_README = $(ADR_DOCS_DIR)/README.md

-include $(shell curl -sSL -o .build-harness "https://cloudposse.tools/build-harness"; echo .build-harness)

.DEFAULT_GOAL := all

.PHONY: all build build_clean install run run/new run/check push


all: init deps build install run/new
	@exit 0

## Install dependencies (if any)
deps: init
	@exit 0

## Build docker image
build:
	@make --no-print-directory docker/build

## Build docker image with no cache
build_clean:
	@make --no-print-directory DOCKER_BUILD_FLAGS=--no-cache docker/build

## Push docker image to registry
push:
	@docker tag $(DOCKER_IMAGE_NAME) $(TARGET_IMAGE_NAME)
	@docker push $(TARGET_IMAGE_NAME)

## Install wrapper script from geodesic container
install:
	@docker run --rm --env APP_NAME --env DOCKER_IMAGE --env DOCKER_TAG --env INSTALL_PATH $(DOCKER_IMAGE_NAME) | bash -s $(DOCKER_TAG)

## Start the geodesic shell by calling wrapper script
run:
	@$(APP_NAME)

run/check:
	@if [[ -n "$$(docker ps --format '{{ .Names }}' --filter name="^/$(APP_NAME)\$$")" ]]; then \
		printf "**************************************************************************\n" ; \
		printf "Not launching new container because old container is still running.\n"; \
		printf "Exit all running container shells gracefully or kill the container with\n\n"; \
		printf "  docker kill %s\n\n" "$(APP_NAME)" ; \
		printf "**************************************************************************\n" ; \
		exit 9 ; \
	fi

run/new: run/check run
	@exit 0

.PHONY: terraform-rm-lockfiles rebuild-adr-docs rebuild-aws-config rebuild-docs ecr-auth

## Remove all lock files
terraform-rm-lockfiles:
	$(shell find . -name ".terraform.lock.hcl" -exec rm -v {} \;)

## Rebuild README for all Terraform components
rebuild-docs: packages/install/terraform-docs
	@pre-commit run --all-files terraform_docs

## Rebuild README TOC for all ADRs
rebuild-adr-docs:
	adr generate toc > $(ADR_DOCS_README);

## Rebuild aws-config
rebuild-aws-config:
	bash rootfs/usr/local/bin/aws-accounts gen-cicd > rootfs/etc/aws-config/aws-config-cicd
	bash rootfs/usr/local/bin/aws-accounts gen-saml | grep -v source_profile | grep admin -C 1 | grep -v '\-\-' > rootfs/etc/aws-config/aws-config-extend-roles
	bash rootfs/usr/local/bin/aws-accounts gen-saml > rootfs/etc/aws-config/aws-config-local

## Authenticate with ECR repository
ecr-auth:
	@AWS_PROFILE=cp-sandbox-admin aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $(TARGET_DOCKER_REPO)

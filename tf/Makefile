# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Please note that this file was generated from [terraform-google-module-template](https://github.com/terraform-google-modules/terraform-google-module-template).
# Please make sure to contribute relevant changes upstream!

# Make will use bash instead of sh
SHELL := /usr/bin/env bash

DOCKER_TAG_VERSION_DEVELOPER_TOOLS := 1.22
DOCKER_IMAGE_DEVELOPER_TOOLS := cft/developer-tools
REGISTRY_URL := gcr.io/cloud-foundation-cicd
CLUSTER_NAME = argocd-conductr-control-plane
DOCKER_RESTART = no

# GPG_ID := 68789365A466F3CFC4D563AF9C946BF5155242C6

.DEFAULT_GOAL := help

.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nNutzung:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# Enter docker container for local development
.PHONY: docker-run
docker_run:
#	docker run --rm -it \

# Execute prepare tests within the docker container
#		-e TF_VAR_folder_id \
#		-e TF_VAR_billing_account \

.PHONY: docker-test-prepare
docker_test_prepare:
#	docker run --rm -it \

# Clean up test environment within the docker container
.PHONY: docker-test-cleanup
docker_test_cleanup:
#	docker run --rm -it \

# Execute integration tests within the docker container
.PHONY: docker-test-integration
docker-test-integration:
#	docker run --rm -it \

.PHONY: docker-test-lint
docker-test-lint: ## Execute lint tests within the docker container
	docker run --rm -it \
		-v $(CURDIR):/workspace \
		$(REGISTRY_URL)/${DOCKER_IMAGE_DEVELOPER_TOOLS}:${DOCKER_TAG_VERSION_DEVELOPER_TOOLS} \
		/usr/local/bin/test_lint.sh

.PHONY: docker-generate-docs
docker-generate-docs: ## Generate documentation
	docker run --rm -it \
		-v $(CURDIR):/workspace \
		$(REGISTRY_URL)/${DOCKER_IMAGE_DEVELOPER_TOOLS}:${DOCKER_TAG_VERSION_DEVELOPER_TOOLS} \
		/bin/bash -c 'source /usr/local/bin/task_helper_functions.sh && generate_docs'

# Alias for backwards compatibility
.PHONY: generate-docs
generate_docs: docker-generate-docs

.PHONY: apply
apply: ## Terraform apply
	terraform apply -auto-approve

.PHONY: quick-destroy
quick-destroy: ## Quick destruction
	docker stop argocd-conductr-control-plane || true
	docker rm argocd-conductr-control-plane || true
#	rm -rf terraform.tfstate*
	terraform state list | cut -f 1 -d '[' | sort | uniq | xargs terraform state rm

.PHONY: docker-update-restart
docker-update-restart: ## Update Docker Restart Policy
	docker update --restart=$(DOCKER_RESTART) $(CLUSTER_NAME)

.PHONY: argocd-update-nodeport
argocd-update-nodeport: ## Update ArgoCD Nodeport (TODO: : ArgoCD CRD does not allow setting a known port)
	kubectl patch service argocd-server -n argocd \
		-p '{"spec": {"ports": [{"port": 80, "nodePort": 31080, "protocol": "TCP", "targetPort": 8080}], "type": "NodePort"}}'


.PHONY: run-pull-registry-proxy
run-registry-proxy: ## Run pull through registry proxy/-ies
	docker run -d --name docker-proxy --restart=always --net=kind \
    	-e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io registry:2
	docker run -d --name quay-proxy --restart=always --net=kind \
    	-e REGISTRY_PROXY_REMOTEURL=https://quay.io registry:2
	docker run -d --name k8s-proxy --restart=always --net=kind \
    	-e REGISTRY_PROXY_REMOTEURL=https://registry.k8s.io registry:2
	docker run -d --name ghcr-proxy --restart=always --net=kind \
    	-e REGISTRY_PROXY_REMOTEURL=https://ghcr.io registry:2

.PHONY: run-push-registry
run-registry: ## Run docker registry
	docker run -d --name registry --restart=always --net=kind \
    	-p 5000:5000 registry:2

.PHONY: show-connections
show-connections: ## Show submariner/ocm connections
	KUBECONFIG="argocd-conductr-config:examples/generic/argocd-conductr-spoke-config" subctl show connections
	KUBECONFIG="argocd-conductr-config:examples/generic/argocd-conductr-spoke-config" kubectl --context kind-argocd-conductr get managedcluster


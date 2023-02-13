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

DOCKER_TAG_VERSION_DEVELOPER_TOOLS := 1.3
DOCKER_IMAGE_DEVELOPER_TOOLS := cft/developer-tools
REGISTRY_URL := gcr.io/cloud-foundation-cicd
GPG_ID := 68789365A466F3CFC4D563AF9C946BF5155242C6

.DEFAULT_GOAL := help

.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nNutzung:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# Enter docker container for local development
.PHONY: docker_run
docker_run:
#	docker run --rm -it \

# Execute prepare tests within the docker container
#		-e TF_VAR_folder_id \
#		-e TF_VAR_billing_account \

.PHONY: docker_test_prepare
docker_test_prepare:
#	docker run --rm -it \

# Clean up test environment within the docker container
.PHONY: docker_test_cleanup
docker_test_cleanup:
#	docker run --rm -it \

# Execute integration tests within the docker container
.PHONY: docker_test_integration
docker_test_integration:
#	docker run --rm -it \

# Execute lint tests within the docker container
.PHONY: docker_test_lint
docker_test_lint:
	docker run --rm -it \
		-v $(CURDIR):/workspace \
		$(REGISTRY_URL)/${DOCKER_IMAGE_DEVELOPER_TOOLS}:${DOCKER_TAG_VERSION_DEVELOPER_TOOLS} \
		/usr/local/bin/test_lint.sh

# Generate documentation
.PHONY: docker_generate_docs
docker_generate_docs:
	docker run --rm -it \
		-v $(CURDIR):/workspace \
		$(REGISTRY_URL)/${DOCKER_IMAGE_DEVELOPER_TOOLS}:${DOCKER_TAG_VERSION_DEVELOPER_TOOLS} \
		/bin/bash -c 'source /usr/local/bin/task_helper_functions.sh && generate_docs'

# Alias for backwards compatibility
.PHONY: generate_docs
generate_docs: docker_generate_docs

.PHONY: apply
apply:
	terraform apply -auto-approve

create_age_key:
	age-keygen -o ../key.txt

#create_gpg_secret:
## --dry-run -o yaml 
#	gpg --export-secret-keys --armor "$(GPG_ID)" | \
#		kubectl create secret generic sops-gpg --namespace=argocd --from-file=sops.asc=/dev/stdin

create_age_secret:
	cat ../key.txt | kubectl create secret generic sops-age --namespace=argocd \
		--from-file=key.txt=/dev/stdin


.PHONY:
argocd_initial_admin_password: ## Show initial ArgoCD admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data}" | jq -r '."password"' | base64 -d; echo

# TODO: Pull Load-Balancer IP from Kubernetes
argocd_admin_login:  ## ArgoCD admin login
	argocd login --insecure --username admin \
		--password $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data}" | jq -r '."password"' | base64 -d) \
		$$(kubectl -n argocd get svc/argocd-server --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

argocd_ensure_cluster_admin: ## Ensure ArgoCD sa can do anything
	kubectl auth can-i create pod --as=system:serviceaccount:argocd:argocd-application-controller -n kube-system

argocd_deploy: ## ArgoCD deploy guestbook
	argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default

show_docker_subnet:
	docker network inspect --format '{{ json (index .IPAM.Config 0) }}' kind | jq -r .Subnet

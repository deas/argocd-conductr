operator_version=v1.0.0
catalogd_version=v1.0.0
cert_mgr_version=v1.15.3

.DEFAULT_GOAL := help

.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

crds:
	mkdir -p crds

.PHONY: download-manifests
download-manifests: ## Download manifests
	rm -f tmp/*
	wget -P tmp -q "https://github.com/cert-manager/cert-manager/releases/download/$(cert_mgr_version)/cert-manager.yaml"
	wget -P tmp -q "https://github.com/operator-framework/catalogd/releases/download/$(catalogd_version)/catalogd.yaml"
	wget -P tmp -q "https://github.com/operator-framework/catalogd/releases/download/$(catalogd_version)/default-catalogs.yaml"
	wget -P tmp -q "https://github.com/operator-framework/operator-controller/releases/download/$(operator_version)/operator-controller.yaml"

.PHONY: split-manifests
split-manifests: crds ## Split manifests
	for file in catalogd cert-manager operator-controller default-catalogs; do \
		cat tmp/$${file}.yaml | ./split-k8s-manifests.clj -$${file}; \
	done

# | yq eval-all '.spec.groups[] as $$item ireduce ({"groups": []}; .groups += [$$item])' - > apps/infra/monitoring/prom-test-rules.yaml


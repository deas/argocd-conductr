KUBECTL=kubectl
CA_CERTS_FILE=/etc/ssl/certs/ca-certificates.crt
SSH_PUB_KEY=keys/id_rsa-argocd-conductr.pub
GPG_KEY=argocd-conductr
ARGOCD_NS=argocd
MONITORING_NS=openshift-user-workload-monitoring
OPERATORS_NS=openshift-operators
OLM_NS=olm
# OLM_NS=openshift-operator-lifecycle-manager
ENV=local
AMTOOL_OUTPUT=simple
BOOTSTRAP_MANIFEST=keys/bootstrap.yaml

.DEFAULT_GOAL := help

.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: gen-keys
gen-keys: ## Generate ssh keys
	./script/gen-keys.sh

.PHONY: gh-add-deploy-key
gh-add-deploy-key: ## Add Deployment key to github
	gh repo deploy-key add keys $(SSH_PUB_KEY)

.PHONY: image-summary
image-summary: ## Show deployed images
	$(KUBECTL) get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}" | tr -s '[[:space:]]' '\n' | sort | uniq -c | sort -n | tac

target:
	mkdir target

age-create-key:
	age-keygen -o ./key.txt

#create_gpg_secret:
## --dry-run -o yaml 
#	gpg --export-secret-keys --armor "$(GPG_ID)" | \
#		kubectl create secret generic sops-gpg --namespace=argocd --from-file=sops.asc=/dev/stdin

create-age-secret:
	cat ./key.txt | kubectl create secret generic sops-age --namespace=argocd \
		--from-file=key.txt=/dev/stdin

.PHONY:
argocd-initial-admin-password: ## Show initial ArgoCD admin password
	@./tools/argocd.sh show-pass

# TODO: Pull Load-Balancer IP from Kubernetes
argocd-admin-login:  ## ArgoCD admin login
	./tools/argocd.sh login
#		$$(kubectl -n argocd get svc/argo-cd-argocd-server --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

argocd-ensure-cluster-admin: ## Ensure ArgoCD sa can do anything
	kubectl auth can-i create pod --as=system:serviceaccount:argocd:argocd-application-controller -n kube-system

argocd-deploy: ## ArgoCD deploy guestbook
	argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default

.PHONY: argocd-generate-monitor-manifests
argocd-generate-monitor-manifests: ## Generate ArgoCD monitor manifests
	helm template --release-name argo-cd argo/argo-cd -n argocd --api-versions monitoring.coreos.com/v1 \
		-f apps/infra/argo-cd/values.yaml -f apps/infra/argo-cd/envs/$(ENV)/values.yaml \
	| yq 'select(.kind == "ServiceMonitor")'

.PHONY: test-prom-rules
test-prom-rules: target ## Unit test prometheus rules
	helm template --release-name monitoring apps/infra/monitoring -n $(MONITORING_NS)  \
		-f apps/infra/monitoring/values.yaml -f apps/infra/monitoring/envs/$(ENV)/values.yaml \
	| yq 'select(.kind == "PrometheusRule")' \
	| yq eval-all '.spec.groups[] as $$item ireduce ({"groups": []}; .groups += [$$item])' - > apps/infra/monitoring/prom-test-rules.yaml
	cd apps/infra/monitoring && promtool test rules test.yaml

# /usr/local/share/ca-certificates/extra/mitmproxy-ca-cert.crt
.PHONY: create-ca-res
create-ca-res: target/manifest-ca-certs.yaml

target/manifest-ca-certs.yaml: target ## Recreate ca certs manifests
	cat $(CA_CERTS_FILE) | $(KUBECTL) create configmap ca-certs --from-file=ca-certificates.crt=/dev/stdin --dry-run=client -o yaml > target/manifest-ca-certs.yaml

.PHONY: argocd-recreate-ca-res
argocd-recreate-ca-res: target/manifest-ca-certs.yaml ## Re-create ArgoCD ca certs
	$(KUBECTL) -n $(ARGOCD_NS) delete configmap ca-certs || true
	$(KUBECTL) -n $(ARGOCD_NS) create -f target/manifest-ca-certs.yaml

.PHONY: argocd-patch-openshift-auth
argocd-patch-openshift-auth: ## Patch ArgoCD to use apenShift auth
#  Deprecated since openshift 4.11: oc -n serviceaccounts get-token argocd-dex-server
#  Needs secret in secrets property of serviceaccount
	export argocd_host=$$($(KUBECTL) -n $(ARGOCD_NS) get ing argo-cd-argocd-server -o=jsonpath='{ .spec.rules[0].host }') \
	ns=$(ARGOCD_NS) \
	sa=argocd-dex-server \
	issuer=$$(oc whoami --show-server) && \
	./assets/create-argocd-openshift-auth-patch.sh && \
	$(KUBECTL) -n $(ARGOCD_NS) patch serviceaccount argocd-dex-server --type='json' -p='[{"op": "add", "path": "/metadata/annotations/serviceaccounts.openshift.io~1oauth-redirecturi.dex", "value":"'https://$${argocd_host}/api/dex/callback'"}]'
	$(KUBECTL) -n $(ARGOCD_NS) delete pod -l app.kubernetes.io/component=dex-server
	$(KUBECTL) -n $(ARGOCD_NS) delete pod -l app.kubernetes.io/component=server

.PHONY: patch-openshift-htpass
patch-openshift-htpass: ## Patch OpenShift OAuth (Beware: Nukes default auth on CRC)
	htpasswd -bBn admin admin | $(KUBECTL) create secret generic htpass --from-file=htpasswd=/dev/stdin -n openshift-config
	$(KUBECTL) apply -f assets/oauth-cluster.yaml


.PHONY: argocd-install-basic-common
argocd-install-basic-common: ## Install ArgoCD common (Helm/OLM) bits
	$(KUBECTL) create ns $(ARGOCD_NS) || true
	[ -e "keys/$(GPG_KEY)-priv.asc" ] && $(KUBECTL) -n $(ARGOCD_NS) create secret generic sops-gpg --namespace=argocd --from-file=sops.asc=keys/$(GPG_KEY)-priv.asc || true
	[ -e "$(BOOTSTRAP_MANIFEST)" ] && $(KUBECTL) apply -f $(BOOTSTRAP_MANIFEST)
	$(KUBECTL) -n $(ARGOCD_NS) create secret generic env-rev \
		--from-literal env=$(ENV) \
		--from-literal repo=https://github.com/deas/argocd-conductr.git \
		--from-literal server=https://kubernetes.default.svc \
		--dry-run=client -o yaml | $(KUBECTL) apply -f -
	# $(KUBECTL) -n $(ARGOCD_NS) create secret generic $(ENV) --from-literal config="{'tlsClientConfig':{'insecure':false}}" --from-literal name=$(ENV) --from-literal server=https://kubernetes.default.svc --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) -n $(ARGOCD_NS) label secret env-rev argocd.argoproj.io/secret-type=cluster
	$(KUBECTL) -n $(ARGOCD_NS) create secret generic sops-age --namespace=argocd --from-file=keys.txt=./sample-key.txt || true
#	$(KUBECTL) apply -f assets/scc-argocd.yaml
#   kustomize build --enable-helm apps/local/argo-cd | $(KUBECTL) apply -f -

.PHONY: argocd-helm-install-basic
# TODO: A bit overlap with terraform 
argocd-helm-install-basic: argocd-install-basic-common  ## Install ArgoCD with Helm
	helm upgrade --install --namespace $(ARGOCD_NS) -f apps/infra/argo-cd/values.yaml -f apps/infra/argo-cd/envs/local/values.yaml -f apps/infra/argo-cd/bootstrap-override-values.yaml argocd --repo https://argoproj.github.io/argo-helm argo-cd --version 7.6.8


.PHONY: argcd-olm-install-basic
argcd-olm-install-basic: argocd-install-basic-common  ## Install ArgoCD with OLM
	helm upgrade --install --namespace $(OPERATORS_NS) operators apps/infra/operators -f apps/infra/operators/bootstrap-override-operatorhub-values.yaml \
		--set subscriptions[0].sourceNamespace=olm
	kubectl -n $(OPERATORS_NS) wait --timeout=180s --for=jsonpath='{.status.state}'=AtLatestKnown subscription/argocd-operator
	kustomize build apps/infra/argo-cd/envs/spoke | kubectl apply -f - # TODO $(ENV)
	kubectl -n $(ARGOCD_NS) wait --timeout=180s --for=jsonpath='{.status.phase}'=Available argocd/argocd
#	--set operatorsNamespace=openshift-operators --set subscriptions[0].sourceNamespace=openshift-operator-lifecycle-manager

.PHONY: argocd-apply-root
argocd-apply-root: ## Apply argocd root application
	$(KUBECTL) apply -f envs/$(ENV)/app-root.yaml

#.PHONY: update-olm-manifests
#update-olm-manifests: ## Update olm manifests
#	wget -q https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/crds.yaml -O components/olm/crd/crds.yaml
#	wget -q https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml -O components/olm/non-crd/olm.yaml

.PHONY: fmt
fmt: ## Format
	terraform fmt --check --recursive

.PHONY: lint
lint: ## Lint
	tflint --recursive

.PHONY: gator-verify
gator-verify: target ## Gator verify templates and constraints
	kustomize build apps/infra/gatekeeper-library/envs/$(ENV) | yq 'select(.kind == "ConstraintTemplate")' > target/template.yaml
	gator verify apps/infra/gatekeeper-library/...

.PHONY: set-gitops-branch
set-gitops-branch: ## Set gitops branch to current
	branch=$$(git rev-parse --abbrev-ref HEAD); find envs -iname "*.yaml" | while read f ; do sed -i "s/evision: \"*[a-z].*/evision: $${branch}/g" "$${f}"; done

.PHONY: install-tools
install-tools: ## Install all the tools
	mise install

.PHONY: create-dashboard-configmaps
create-dashboard-configmaps: ## Create dashboard ConfigMaps
	$(KUBECTL) -n $(MONITORING_NS) create configmap dashboards-misc --from-file=./apps/infra/monitoring/envs/local/assets/dashboards -o yaml --dry-run=client > ./apps/infra/monitoring/envs/local/configmap-dashboards.yaml
	@echo
	@echo "Make sure to add label for grafana sidecar"
	@echo

.PHONY: show-alerts
show-alerts: ## Show firing alerts
	@$(KUBECTL) -n $(MONITORING_NS) exec -it alertmanager-kube-prometheus-stack-alertmanager-0 -- amtool alert -o $(AMTOOL_OUTPUT) --alertmanager.url=http://alertmanager-operated:9093

.PHONY: argocd-disable-sync
argocd-disable-sync: ## Disable sync for all argo cd apps
	argocd app set root --sync-policy none
	for appset in $$(kubectl get applicationsets -n argocd -o name); do \
		kubectl patch $$appset -n argocd --type merge -p '{"spec":{"template":{"spec":{"syncPolicy":{"automated": null}}}}}'; \
	done

.PHONY: argocd-enable-sync
argocd-enable-sync: ## Enable sync for all argo cd apps
	argocd app set root --sync-policy auto 
	argocd app sync root

.PHONY: get-mon-webhook-logs
get-mon-webhook-logs: ## Get monitoring webhook	logs
	$(KUBECTL) -n $(MONITORING_NS) logs -l app.kubernetes.io/instance=monitoring-webhook

.PHONY: olmv0-install
olmv0-install: ## Ad hoc install olmv0
	curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.30.0/install.sh | bash -s v0.30.0

.PHONY: olmv1-install
olmv1-install: ## Ad hoc install olmv1
	curl -L -s https://github.com/operator-framework/operator-controller/releases/latest/download/install.sh | bash -s

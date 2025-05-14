KUBECTL=kubectl
# CA_CERTS_FILE=/etc/ssl/certs/ca-certificates.crt
CA_FILES_ROOT=apps/infra/openshift-config
CA_KEY=$(CA_FILES_ROOT)/ca-tls.key
CA_CERT=$(CA_FILES_ROOT)/ca-tls.crt
CA_SUBJ=/C=DE/ST=Hamburg/L=Hamburg/O=My Company/CN=My Root CA
CA_CNF=$(CA_FILES_ROOT)/ca-tls.cnf

SSH_PUB_KEY=keys/id_rsa-argocd-conductr.pub
GPG_KEY=argocd-conductr
ARGOCD_NS=argocd
MONITORING_NS=openshift-user-workload-monitoring
OPERATORS_NS=openshift-operators
# OLM_NS=olm
# OLM_NS=openshift-operator-lifecycle-manager
ENV=local
AMTOOL_OUTPUT=simple
# # Use the bootstrap manifest for secrets which are not in git
BOOTSTRAP_MANIFEST=keys/bootstrap.yaml
BOOTSTRAP_SEALED_SECRET=apps/infra/private/base/sealedsecret-argocd-repo.yaml

.DEFAULT_GOAL := help

# TODO: Unify naming of targets wrt verbs/nouns
#
.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: gen-ca-key
gen-ca-key: ## Generate CA key
	openssl genpkey -algorithm RSA -out "$(CA_KEY)"

.PHONY: gen-ca-cert
gen-ca-cert: ## Generate CA cert
	openssl req -new -x509 -days 3650 -key "$(CA_KEY)" -out "$(CA_CERT)" -config "$(CA_CNF)" -subj "$(CA_SUBJ)"

.PHONY: gen-ca-sealedsecret
gen-ca-sealedsecret: ## Generate CA sealed secret
	$(KUBECTL) create secret generic custom-ca --namespace=openshift-operators --from-file=tls.crt=$(CA_CERT) --from-file=tls.key=$(CA_KEY) --dry-run=client -o yaml \
		| kubeseal -n openshift-operators --cert assets/kubeseal.pem --format yaml \
		> apps/infra/private/base/sealedsecret-custom-ca.yaml

.PHONY: gen-keys
gen-keys: ## Generate ssh keys
	./tools/gen-keys.sh

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
	cat ./key.txt | $(KUBECTL) create secret generic sops-age --namespace=argocd \
		--from-file=key.txt=/dev/stdin

.PHONY:
argocd-initial-admin-password: ## Show initial ArgoCD admin password
	@./tools/argocd.sh show-pass

# TODO: Pull Load-Balancer IP from Kubernetes
argocd-admin-login:  ## ArgoCD admin login
	./tools/argocd.sh login
#		$$(kubectl -n argocd get svc/argo-cd-argocd-server --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

argocd-ensure-cluster-admin: ## Ensure ArgoCD sa can do anything
	$(KUBECTL) auth can-i create pod --as=system:serviceaccount:argocd:argocd-application-controller -n kube-system

argocd-deploy: ## ArgoCD deploy guestbook
	argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default

.PHONY: argocd-generate-monitor-manifests
argocd-generate-monitor-manifests: ## Generate ArgoCD monitor manifests
	helm template --release-name argo-cd argo/argo-cd -n argocd --api-versions monitoring.coreos.com/v1 \
		-f apps/infra/argo-cd/values.yaml -f apps/infra/argo-cd/envs/$(ENV)/values.yaml \
	| yq 'select(.kind == "ServiceMonitor")'

.PHONY: test-prom-rules
test-prom-rules: target ## Unit test prometheus rules
	helm template --release-name monitoring apps/infra/openshift-user-workload-monitoring -n $(MONITORING_NS)  \
		-f apps/infra/openshift-user-workload-monitoring/values.yaml -f apps/infra/openshift-user-workload-monitoring/envs/$(ENV)/values.yaml \
	| yq 'select(.kind == "PrometheusRule")' \
	| yq eval-all '.spec.groups[] as $$item ireduce ({"groups": []}; .groups += [$$item])' - > apps/infra/openshift-user-workload-monitoring/prom-test-rules.yaml
	cd apps/infra/openshift-user-workload-monitoring && promtool test rules test.yaml

# /usr/local/share/ca-certificates/extra/mitmproxy-ca-cert.crt
.PHONY: create-ca-res
create-ca-res: $(CA_FILES_ROOT)/base/configmap-user-ca-bundle.yaml

.PHONY: create-user-ca-certs-res
create-user-ca-certs-res: $(CA_FILES_ROOT)/base/configmap-user-ca-bundle.yaml ## Create User CA bundle

# TODO: Don't dupe certs things
target/manifest-ca-certs.yaml: target ## Recreate ca certs manifests
	cat $(CA_FILES_ROOT)/*.crt | $(KUBECTL) create configmap ca-certs --from-file=ca-certificates.crt=/dev/stdin --dry-run=client -o yaml > target/manifest-ca-certs.yaml

$(CA_FILES_ROOT)/base/configmap-user-ca-bundle.yaml: target ## Create openshift user ca cert manifests bundle
	cat $(CA_FILES_ROOT)/*.crt | $(KUBECTL) -n openshift-config create configmap user-ca-bundle --dry-run=client -o yaml --from-file=ca-bundle.crt=/dev/stdin \
		| yq eval '.metadata.annotations += {"reflector.v1.k8s.emberstack.com/reflection-allowed": "true","reflector.v1.k8s.emberstack.com/reflection-auto-enabled": "true", "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces": ".*"}' \
	  > $@

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
	if [ -e "keys/$(GPG_KEY)-priv.asc" ] ; then $(KUBECTL) -n $(ARGOCD_NS) create secret generic sops-gpg --namespace=argocd --from-file=sops.asc=keys/$(GPG_KEY)-priv.asc ; fi 
	if [ -e "$(BOOTSTRAP_MANIFEST)" ] ; then $(KUBECTL) apply -f $(BOOTSTRAP_MANIFEST) ; fi
	# TODO: Unsure whether we want env-config for AppSets in repo
	#$(KUBECTL) -n $(ARGOCD_NS) create secret generic env-rev \
	#	--from-literal env=$(ENV) \
	#	--from-literal repo=https://github.com/deas/argocd-conductr.git \
	#	--from-literal server=https://kubernetes.default.svc \
	#	--dry-run=client -o yaml | $(KUBECTL) apply -f -
	# $(KUBECTL) -n $(ARGOCD_NS) create secret generic $(ENV) --from-literal config="{'tlsClientConfig':{'insecure':false}}" --from-literal name=$(ENV) --from-literal server=https://kubernetes.default.svc --dry-run=client -o yaml | $(KUBECTL) apply -f -
	# $(KUBECTL) -n $(ARGOCD_NS) label secret env-rev argocd.argoproj.io/secret-type=cluster || true
	$(KUBECTL) -n $(ARGOCD_NS) create secret generic sops-age --namespace=argocd --from-file=keys.txt=./sample-key.txt || true
	# TODO: DRY: Could pull sealed secrets bits from ArgoCD appset
	# helm upgrade -i --repo https://bitnami-labs.github.io/sealed-secrets sealed-secrets sealed-secrets -n kube-system --version 2.16.1 -f apps/infra/sealed-secrets/values.yaml \
	#	--set metrics.serviceMonitor.enabled=false
	# if [ -e "$(BOOTSTRAP_SEALED_SECRET)" ] ; then $(KUBECTL) apply -f $(BOOTSTRAP_SEALED_SECRET) ; fi 

.PHONY: argocd-helm-install-basic
# TODO: A bit overlap with terraform 
argocd-helm-install-basic: argocd-install-basic-common  ## Install ArgoCD with Helm
#	$(KUBECTL) apply -f assets/scc-argocd.yaml
#   kustomize build --enable-helm apps/local/argo-cd | $(KUBECTL) apply -f -
	helm upgrade --install --namespace $(ARGOCD_NS) -f apps/infra/argo-cd/values.yaml -f apps/infra/argo-cd/envs/local/values.yaml -f apps/infra/argo-cd/bootstrap-override-values.yaml argocd --repo https://argoproj.github.io/argo-helm argo-cd --version 7.6.8


.PHONY: argocd-olm-install-basic
argocd-olm-install-basic: argocd-install-basic-common  ## Install ArgoCD with OLM
	helm upgrade -i --namespace $(OPERATORS_NS) operators apps/infra/operators -f apps/infra/operators/bootstrap-override-operatorhub-values.yaml
	$(KUBECTL) -n $(OPERATORS_NS) wait --timeout=180s --for=jsonpath='{.status.state}'=AtLatestKnown subscription/argocd-operator
	./tools/wait-for-k8s.sh crd/argocds.argoproj.io banane 60 # TODO : There should be a better way
	kustomize build apps/infra/argo-cd/envs/$(ENV) | $(KUBECTL) apply -f -
	$(KUBECTL) -n $(ARGOCD_NS) apply -f apps/infra/argo-cd/envs/$(ENV)/configmap-cluster-env.yaml
	$(KUBECTL) -n $(ARGOCD_NS) wait --timeout=180s --for=jsonpath='{.status.phase}'=Available argocd/argocd

.PHONY: argocd-sealed-secret-create
argocd-sealed-secret-create: ## Create sealed secret for argo cd repo
	kubeseal -n $(ARGOCD_NS) --cert assets/kubeseal.pem --format yaml < keys/secret-argocd-repo.yaml > apps/infra/private/base/sealedsecret-argocd-repo.yaml

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

.PHONY: set-gitops-rev
set-gitops-rev: ## Set gitops REV - defaults to current
	if [ -n "$(REV)" ] ; then rev=$(REV); else rev=$$(git rev-parse --abbrev-ref HEAD); fi ; \
	find envs -iname "*.yaml" | while read f ; do sed -i "s/evision: \"*[a-z].*/evision: $${rev}/g" "$${f}"; done

.PHONY:set-gitops-repo
set-gitops-repo: ## Set gitops repo to NEW_URL
	if [ -z "$(NEW_URL)" ] ; then echo "NEW_URL must not be empty"; exit 1; fi
	old_url=$$(grep repoURL: envs/local/app-root.yaml | sed -e s,'.*repoURL: ',,g); find envs -iname "*.yaml" | while read f ; do sed -i "s,$${old_url},$(NEW_URL),g" "$${f}"; done

.PHONY: install-tools
install-tools: ## Install all the tools
	mise install

#.PHONY: create-dashboard-configmaps
#create-dashboard-configmaps: ## Create dashboard ConfigMaps
#	$(KUBECTL) -n $(MONITORING_NS) create configmap dashboards-misc --from-file=./apps/infra/openshift-user-workload-monitoring/envs/local/assets/dashboards -o yaml --dry-run=client > ./apps/infra/monitoring/envs/local/configmap-dashboards.yaml
#	@echo
#	@echo "Make sure to add label for grafana sidecar"
#	@echo

.PHONY: show-alerts
show-alerts: ## Show firing alerts
	@$(KUBECTL) -n $(MONITORING_NS) exec -it alertmanager-kube-prometheus-stack-alertmanager-0 -- amtool alert -o $(AMTOOL_OUTPUT) --alertmanager.url=http://alertmanager-operated:9093

.PHONY: argocd-disable-sync
argocd-disable-sync: ## Disable sync for all argo cd apps
	for app in argo-cd root; do \
		argocd app set $$app --sync-policy none; \
	done
	for appset in $$(kubectl get applicationsets -n argocd -o name); do \
		$(KUBECTL) patch $$appset -n argocd --type merge -p '{"spec":{"template":{"spec":{"syncPolicy":{"automated": null}}}}}'; \
	done

.PHONY: argocd-enable-sync
argocd-enable-sync: ## Enable sync for all argo cd apps
	for app in argo-cd root; do \
		argocd app set $$app --sync-policy auto ; \
		argocd app sync $$app; \
	done

.PHONY: argocd-remove-appsets-only
argocd-remove-appsets-only: ## Remove appsets only
	$(KUBECTL) -n $(ARGOCD_NS) patch argocd argocd --type=merge -p='{"spec":{"applicationSet":{"enabled":false}}}'
	$(KUBECTL) -n $(ARGOCD_NS) wait --for=jsonpath='{.status.applicationSetController}'=Unknown argocd/argocd
	$(KUBECTL) -n $(ARGOCD_NS) get applicationset -o name | xargs -r -I {} $(KUBECTL) -n $(ARGOCD_NS) patch {} --type=json -p='{"metadata":{"ownerReferences":null}}' --type merge
	$(KUBECTL) -n $(ARGOCD_NS) get applicationset -o name | xargs -r $(KUBECTL) -n $(ARGOCD_NS) delete

.PHONY: get-mon-webhook-logs
get-mon-webhook-logs: ## Get monitoring webhook	logs
	$(KUBECTL) -n $(MONITORING_NS) logs -l app.kubernetes.io/instance=monitoring-webhook

.PHONY: olmv0-install
olmv0-install: ## Ad hoc install olmv0
	helm upgrade -i olm oci://ghcr.io/cloudtooling/helm-charts/olm --version 0.30.0 -f tf/values-olm.yaml
	# Shell based install not in harmony with openshift
	# curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.30.0/install.sh | bash -s v0.30.0

.PHONY: olmv1-install
olmv1-install: ## Ad hoc install olmv1
	curl -L -s https://github.com/operator-framework/operator-controller/releases/latest/download/install.sh | bash -s

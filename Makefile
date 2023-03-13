KUBECTL=kubectl
CA_CERTS_FILE=/etc/ssl/certs/ca-certificates.crt
SSH_PUB_KEY=keys/id_rsa-argocd-conductr.pub
ARGOCD_NS=argocd
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

create_age_key:
	age-keygen -o ./key.txt

#create_gpg_secret:
## --dry-run -o yaml 
#	gpg --export-secret-keys --armor "$(GPG_ID)" | \
#		kubectl create secret generic sops-gpg --namespace=argocd --from-file=sops.asc=/dev/stdin

create_age_secret:
	cat ./key.txt | kubectl create secret generic sops-age --namespace=argocd \
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


# /usr/local/share/ca-certificates/extra/mitmproxy-ca-cert.crt
.PHONY: create-ca-res
create-ca-res: target/manifest-ca-certs.yaml

target/manifest-ca-certs.yaml: target ## Recreate ca certs manifests
	cat $(CA_CERTS_FILE) | $(KUBECTL) create configmap ca-certs --from-file=ca-certificates.crt=/dev/stdin --dry-run=client -o yaml > target/manifest-ca-certs.yaml

.PHONY: recreate-argocd-ca-res
recreate-argocd-ca-res: target/manifest-ca-certs.yaml ## Re-create ArgoCD ca certs
	$(KUBECTL) -n $(ARGOCD_NS) delete configmap ca-certs || true
	$(KUBECTL) -n $(ARGOCD_NS) create -f target/manifest-ca-certs.yaml

.PHONY: fmt
fmt: ## Format
	terraform fmt --check --recursive

.PHONY: lint
lint: ## Lint
	tflint --recursive

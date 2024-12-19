# TODO: Imperative af
PV_SIZE=12Gi
TOOLS_DIR=.
STORAGE_CLASSES=ceph-rbd cephfs
CEPH_SERVICE_PROFILE=ceph-service
CEPH_CONSUMER_PROFILE=ceph-consumer
CEPH_SANDBOX_PROFILE=ceph-sandbox

# TODO: Beware of the two k8s contexts!
.DEFAULT_GOAL := help


.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: create-ceph-sandbox-cluster
create-ceph-sandbox-cluster: ## Create Ceph Service Cluster (deprecated)
	ROOK_PROFILE_NAME=$(CEPH_SANDBOX_PROFILE) ./create-ceph-service.sh -m # -r (orchestrator via tools)
	./configure-ceph-service.sh
	 kubectl -n rook-ceph wait --for=jsonpath='{.status.phase}'=Ready cephblockpool/replicapool
	 kubectl -n rook-ceph wait --for=jsonpath='{.status.phase}'=Ready cephobjectstore/my-store
	 kubectl -n rook-ceph wait --for=jsonpath='{.status.phase}'=Ready cephfilesystem/myfs
	 kubectl -n rook-ceph wait --timeout=180s --for=jsonpath='{.subsets[0].addresses[0].nodeName}'=$(CEPH_SERVICE_PROFILE) ep/rook-ceph-rgw-my-store
	$(TOOLS_DIR)/export-config.sh


.PHONY: create-ceph-service-cluster
create-ceph-service-cluster: ## Create Ceph Service Cluster
	minikube --container-runtime=containerd --disk-size=40g --extra-disks=3 --cpus=2 --driver=kvm2 --network=default --profile $(CEPH_SERVICE_PROFILE) start
	minikube --profile $(CEPH_SERVICE_PROFILE) addons enable metrics-server
	make setup-prometheus
	VALUES_SUFFIX=-mini-service $(TOOLS_DIR)/install-rook.sh
	./configure-ceph-service.sh
	 kubectl -n rook-ceph wait --timeout=180s --for=jsonpath='{.status.phase}'=Ready cephblockpool/replicapool
	 kubectl -n rook-ceph wait --timeout=180s --for=jsonpath='{.status.phase}'=Ready cephobjectstore/my-store
	 kubectl -n rook-ceph wait --timeout=180s  -for=jsonpath='{.status.phase}'=Ready cephfilesystem/myfs
	 kubectl -n rook-ceph wait --timeout=180s --for=jsonpath='{.subsets[0].addresses[0].nodeName}'=$(CEPH_SERVICE_PROFILE) ep/rook-ceph-rgw-my-store
	$(TOOLS_DIR)/export-config.sh

.PHONY: create-ceph-consumer-cluster
create-ceph-consumer-cluster: ## Create Ceph Consumer Cluster
	# Need 3 cpus to get cephfs provisioner working
	minikube --container-runtime=containerd --cpus=3 --driver=kvm2 --network=default --profile $(CEPH_CONSUMER_PROFILE) start
	minikube --profile $(CEPH_CONSUMER_PROFILE) addons enable volumesnapshots
	minikube --profile $(CEPH_CONSUMER_PROFILE) addons enable metrics-server
	make setup-prometheus setup-ceph-csi-ext 
	kubectl -n rook-ceph wait --timeout=180s --for=jsonpath='{.status.state}'=Connected cephcluster/rook-ceph
	$(TOOLS_DIR)/configure-ceph-consumer.sh
	$(TOOLS_DIR)/setup-velero.sh

.PHONY: destroy-ceph-service-cluster
destroy-ceph-service-cluster: ## Destroy Ceph Service Cluster
	minikube --profile $(CEPH_SERVICE_PROFILE) delete

.PHONY: destroy-ceph-consumer-cluster
destroy-ceph-consumer-cluster: ## Destroy Ceph Consumer Cluster
	minikube --profile $(CEPH_CONSUMER_PROFILE) delete

.PHONY: setup-ceph-csi-ext
setup-ceph-csi-ext: ## Setup Ceph CSI
	VALUES_SUFFIX= $(TOOLS_DIR)/install-rook.sh
	$(TOOLS_DIR)/import-external-cluster.sh

.PHONY: setup-prometheus
setup-prometheus: ## Setup Prometheus
	helm install prometheus \
  	kube-prometheus-stack \
  	--repo https://prometheus-community.github.io/helm-charts \
  	--namespace monitoring \
  	--create-namespace \
  	--set defaultRules.enabled=false \
  	--set prometheus.enabled=true \
  	--set alertmanager.enabled=false \
  	--set grafana.enabled=false \
  	--set kubernetesServiceMonitors.enabled=false \
  	--set kubeApiServer.enabled=false \
  	--set kubelet.enabled=false \
  	--set kubeControllerManager.enabled=false \
  	--set coreDns.enabled=false \
  	--set kubeEtcd.enabled=false \
  	--set kubeScheduler.enabled=false \
  	--set kubeProxy.enabled=false \
  	--set kubeStateMetrics.enabled=false \
  	--set nodeExporter.enabled=false

.PHONY: show-rook-resource-requests
show-rook-resource-requests: ## Show Rook Resource Requests
	kubectl get pods -n rook-ceph -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,MEMORY_REQUEST:.spec.containers[*].resources.requests.memory,CPU_REQUEST:.spec.containers[*].resources.requests.cpu"

.PHONY: test-csi-io
test-csi-io: ## Run CSI IO Test
	for sc in $(STORAGE_CLASSES); do kubestr fio -s $${sc} -z $(PV_SIZE); done

.PHONY: test-csi-snapshot
test-csi-snapshot: ## Test CSI Snapshot
	for sc in $(STORAGE_CLASSES); do kubestr csicheck -s $${sc} -v $${sc}; done

.PHONY: test-s3-io
test-s3-io: ## Run S3 IO Test
	kubectl delete -f manifests/job-ob.yaml || true
	kubectl apply -f manifests/job-ob.yaml

.PHONY: test-velero
test-velero: ## Test Velero Backup
	kubectl delete -f manifests/nginx.yaml 2 >/dev/null || true
	kubectl delete -f manifests/backup-rbd-pvc.yaml 2>/dev/null || true 
	. ./s3-bucket-env.sh && aws s3 rm --recursive s3://$${BUCKET_NAME}/backups || true 
	kubectl apply -f manifests/backup-rbd-pvc.yaml
	kubectl apply -f manifests/backup-rbd-pvc.yaml
	kubectl -n velero wait --for=jsonpath='{.status.phase}'=Completed backup/rbd-pvc

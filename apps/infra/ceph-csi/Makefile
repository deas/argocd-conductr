PV_SIZE=12Gi
CEPH_SERVICE_PROFILE=ceph-service
CEPH_CONSUMER_PROFILE=ceph-consumer

# TODO: Beware of the two k8s contexts!
.DEFAULT_GOAL := help


.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: create-dev-service-cluster
create-dev-service-cluster: ## Create external ceph dev cluster
	ROOK_PROFILE_NAME=$(CEPH_SERVICE_PROFILE) ./create-dev-cluster.sh
	./configure-dev-cluster.sh
	 kubectl -n rook-ceph wait --for=jsonpath='{.status.phase}'=Ready cephblockpool/replicapool
	 kubectl -n rook-ceph wait --for=jsonpath='{.status.phase}'=Ready cephobjectstore/my-store
	 kubectl -n rook-ceph wait --for=jsonpath='{.status.phase}'=Ready cephfilesystem/myfs
	 kubectl -n rook-ceph wait --timeout=180s --for=jsonpath='{.subsets[0].addresses[0].nodeName}'=$(CEPH_SERVICE_PROFILE) ep/rook-ceph-rgw-my-store
	./export-config.sh


.PHONY: create-dev-consumer-cluster
create-dev-consumer-cluster: ## Create ceph consumer cluster
	# Need 3 cpus to get cephfs provisioner working
	minikube --container-runtime=containerd --cpus=3 --driver=kvm2 --network=default --profile $(CEPH_CONSUMER_PROFILE) start
	minikube --profile $(CEPH_CONSUMER_PROFILE) addons enable volumesnapshots
	make setup-ceph-csi-ext
	kubectl -n rook-ceph wait --for=jsonpath='{.status.state}'=Connected cephcluster/rook-ceph

.PHONY: destroy-dev-service-cluster
destroy-dev-service-cluster: ## Destroy exteral ceph dev cluster
	minikube --profile $(CEPH_SERVICE_PROFILE) delete

.PHONY: setup-ceph-csi-ext
setup-ceph-csi-ext: ## Setup Ceph CSI
	./install-rook-external.sh
	./import-external-cluster.sh

.PHONY: test-ceph-rbd
test-ceph-rbd: ## Run fio test on ceph-rbd
	kubestr fio -s ceph-rbd -z $(PV_SIZE)

.PHONY: test-cephfs
test-cephfs: ## Run fio test on cephfs
	kubestr fio -s cephfs -z $(PV_SIZE)



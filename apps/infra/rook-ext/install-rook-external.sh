#!/bin/bash
set -e

OPERATOR_NS=${OPERATOR_NS:="rook-ceph"}
ROOK_CLUSTER_NS=${ROOK_CLUSTER_NS:="rook-ceph"}
REPO=https://charts.rook.io/release

# cd deploy/examples/charts/rook-ceph-cluster
# helm repo add rook-release https://charts.rook.io/release
helm install --create-namespace --namespace ${ROOK_CLUSTER_NS} --repo ${REPO} rook-ceph rook-ceph \
  -f charts/rook-ceph//values.yaml
helm install --create-namespace --namespace ${ROOK_CLUSTER_NS} --repo ${REPO} rook-ceph-cluster rook-ceph-cluster \
  --set operatorNamespace=${OPERATOR_NS} -f charts/rook-ceph-cluster/values.yaml

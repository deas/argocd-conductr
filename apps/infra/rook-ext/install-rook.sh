#!/bin/bash
set -e

VALUES_SUFFIX=${VALUES_SUFFIX:=""}
OPERATOR_NS=${OPERATOR_NS:="rook-ceph"}
ROOK_CLUSTER_NS=${ROOK_CLUSTER_NS:="rook-ceph"}
REPO=https://charts.rook.io/release

# helm repo add rook-release https://charts.rook.io/release
#
helm upgrade --install --create-namespace --namespace ${ROOK_CLUSTER_NS} --repo ${REPO} rook-ceph rook-ceph \
  -f charts/rook-ceph/values${VALUES_SUFFIX}.yaml

helm upgrade --install --create-namespace --namespace ${ROOK_CLUSTER_NS} --repo ${REPO} rook-ceph-cluster rook-ceph-cluster \
  --set operatorNamespace=${OPERATOR_NS} -f charts/rook-ceph-cluster/values${VALUES_SUFFIX}.yaml

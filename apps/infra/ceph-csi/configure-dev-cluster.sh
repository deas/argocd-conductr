#!/bin/bash

set -e

# ./deploy/examples/cephfs-test.yaml
# ./deploy/examples/filesystem-test.yaml
# ./deploy/examples/object-multisite-test.yaml
# ./deploy/examples/object-separate-pools-test.yaml
# ./deploy/examples/cluster-multus-test.yaml
# ./deploy/examples/nfs-test.yaml
# ./deploy/examples/object-test.yaml
# ./deploy/examples/csi/rbd/storageclass-test.yaml
# ./deploy/examples/cluster-test.yaml
# ./deploy/examples/object-shared-pools-test.yaml
# ./deploy/examples/two-object-one-zone-test.yaml
# ./deploy/examples/pool-test.yaml
# ./deploy/examples/object-multisite-pull-realm-test.yaml
# ./deploy/examples/multus-validation-test-openshift.yaml

manifest_path=manifests

# deploy/examples

# https://rook.io/docs/rook/latest/CRDs/Cluster/external-cluster/provider-export/
# minikube --profile rook addons enable volumesnapshots

kubectl apply -f ${manifest_path}/filesystem-test.yaml
# TODO: nfs-ganesha-1[main] Bind_sockets :DISP :FATAL :Error binding to V6 interface. Cannot continue.
# kubectl apply -f ${manifest_path}/nfs-test.yaml
kubectl apply -f ${manifest_path}/object-test.yaml
kubectl apply -f ${manifest_path}/pool-test.yaml
# kubectl apply -f ${manifest_path}/csi/rbd/storageclass-test.yaml
# minikube addons enable volumesnapshots
# kubectl apply -f ${manifest_path}/csi/cephfs/snapshotclass.yaml
# kubectl apply -f ${manifest_path}/csi/rbd/snapshotclass.yaml
# kubectl apply -f ${manifest_path}/csi/nfs/snapshotclass.yaml

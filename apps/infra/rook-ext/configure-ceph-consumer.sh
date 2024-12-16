#!/bin/bash

set -e

source ./config.ini

RGW_EP=$(echo $RGW_ENDPOINT | cut -d : -f 1)

manifest_path=manifests/ceph-consumer

cat ${manifest_path}/cos-my-store.yaml |
  sed -e s/" ip: .*"/" ip: ${RGW_EP}"/g |
  kubectl apply -f -
kubectl apply -f ${manifest_path}/storageclass-my-store.yaml
kubectl apply -f ${manifest_path}/obc-my-store.yaml
kubectl apply -f ${manifest_path}/snapshotclass-cephfs.yaml
kubectl apply -f ${manifest_path}/snapshotclass-ceph-rbd.yaml

kubectl wait --timeout=180s --for=jsonpath='{.status.phase}'=Bound obc/my-store

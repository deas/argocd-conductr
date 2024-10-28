#!/bin/sh
set -xe

TEMPLATE=$1

export BROKER_NS=submariner-k8s-broker
export SUBMARINER_NS=submariner-operator

# kubectl -n ${SUBMARINER_NS} run -i -t kubectl --image=bitnami/kubectl --restart=Never --overrides='{ "spec": { "serviceAccount": "broker-reader" }  }' --command -- /bin/sh
# kubectl -n ${BROKER_NS} get secrets -o json | jq -r -c '[.items[] | select(.metadata.annotations."kubernetes.io/service-account.name"=="submariner-k8s-broker-client") | select(.data.token != null)] | .[0].data.token' | base64 --decode

export SUBMARINER_BROKER_TOKEN=$(kubectl -n "${BROKER_NS}" get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='${BROKER_NS}-client')].data.token}" | base64 --decode)
export SUBMARINER_BROKER_CA=$(kubectl -n ${BROKER_NS} get secrets -o json | jq -r -c '[.items[] | select(.metadata.annotations."kubernetes.io/service-account.name"=="submariner-k8s-broker-client") | select(.data."ca.crt" != null)] | .[0].data."ca.crt"')
export SUBMARINER_BROKER_URL=$(kubectl -n default get endpoints kubernetes -o jsonpath="{.subsets[0].addresses[0].ip}:{.subsets[0].ports[?(@.name=='https')].port}")

cat "${TEMPLATE}" | envsubst | tee | kubectl -n "${SUBMARINER_NS}" apply -f -

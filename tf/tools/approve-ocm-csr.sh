#!/bin/bash

set -e

cluster_name=$1 #$(echo "$input" | jq -r .cluster_name)
# namespace=$(echo "$input" | jq -r .namespace)
# context=$(echo "$input" | jq -r .context)
# server=$(echo "$input" | jq -r .server)
timeout=$2 #$2 #$(echo "$input" | jq -r .timeout)

# echo "$sa"
# echo "$namespace"
# echo "$timeout"

if [ -z "$cluster_name" ]; then
  echo "Usage: $0 <cluster_name> <timeout>"
  exit 1
fi

seconds=0
interval=5

while true; do
  # kubectl -n open-cluster-management create token cluster-bootstrap
  if [ $(kubectl get csr -l open-cluster-management.io/cluster-name=${cluster_name} -o name | wc -l) -eq 1 ] && kubectl get managedclusters "${cluster_name}"; then
    kubectl get csr -l open-cluster-management.io/cluster-name=${cluster_name} -o name | xargs kubectl certificate approve
    kubectl patch managedclusters ${cluster_name} -p '{"spec":{"hubAcceptsClient":true}}' --type merge
    exit 0
  fi

  if [ "$seconds" -ge "$timeout" ]; then
    echo "{Timed out after $timeout seconds waiting for service account '$sa'.}"
    exit 1
  fi

  sleep $interval
done

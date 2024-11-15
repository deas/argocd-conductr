#!/bin/bash

set -e

input=$(cat)

# read -r sa namespace < <(jq -r '.sa, .namespace')

sa=$(echo "$input" | jq -r .sa)
namespace=$(echo "$input" | jq -r .namespace)
# context=$(echo "$input" | jq -r .context)
server=$(echo "$input" | jq -r .server)
timeout=$(echo "$input" | jq -r .timeout)

# echo "$sa"
# echo "$namespace"
# echo "$timeout"

if [ -z "$sa" ] || [ -z "$namespace" ]; then
  echo "Usage: $0 <sa> <namespace> [timeout]"
  exit 1
fi

seconds=0
interval=5

while true; do
  # kubectl -n open-cluster-management create token cluster-bootstrap
  if kubectl get serviceaccount "$sa" -n "$namespace" &>/dev/null; then
    current_context=$(kubectl config current-context)
    cluster_name=$(kubectl config view -o jsonpath="{.contexts[?(@.name == \"$current_context\")].context.cluster}")
    if [ "${server}" == "null" ]; then
      server=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$cluster_name\")].cluster.server}")
    fi
    certificate_authority_data=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name == \"$cluster_name\")].cluster.certificate-authority-data}")
    kubectl -n "$namespace" create token "$sa" -o json | jq '.status' | jq '. += {"server":"'${server}'", "certificate-authority-data": "'${certificate_authority_data}'"}'
    exit 0
  fi

  if [ "$seconds" -ge "$timeout" ]; then
    echo "{Timed out after $timeout seconds waiting for service account '$sa'.}"
    exit 1
  fi

  sleep $interval
done

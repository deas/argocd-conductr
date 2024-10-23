#!/bin/bash

set -e

input=$(cat)

# read -r resource namespace < <(jq -r '.resource, .namespace')

resource=$(echo "$input" | jq -r .resource)
namespace=$(echo "$input" | jq -r .namespace)
timeout=$(echo "$input" | jq -r .timeout)

# echo "$resource"
# echo "$namespace"
# echo "$timeout"

if [ -z "$resource" ] || [ -z "$namespace" ]; then
  echo "Usage: $0 <resource> <namespace> [timeout]"
  exit 1
fi

seconds=0
interval=5
broker_server=$(kubectl -n default get endpoints kubernetes -o jsonpath="{.subsets[0].addresses[0].ip}:{.subsets[0].ports[?(@.name=='https')].port}")

while true; do
  if kubectl get "$resource" -n "$namespace" &>/dev/null; then
    # echo "'$resource' found in namespace '$namespace'."
    kubectl get "$resource" -n "$namespace" -o jsonpath='{.data}' | jq '. += {"broker_server":"'${broker_server}'"} | .namespace = (.namespace | @base64d) | .token = (.token | @base64d)'
    exit 0
  fi

  if [ "$seconds" -ge "$timeout" ]; then
    echo "{Timed out after $timeout seconds waiting for secret '$resource'.}"
    exit 1
  fi

  sleep $interval
done

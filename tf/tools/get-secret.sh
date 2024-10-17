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

while true; do
  if kubectl get "$resource" -n "$namespace" &>/dev/null; then
    # echo "'$resource' found in namespace '$namespace'."
    kubectl get "$resource" -n "$namespace" -o jsonpath='{.data}'
    exit 0
  fi

  if [ "$seconds" -ge "$timeout" ]; then
    echo "{Timed out after $timeout seconds waiting for secret '$resource'.}"
    exit 1
  fi

  sleep $interval
done

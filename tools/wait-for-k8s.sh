#!/bin/bash
RESOURCE=$1
NAMESPACE=$2
TIMEOUT=${3:-60}
INTERVAL=5

set -e

if [ -z "$RESOURCE" ] || [ -z "$NAMESPACE" ]; then
  echo "Usage: $0 <resource> <namespace> [timeout]"
  exit 1
fi

SECONDS=0

echo "Waiting for '$RESOURCE' to exist in namespace '$NAMESPACE' (timeout: $TIMEOUT seconds)..."

while true; do
  if kubectl get "$RESOURCE" -n "$NAMESPACE" &>/dev/null; then
    echo "'$RESOURCE' found in namespace '$NAMESPACE'."
    exit 0
  fi

  if [ "$SECONDS" -ge "$TIMEOUT" ]; then
    echo "Timed out after $TIMEOUT seconds waiting for secret '$RESOURCE'."
    exit 1
  fi

  sleep $INTERVAL
done

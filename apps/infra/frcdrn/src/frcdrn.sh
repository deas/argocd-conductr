#!/bin/sh

set -e

: ${MIN_AGE:="0"}
: ${MAX_AGE:="1000000"}
: ${LABELS:="!node-role.kubernetes.io/control-plane,!frcdrn/ignore""}

echo "Draining ready and unschedulable nodes labeled ${LABELS} stuck more than ${MIN_AGE} seconds and less than ${MAX_AGE} seconds"

# 🤪
kubectl get nodes -l "${LABELS}" -o json | jq -r '
  .items[]
  | select(.spec.taints != null
           and (.spec.taints[]
               | select(.key == "node.kubernetes.io/unschedulable"
                        and .effect == "NoSchedule"
                        and (.timeAdded != null
                             and ((now - (.timeAdded | fromdateiso8601)) > '"${MIN_AGE}"')
                             and ((now - (.timeAdded | fromdateiso8601)) < '"${MAX_AGE}"')))))
  | .metadata.name' |
  while read node; do
    echo "Force draining ${node}"
    kubectl drain "${node}" --ignore-daemonsets --delete-emptydir-data --disable-eviction --force
    echo "Done draining ${node} ($?)"
  done

echo "done"
# TODO: Alert manager should probably cover issues caused by nodes stuck longer than max age

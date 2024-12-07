#!/bin/sh

ns=operators
subs=$(kubectl -n ${ns} get subscriptions -l app.kubernetes.io/managed-by=Helm -o jsonpath='{range .items[*]}{.metadata.name} {end}')

kubectl -n ${ns} create configmap operator-subs --from-literal="subs=${subs}" -o yaml --dry-run=client | kubectl -n ${ns} apply -f -

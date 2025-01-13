#!/bin/bash
# kubectl -n openshift-gitops get secret openshift-gitops-cluster -o yaml
# kubectl -n openshift-gitops get route openshift-gitops-server -o yaml
# kubectl -n openshift-gitops get csv openshift-gitops-operator.v1.14.2 -o yaml
# kubectl -n openshift-gitops get argocd openshift-gitops -o yaml

set -e

action=$1

if kubectl get ns openshift-gitops >/dev/null 2>&1; then
  ns=openshift-gitops
  argocd_args=
  secret=openshift-gitops-cluster
  secret_key=admin.password
  # secret=argocd-initial-admin-secret
  csv=openshift-gitops-operator.v1.14.2
  route=openshift-gitops-server
  argocd=openshift-gitops
  svc_label=openshift-gitops-server
  argocd_ep=$(kubectl -n ${ns} get route ${route} -o jsonpath="{.spec.host}")
else
  ns=argocd
  argocd_args=--insecure
  if kubectl -n ${ns} get argocd argocd >/dev/null 2>&1; then
    secret=argocd-cluster
    secret_key=admin.password
    # csv=openshift-gitops-operator.v1.14.2
  else
    secret=argocd-initial-admin-secret
    secret_key=password
  fi
  csv=openshift-gitops-operator.v1.14.2
  route=openshift-gitops-server
  argocd=argocd
  svc_label=argocd-server
  argocd_ep=$(kubectl -n default get endpoints kubernetes -o jsonpath="{.subsets[0].addresses[0].ip}"):$(kubectl -n ${ns} get svc -l app.kubernetes.io/name=${svc_label} -o jsonpath='{.items[0].spec.ports[?(@.name=="http")].nodePort}')
fi

pass=$(kubectl -n ${ns} get secret ${secret} -o jsonpath="{.data}" 2>/dev/null | jq -r '."'${secret_key}'" | @base64d')

# echo ${pass}
# echo ${argocd_ep}
if [ "${action}" == "show-pass" ]; then
  echo "${pass}"
elif [ "${action}" == "login" ]; then
  argocd login ${argocd_args} --plaintext --username admin --password ${pass} ${argocd_ep}
else
  echo "Unknown action \"${action}\""
  exit 1
fi

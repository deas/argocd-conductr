#!/bin/sh
set -ex
# TODO: Should likely end up as a helm hook
# https://cloud.redhat.com/blog/openshift-authentication-integration-with-argocd
# https://dexidp.io/docs/connectors/openshift
#
# kubectl -n argocd patch cm argocd-cm --patch-file assets/patch-argocd-openshift-auth.yaml
# kubectl -n argocd apply view-last-applied cm/argocd-cm | kubectl -n argocd apply -f -
# argocd_host=$(oc get route argocd-server -o jsonpath='{.spec.host}')

: "${ns:=argocd}"
: "${sa:=argocd-dex-server}"
: "${argocd_host:=argocd-server.local}"
: "${issuer:="https://localhost:6443"}"
# issuer=$(oc whoami --show-server)

cat <<EOF | kubectl -n ${ns} apply -f -
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: ${sa}
  annotations:
    kubernetes.io/service-account.name: ${sa}
EOF

token=$(kubectl -n ${ns} get secrets/${sa} --template="{{index .data \"token\" | base64decode}}")
patch=$(mktemp --suffix=.yaml)

cat <<EOF > $patch
data:
  url: "https://${argocd_host}"
  dex.config: |
    connectors:
      # OpenShift
      - type: openshift
        id: openshift
        name: OpenShift
        config:
          issuer: "${issuer}"
          clientID: "system:serviceaccount:${ns}:${sa}"
          clientSecret: "${token}"
          redirectURI: "https://${argocd_host}/api/dex/callback"
          insecureCA: true
        #   groups:
        #     - argocdusers
        #     - argocdadmins
EOF

kubectl -n ${ns} patch cm argocd-cm --patch-file ${patch}

rm -f ${patch}
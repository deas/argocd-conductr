#!/bin/bash

set -e

# ns=velero

source ./s3-bucket-env.sh

helm upgrade --install --create-namespace --namespace velero --repo https://vmware-tanzu.github.io/helm-charts velero velero \
  -f ../velero/envs/local/values.yaml \
  --set configuration.backupStorageLocation[0].bucket=${BUCKET_NAME} \
  --set configuration.backupStorageLocation[0].credential.name=cloud-credentials \
  --set configuration.backupStorageLocation[0].credential.key=content \
  --set configuration.backupStorageLocation[0].config.s3Url=${AWS_ENDPOINT_URL}

secret_content=$(
  cat <<EOF | base64 -w 0
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
)

cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  content: ${secret_content}
kind: Secret
metadata:
  name: cloud-credentials
  namespace: velero
EOF

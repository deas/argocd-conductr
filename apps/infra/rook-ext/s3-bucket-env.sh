#!/bin/sh
#config-map, secret, OBC will part of default if no specific name space mentioned
ns=default
bucket=my-store
export AWS_HOST=$(kubectl -n ${ns} get cm ${bucket} -o jsonpath='{.data.BUCKET_HOST}')
export PORT=$(kubectl -n ${ns} get cm ${bucket} -o jsonpath='{.data.BUCKET_PORT}')
export BUCKET_NAME=$(kubectl -n ${ns} get cm ${bucket} -o jsonpath='{.data.BUCKET_NAME}')
export AWS_ACCESS_KEY_ID=$(kubectl -n ${ns} get secret ${bucket} -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 --decode)
export AWS_SECRET_ACCESS_KEY=$(kubectl -n ${ns} get secret ${bucket} -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 --decode)
export AWS_ENDPOINT_URL=http://${AWS_HOST}:${PORT}

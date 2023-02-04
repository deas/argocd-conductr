#!/bin/sh
# TODO: Pull stuff from tf

set -xe

. $(dirname $0)/flux-env.sh

flux bootstrap github \
  --owner=${GITHUB_USER} \
  --log-level debug \
  --repository=${GITHUB_REPO} \
  --branch=${BRANCH} \
  --personal \
  --read-write-key \
  --components-extra=image-reflector-controller,image-automation-controller \
  --path=${CLUSTER_PATH}

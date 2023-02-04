#!/bin/sh

name=flux-conductr
full_path=$(realpath $0)
dir_path=$(dirname $full_path)
key_dir="$(dirname $dir_path)/keys"

gh repo deploy-key add "${key_dir}/id_${name}.pub" -t ${name} -w
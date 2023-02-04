#!/bin/sh

name=flux-conductr
full_path=$(realpath $0)
dir_path=$(dirname $full_path)
key_dir="$(dirname $dir_path)/keys"

gpg --import "${key_dir}/${name}-pub.asc"
gpg --import "${key_dir}/${name}-priv.asc"
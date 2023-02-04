#!/bin/sh

name=flux-conductr
domain=contentreich.de

full_path=$(realpath $0)
dir_path=$(dirname $full_path)
key_dir="$(dirname $dir_path)/keys"

ssh-keygen -N "" -C "${name}" -f "${key_dir}/id_rsa-${name}"

gpg --batch --gen-key <<EOF
Key-Type: 1
Key-Length: 2048
Subkey-Type: 1
Subkey-Length: 2048
Name-Real: ${name}
Name-Email: ${name}@${domain}
Expire-Date: 0
EOF

gpg --armor --output "${key_dir}/${name}-pub.asc" --export ${name}@${domain}
gpg --armor --output "${key_dir}/${name}-priv.asc" --export-secret-key ${name}@${domain}

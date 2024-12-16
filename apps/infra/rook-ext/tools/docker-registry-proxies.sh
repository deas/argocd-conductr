#!/bin/bash

# ghcr-proxy quay-proxy docker-proxy k8s-proxy
containers=("$@")

for container in "${containers[@]}"; do
  container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container")
  echo "$container_ip $container"
done

# Ceph CSI

## Problem statement

We want to use the Ceph CSI driver to consume from an external cluster. Wiring this is is a bit tricky, as it involves building a trust relationship including key exchange.

Aiming at a fast development cycle, we also want a local environment.

Ideally, this would be fully covered by ArgoCD and terraform and making the local bit an implementation detail.

However, we need to get things going first.

Hence, we start by borrowing proven things and adapting them as we go. Naturally, this starts by learning from the Rook developers. Thats how we arrive at minikube for external server.

## TODO

- Introduce pull through cache on kvm [Set Up Docker Registry Mirror as a Docker Hub Pull-through Cache for Minikube Local K8s Cluster](https://itnext.io/set-up-docker-registry-mirror-as-a-docker-hub-pull-through-cache-for-minikube-local-k8s-cluster-1874ade89341)
- Introduce IPv6

## Known Issues

- ["To sum up: the Docker daemon does not currently support multiple registry mirrors ..."](https://blog.alexellis.io/how-to-configure-multiple-docker-registry-mirrors/) -> `minikube start --registry-mirror="http://yourmirror"`

FROM busybox
ARG CLUSTERADM_VERSION=0.9.0
RUN wget -qO- https://github.com/open-cluster-management-io/clusteradm/releases/download/v${CLUSTERADM_VERSION}/clusteradm_linux_amd64.tar.gz | tar xzvf - clusteradm
CMD ["/clusteradm"]

#!/bin/bash
ns=rook-ceph
pool=replicapool
# TODO: unable to connect to endpoint: 192.168.122.74:9926, failed error: HTTPSConnectionPool(host='192.168.122.74', port=9926): Read timed out
# monitoring_ep=$(kubectl -n rook-ceph get endpoints -l app=rook-ceph-exporter -o jsonpath="{.items[0].subsets[0].addresses[0].ip}")
# monitoring_ep_port=$(kubectl -n rook-ceph get endpoints -l app=rook-ceph-exporter -o jsonpath="{.items[0].subsets[0].ports[?(@.name=='ceph-exporter-http-metrics')].port}")
rgw_ep=$(kubectl -n rook-ceph get endpoints -l app=rook-ceph-rgw -o jsonpath="{.items[0].subsets[0].addresses[0].ip}:{.items[0].subsets[0].ports[?(@.name=='http')].port}")
# https://rook.io/docs/rook/latest/CRDs/Cluster/external-cluster/provider-export/
create_script=./create-external-cluster-resources.py
cat ${create_script} | kubectl exec -i -n ${ns} deploy/rook-ceph-tools -- \
  python3 - \
  --rbd-data-pool-name ${pool} \
  --rgw-endpoint ${rgw_ep} \
  --namespace ${ns} \
  --format bash \
  >config.ini

#  --monitoring-endpoint ${monitoring_ep} \
#  --monitoring-endpoint-port ${monitoring_ep_port} \
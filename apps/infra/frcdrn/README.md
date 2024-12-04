# Force Drain Kubernetes Nodes

## Problem statement

In Kubernetes, there are situations triggering node drainage that can easily get stuck ending up with nodes being `Ready` and `unschedulable` while still running pods.

We aim at automating away at least one common reason frequently hitting us: Unawareness of PodDisruptionBudgets

[This manifest](./test/manifest-drainfail.yaml) illustrates the "trap".

Openshift easily falls for it when machine config chooses to reboot. This usually happens when upgrading a cluster, but there are other situations as well. Another example is changing the global `Proxy` object.

This machine config behavior is likely [by design](https://github.com/openshift/machine-config-operator/blob/master/docs/MachineConfigDaemon.md#node-drain). Hence, we should probably not start by hacking the draining bits in the MCO hoping for a PR to be merged upstream.

Patching PDBs "back and forth" around the upgrade at the very least causes worries when ArgoCD or Flux are at play.

So what else can be done about it?

One approach might be to counter this with policies preventing deployment of PDBs driving us into the issue. It's surely possible, but also appears to be complex to implement. We may choose to try this later on.

For now, We start out by running a basic tool watching out for the issue. We try our best to detect and fix it - even if that causes a service disruption. So be careful.

We also ship a basic `PrometheusRule` which could be used to kick off logic using an alerting webhook like [this one](../monitoring-webhook/).

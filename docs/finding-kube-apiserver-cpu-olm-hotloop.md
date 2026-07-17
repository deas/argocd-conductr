# Finding: kube-apiserver CPU stress from OLM hot-loop on `loki-operator`

**Date:** 2026-07-08
**Cluster:** `kind-argocd-conductr` (single-node kind, `v1.31.0`)
**Severity:** High — sustained control-plane CPU burn

## Summary

The kube-apiserver CPU stress is caused by a **reconcile storm from Operator
Lifecycle Manager (OLM)**, triggered by the OpenShift `loki-operator`
(`loki-operator.v0.10.2`) being unable to run on this vanilla kind cluster. The
operator crashloops, its `ClusterServiceVersion` (CSV) flaps roughly every 5
minutes, and OLM repeatedly rewrites the CSV and re-runs cluster-wide install
requirement checks — hammering the apiserver.

## Evidence

Apiserver request volume in ~100 minutes of uptime
(`kubectl get --raw /metrics` → `apiserver_request_total`):

| Requests | Verb          | Resource                          | Driver                     |
| -------- | ------------- | --------------------------------- | -------------------------- |
| ~45,000  | PUT + PUTstatus | `clusterserviceversions`        | OLM olm-operator           |
| ~32,000  | GET           | `customresourcedefinitions`       | OLM requirement checks     |
| ~32,000  | LIST          | `validatingwebhookconfigurations` | OLM requirement checks     |
| ~4,400   | LIST          | `mutatingwebhookconfigurations`   | OLM requirement checks     |

`loki-operator-controller-manager` pod: **15 restarts** (CrashLoopBackOff).

## Root cause chain

1. `loki-operator` (v0.10.2) is an **OpenShift operator running on a plain kind
   cluster**. Its manager tries to start watches on OpenShift-only APIs that do
   not exist here:
   - `config.openshift.io/v1` → `APIServer`, `Proxy`
   - `route.openshift.io/v1` → `Route`

   From the manager logs:

   ```
   if kind is a CRD, it should be installed before calling Start
     no matches for kind "APIServer" in version "config.openshift.io/v1"
     no matches for kind "Proxy" in version "config.openshift.io/v1"
     no matches for kind "Route" in version "route.openshift.io/v1"
   problem running manager: failed to wait for lokistack caches to sync
     kind source: *v1.APIServer: timed out waiting for cache to be synced
   error received after stop sequence was engaged: leader election lost
   ```

2. Cache sync for `*v1.APIServer` times out → manager exits → leader election
   lost → **container crashes** (repeats → 15 restarts).

3. Because the manager pod never stays healthy, its Deployment never stays
   "available", so OLM cycles the CSV through a ~5-minute flap loop:

   ```
   Installing → Failed (InstallCheckFailed) → Pending (NeedsReinstall)
     → InstallReady (AllRequirementsMet) → Installing → Succeeded
     → (operator crashes) → repeat
   ```

4. Every flap makes OLM rewrite the CSV (spec + status) many times and **re-run
   all install requirement checks**, which LIST every webhook config and GET
   every CRD in the cluster. That churn, plus the constant container restarts,
   is what stresses kube-apiserver CPU.

## Remediation

Best option first:

1. **Remove it** — stop OLM from reconciling the broken operator:

   ```bash
   kubectl -n openshift-operators delete subscription loki-operator
   kubectl -n openshift-operators delete csv loki-operator.v0.10.2
   ```

2. **Provide the missing APIs** if Loki is actually needed — install the
   OpenShift CRDs it watches (`config.openshift.io` APIServer/Proxy,
   `route.openshift.io` Route), or use a Loki install that does not depend on
   the OpenShift API surface.

3. **Pause temporarily** — scale the operator Deployment to 0 to stop the
   crashloop while deciding.

## Broader note

This kind cluster carries a lot of OpenShift-only stack (OLM, `openshift-*`
monitoring, submariner). Other operators may hit the same missing-OpenShift-API
problem and produce similar OLM hot-loops. Worth auditing the remaining
operators/CSVs for the same failure mode.

## Reproduction / diagnosis commands

```bash
# Top apiserver request sources by value
kubectl get --raw /metrics \
  | grep '^apiserver_request_total{' \
  | awk '{n=$NF; $NF=""; print n"\t"$0}' | sort -rn | head -15

# CSV flap history
kubectl -n openshift-operators get csv loki-operator.v0.10.2 \
  -o jsonpath='{range .status.conditions[*]}{.lastTransitionTime}{"  "}{.phase}{"  "}{.reason}{"\n"}{end}'

# Crash reason
kubectl -n openshift-operators logs \
  deploy/loki-operator-controller-manager -c manager --previous
```

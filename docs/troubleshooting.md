# Troubleshooting Log

Real issues hit while building this project, with root cause and fix.
Format: symptom → cause → fix.

---

## Phase 0 — Project Scaffold & State

*(No issues — reused existing backend, same pattern as projects 2-3.)*

## Phase 3 — EKS Cluster & Node Group

### `terraform apply` seems to hang for a very long time
**Cause:** not a bug — EKS control plane creation genuinely takes
10-15 minutes, and the node group needs a few more minutes after
that. This is the longest single wait across all four projects so
far, normal AWS behavior for this specific service.

### `aws eks describe-addon-versions` errors: version not found
**Cause:** the pinned `kubernetes_version` (default `1.31`) may no
longer be supported by the time you apply — AWS deprecates old EKS
versions on a rolling schedule, similar to RDS Postgres minor
versions.
**Fix:** check AWS's EKS release calendar for a currently-supported
version and add `kubernetes_version = "1.XX"` to `terraform.tfvars`
to override the default.

### `kubectl get nodes` shows nothing, or nodes stuck "NotReady"
**Cause:** usually just timing — nodes take a minute or two after the
node group finishes creating to fully register and become `Ready`.
**Fix:** wait and re-check. If still not ready after 5+ minutes,
confirm `aws eks update-kubeconfig` was run with the correct cluster
name and region, and check the node group's status in the AWS Console
for any launch failures.

# Phase 3 — EKS Cluster & Node Group

Creates: the EKS control plane, a managed node group (2x t3.small,
public subnets, no NAT), IAM roles for both, and an OIDC provider
scoped to this cluster (used in Phase 4 for the Load Balancer
Controller).

**This phase takes noticeably longer than anything so far** — EKS
control plane creation alone typically takes 10-15 minutes.

---

## 1. Install kubectl (one-time)

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

If `chmod`/`mv` fail with permission errors, prefix with `sudo` as
shown — should be fine on a standard Mac setup.

## 2. Check the Kubernetes version is still supported

```bash
aws eks describe-addon-versions --kubernetes-version 1.31 --profile cloud-resume --query "addons[0].addonVersions[0].addonVersion" --output text
```

If this errors out with something like "version not found," check
[AWS's EKS release calendar](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
for a currently-supported version and update `kubernetes_version` in
`terraform.tfvars` accordingly (add a line like
`kubernetes_version = "1.32"`).

## 3. Plan and apply

```bash
cd ~/projects/eks-guestbook/terraform
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect **10 resources to add**: 2 IAM roles + 5 policy attachments,
the EKS cluster, the node group, and the OIDC provider (the OIDC
provider's thumbprint is a hardcoded, well-known value — see
docs/troubleshooting.md for why, if you're curious).

```bash
terraform apply
```

**Expect 15-20 minutes total** — the cluster alone takes 10-15
minutes, and the node group needs a few more after that. This is
normal AWS behavior, not something wrong with the configuration.

## 4. Configure kubectl to talk to the cluster

```bash
aws eks update-kubeconfig --name eks-guestbook-cluster --region us-east-1 --profile cloud-resume
```

This writes connection details into `~/.kube/config`. Verify:

```bash
kubectl get nodes
```

Should show 2 nodes, both `Ready` (may take a minute or two after the
node group finishes creating).

---

## Verification checklist before moving to Phase 4

- [ ] `terraform apply` completed with no errors
- [ ] `kubectl get nodes` shows 2 nodes in `Ready` status
- [ ] EKS cluster shows "Active" status in the AWS Console

Once confirmed, we'll move to **Phase 4: the AWS Load Balancer
Controller and the actual Kubernetes manifests** — this is where
`Helm` gets installed and the app actually starts running as pods.

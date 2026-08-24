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

### `kubectl` fails: "Symbol not found: _SecTrustCopyCertificateChain"
**Cause:** the same class of problem hit repeatedly across every
project in this series (AWS CLI v2, several Terraform provider
plugins, the SSM Session Manager plugin) — recent `kubectl` release
binaries are compiled with a Go toolchain that defaults to requiring
macOS 12+, and this specific error/symbol shows up across a huge
range of unrelated Go-based CLI tools industry-wide once Go made that
default shift, not just Kubernetes-specific tooling.
**Fix:** install an older `kubectl` release (v1.27.16 worked)
predating that toolchain change:
```bash
curl -LO "https://dl.k8s.io/release/v1.27.16/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```
Kubernetes' client/server version skew policy tolerates some
difference between `kubectl`'s version and the cluster's — a v1.27
client talking to a v1.31 cluster works fine for the operations this
project needs, possibly with a harmless compatibility warning.

### Load Balancer Controller pods stuck in "CrashLoopBackOff": "failed to get VPC ID"
**Cause:** a well-documented gotcha with this Helm chart — by
default, the controller tries to auto-detect its VPC ID by querying
the EC2 instance metadata service (IMDS) from inside the pod. That
lookup can time out depending on the cluster's networking setup, even
though the controller's IAM permissions and everything else are
correctly configured.
**Fix:** pass the VPC ID and region explicitly instead of relying on
auto-detection, via `helm upgrade` with the same install command plus
two extra flags:
```bash
helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-guestbook-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set vpcId=<your-vpc-id> \
  --set region=us-east-1
```

### `terraform init`/`plan` fails: "Failed to load plugin schemas" for `hashicorp/tls`
**Cause:** the same class of problem as `kubectl`, the SSM Session
Manager plugin, and several Terraform providers in earlier projects —
the `tls` provider's compiled binary requires a newer macOS than this
project's development machine has. This provider was only being used
for one thing: computing the EKS cluster's OIDC certificate thumbprint
dynamically via a `tls_certificate` data source.
**Fix:** removed the `tls` provider dependency entirely. All AWS EKS
OIDC providers share the same well-known, stable thumbprint value
(`9e99a48a9960b14926bb7f3b02e22da2b0ab7280`), confirmed across
multiple independent sources — since they're all backed by the same
AWS certificate chain, not something unique per cluster. Hardcoding
this value is a legitimate, widely-used pattern (not a workaround
specific to this project's macOS issue), and removes a fragile binary
dependency in the process.

### `kubectl` fails: "the server has asked for the client to provide credentials"
**Cause:** a genuinely surprising EKS detail, not a bug in this
project's setup. With `authentication_mode = "API"` (the modern EKS
access management approach used here), the IAM principal that CREATES
the cluster is NOT automatically granted `kubectl` access. This
differs from the older ConfigMap-based auth mode, where the cluster
creator was implicitly added as a cluster admin. `aws eks update-
kubeconfig` succeeds and the AWS credentials themselves are perfectly
valid — the cluster's access control simply hasn't been told this IAM
principal is allowed in yet.
**Fix:** create an EKS access entry + access policy association
granting the deploying IAM principal the `AmazonEKSClusterAdminPolicy`,
scoped to the whole cluster:
```hcl
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}
```


## Phase 6+ — Teardown

### `terraform destroy` fails: "RepositoryNotEmptyException"
**Cause:** the same ECR gotcha documented in project 3 — AWS refuses
to delete a repository that still contains images unless
`force_delete = true` is set, which this project deliberately doesn't
set. Everything else destroyed cleanly; only this one resource
blocked.
**Fix:** clear the images manually, then re-run `terraform destroy`:
```bash
aws ecr list-images --repository-name eks-guestbook-app --profile cloud-resume --query "imageIds" --output json
aws ecr batch-delete-image --repository-name eks-guestbook-app --profile cloud-resume --image-ids imageDigest=sha256:...
```

### Destroying the ALB before `terraform destroy` — a real ordering requirement
**Cause:** unlike projects 2-3, the ALB in this project was created by
the AWS Load Balancer Controller in response to a Kubernetes Ingress
resource — not by Terraform. Terraform has no knowledge of it and no
way to clean it up. Running `terraform destroy` while that ALB (and
its associated security group and ENIs) still exists would likely
hang or fail while trying to delete the VPC and subnets underneath it.
**Fix:** delete the Kubernetes resources first (`kubectl delete -f
k8s/ingress.yaml`, then `service.yaml`, then `deployment.yaml`), wait
for the controller to actually finish tearing down the real ALB
(verify with `aws elbv2 describe-load-balancers`), and only then run
`terraform destroy`.
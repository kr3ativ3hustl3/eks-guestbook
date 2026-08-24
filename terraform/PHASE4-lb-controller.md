# Phase 4 — Load Balancer Controller & Kubernetes Manifests

Creates: ECR repository, the IAM role for the AWS Load Balancer
Controller (via IRSA), installs the controller itself via Helm, then
deploys the app as real Kubernetes objects (Deployment, Service,
Ingress) — this is the phase where the app actually starts running
and becomes reachable.

**This is the most involved phase across all four projects.** Take it
step by step.

---

## 1. Download the official IAM policy for the Load Balancer Controller

AWS publishes this policy directly — pulling it fresh is more
reliable than a hand-copied version:

```bash
cd ~/projects/eks-guestbook/terraform
curl -o modules/lb-controller-irsa/iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
```

Verify it actually downloaded real content (should be a large JSON
file, not an error page):

```bash
cat modules/lb-controller-irsa/iam-policy.json | head -5
```

## 2. Plan and apply the Terraform

```bash
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect roughly **10 resources to add**: the ECR repository + lifecycle
policy, the controller's IAM policy + role + attachment, and the
RDS-from-EKS security group rule.

```bash
terraform apply
```

## 3. Install Helm (one-time)

```bash
curl -LO "https://get.helm.sh/helm-v3.14.0-darwin-amd64.tar.gz"
tar -xzf helm-v3.14.0-darwin-amd64.tar.gz
sudo mv darwin-amd64/helm /usr/local/bin/
helm version
```

**If this fails with the same `dyld`/`_SecTrustCopyCertificateChain`
error hit with `kubectl`** (a real possibility, same class of issue),
try an older Helm release the same way — e.g. `v3.10.0` instead of
`v3.14.0` in the URL above.

## 4. Install the AWS Load Balancer Controller via Helm

```bash
terraform output lb_controller_role_arn
```

Copy that ARN, then:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

```bash
kubectl create serviceaccount aws-load-balancer-controller -n kube-system
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  eks.amazonaws.com/role-arn=<paste-the-role-arn-here>
```

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-guestbook-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

Verify it's running:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

Should show `1/1` or `2/2` ready within a minute or two.

## 5. Create the database secret (not committed to git)

```bash
cd ~/projects/eks-guestbook/terraform
terraform output db_endpoint
```

This gives you `host:port` — split it apart, then:

```bash
kubectl create secret generic db-credentials \
  --from-literal=DB_HOST=<host-only-no-port> \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=guestbook \
  --from-literal=DB_USER=guestbook_admin \
  --from-literal=DB_PASSWORD='<your-real-password-from-terraform.tfvars>'
```

This is a genuine parallel to never committing `terraform.tfvars` —
the secret lives only in the cluster and your terminal history, never
in a file that gets pushed to GitHub.

## 6. Deploy the app

```bash
cd ~/projects/eks-guestbook
terraform -chdir=terraform output -raw ecr_repository_url
```

Edit `k8s/deployment.yaml` and replace `<ECR_REPOSITORY_URL>` with
that real value (keep the `:latest` tag suffix as-is).

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

## 7. Wait for the ALB and check status

```bash
kubectl get ingress guestbook
```

The `ADDRESS` column starts empty and takes **2-5 minutes** to
populate with a real ALB hostname — the controller is provisioning it
in the background. Keep re-running this command until it appears.

```bash
kubectl get pods
```

Both pods should show `Running` and `1/1` ready.

Once you have the ALB hostname:

```bash
curl -s http://<alb-hostname-from-ingress>/health
```

Should return `OK`.

---

## Verification checklist — core architecture complete

- [ ] `terraform apply` completed with no errors
- [ ] Load Balancer Controller pod(s) running in `kube-system`
- [ ] `kubectl get ingress guestbook` shows a real ALB address
- [ ] Both app pods `Running` and ready
- [ ] The site loads in a browser and the guestbook form actually
      saves and displays entries

Once confirmed, this is functionally a complete containerized,
orchestrated three-tier architecture. **Phases 5-6 are refinements**
(CI/CD automation and the final write-up).

**Cost reminder:** you're now at the full ~$110-130/month rate
(cluster + nodes + ALB all running). Move promptly to verify and then
`terraform destroy` when done actively working.

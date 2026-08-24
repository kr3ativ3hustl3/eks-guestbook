# Phase 5 — CI/CD Auto-Deploy

Adds: an EKS access entry granting GitHub Actions `kubectl` access
(scoped to edit permissions in the `default` namespace only — not
cluster-admin), and two new workflow steps that trigger and wait for
a rollout after each image push.

How it works: `kubectl rollout restart deployment/guestbook` replaces
running pods with new ones that pull whatever `:latest` currently
points to — the Kubernetes equivalent of project 3's ECS `--force-
new-deployment`.

---

## 1. Apply the access entry

```bash
cd ~/projects/eks-guestbook/terraform
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect **2 resources to add**: the access entry and its policy
association. Nothing else should change.

```bash
terraform apply
```

## 2. Push the updated workflow

```bash
cd ~/projects/eks-guestbook
git add .github terraform
git commit -m "Phase 5: CI/CD auto-deploy via kubectl rollout restart"
git push
```

## 3. Test the full pipeline

```bash
echo "# CI/CD rollout test" >> app/app.py
git add app/app.py
git commit -m "Test full CI/CD pipeline"
git push
```

Watch the **Actions** tab — "Build, Push, and Deploy" should run all
steps: build, push, update kubeconfig, roll out, wait for stability.

## 4. Verify the live site actually updated

```bash
curl -s http://<your-alb-hostname>/health
```

Confirm it still returns `OK` — proving the rollout completed cleanly,
not just that the workflow reported success.

---

## Verification checklist

- [ ] `terraform apply` succeeded (2 resources: access entry + association)
- [ ] "Build, Push, and Deploy" completes all steps successfully
- [ ] The site is reachable and healthy after the rollout

Once confirmed, we'll move to **Phase 6: final write-up**.

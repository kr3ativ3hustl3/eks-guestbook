# Phase 0 — Project Scaffold & Terraform State

No new AWS account setup needed — reuses the state backend from
projects 1-3.

---

## ⚠️ Cost note

This project's infrastructure costs roughly **$110-130/month if left
running**, meaningfully more than projects 2-3 — mainly the flat
~$73/month EKS control plane fee. AWS bills hourly and charges at the
end of your billing cycle, not upfront. Building, verifying, and
destroying within a session (same practice as before) costs on the
order of $1-2. Plan to `terraform destroy` promptly once verified.

## New local tools needed this project

Unlike projects 1-3, this one needs two additional command-line tools
on your Mac: **kubectl** (talks to the Kubernetes API) and **Helm**
(installs the AWS Load Balancer Controller). We'll install these when
we actually need them (Phase 3), not right now — no need to install
anything yet.

## 1. Get the project onto your machine

Unzip alongside your other projects — NOT inside any of them:

```bash
unzip -o ~/Downloads/eks-guestbook.zip -d ~/projects
cd ~/projects/eks-guestbook/terraform
```

## 2. Set up tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Defaults are fine as-is for now.

## 3. Init

```bash
export AWS_PROFILE=cloud-resume
terraform init
```

```bash
terraform plan
```

Should show "No changes" — nothing defined yet, just confirming the
backend connects correctly.

---

## Verification checklist before moving to Phase 1

- [ ] `terraform init` completes with no errors
- [ ] `terraform plan` shows a clean empty state

Once confirmed, we'll move to **Phase 1: networking** — same pattern
as project 3 (public + database subnets, no NAT Gateway).

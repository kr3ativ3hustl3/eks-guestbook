# Phase 2 — Database Tier

Creates: a DB subnet group, an RDS Postgres instance in the isolated
database subnets, and a security group with zero inbound rules — same
locked-down pattern as projects 2-3.

---

## 1. Set a real database password

```bash
cd ~/projects/eks-guestbook/terraform
```

Edit `terraform.tfvars` and replace the placeholder password with a
real, strong one (8+ characters).

## 2. Check the Postgres version is still valid

```bash
aws rds describe-db-engine-versions \
  --engine postgres \
  --query "DBEngineVersions[?EngineVersion.starts_with(@, '16.')].EngineVersion" \
  --output table \
  --profile cloud-resume
```

## 3. Plan and apply

```bash
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect **3 resources to add**. Phase 1's networking should show no
changes.

```bash
terraform apply
```

**This takes 5-10 minutes** — RDS provisioning is genuinely slow.

## 4. Verify

```bash
terraform output db_endpoint
```

Should return a real hostname. Nothing can connect yet — correct,
same as before.

---

## Verification checklist before moving to Phase 3

- [ ] `terraform apply` completed with no errors
- [ ] `terraform output db_endpoint` returns a real hostname

Once confirmed, we'll move to **Phase 3: the EKS cluster** — this is
where things get genuinely new, and where we'll install `kubectl` and
set up the local tools needed to actually work with Kubernetes.

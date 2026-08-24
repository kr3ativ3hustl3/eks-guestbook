# Architecture Notes

## Overview

The same guestbook app from projects 2-3, now on EKS — completing a
three-way comparison of AWS compute models: EC2 (project 2), ECS
Fargate (project 3), and EKS (this project). Built to demonstrate
Kubernetes fundamentals on top of the AWS networking/database patterns
already proven in the earlier projects.

## Design decisions & tradeoffs

### Reusing the state backend from projects 1-3, with a separate key
Same pattern as every prior project — one S3 bucket and DynamoDB
table serve all state, isolated by key.

### Managed node group, not EKS Fargate
EKS supports running pods on Fargate (no EC2 nodes to manage at all)
or on a traditional managed node group (EC2 instances you specify,
AWS handles provisioning/lifecycle). Fargate is simpler to operate,
but a managed node group is what most real companies actually run in
production and is more representative of what "using Kubernetes on
AWS" typically means day to day — worth the small added complexity
for a project specifically meant to build genuine Kubernetes literacy.

### Plain Kubernetes YAML manifests, not Terraform-managed Kubernetes resources
Terraform's `kubernetes` provider could create Deployments, Services,
and Ingresses directly from HCL. Deliberately not used here — the
whole point of this project is practicing real Kubernetes YAML and
`kubectl`, which is what interviews actually probe ("can you write a
Deployment spec," "what's a readiness probe for"). Hiding that behind
Terraform would demonstrate Terraform skill, not Kubernetes skill.
Terraform's job in this project stops at provisioning the AWS
infrastructure (VPC, RDS, EKS cluster, node group, IAM) that
Kubernetes then runs on top of.

### No NAT Gateway — same pattern as project 3
Worker nodes sit in public subnets with public IPs, locked down by
security group rather than network isolation — consistent with the
cost-saving approach already proven in project 3, and it keeps the
three "same app" projects genuinely comparable rather than
introducing an unrelated cost variable.

### AWS Load Balancer Controller via Helm, not a plain Kubernetes Service of type LoadBalancer
A `Service` of type `LoadBalancer` would provision a classic/network
load balancer automatically, but that bypasses the more realistic,
more commonly-used pattern in real EKS deployments: an Ingress
resource managed by the AWS Load Balancer Controller, which
provisions and configures an actual Application Load Balancer (same
ALB type used in projects 2-3, keeping the comparison consistent) and
supports the richer routing/TLS features real applications need.

### Rely on the EKS-managed cluster security group, not a custom one
When no explicit additional security groups are specified, EKS
automatically creates and manages a "cluster security group" shared
between the control plane and worker nodes, with the internal rules
they need to communicate already configured correctly. Building a
custom node security group from scratch would just be re-implementing
what EKS already provides safely by default — Phase 4 adds one
ingress rule to this existing group (allowing the future ALB in),
rather than replacing it with hand-rolled rules.

### API-based EKS access management, not the aws-auth ConfigMap
Older EKS clusters manage who can run `kubectl` against them via a
special `aws-auth` ConfigMap inside the cluster itself — editable only
via `kubectl`, which creates an awkward bootstrapping problem (you
need cluster access to grant cluster access). This project uses EKS's
newer API-based access entries instead (`authentication_mode = "API"`
on the cluster), managed the same way as any other AWS IAM-adjacent
resource — directly relevant in Phase 5, when GitHub Actions needs
`kubectl` access without ever touching an in-cluster ConfigMap by hand.

## Cost breakdown (expected)

| Service | Free tier | Expected usage | Expected cost |
|---|---|---|---|
| EKS control plane | **None** | 1 cluster | ~$73/month flat, regardless of usage |
| EC2 worker nodes (t3.small x2) | 750 hrs/mo (12mo, may not cover this) | 2 nodes | ~$15-30/month |
| Application Load Balancer | **Not free** | 1 ALB (via Ingress controller) | ~$16-20/month |
| RDS (db.t3.micro) | 750 hrs/mo (12mo) | 1 instance | $0 (free tier, first 12mo) |
| ECR | 500MB free (12mo) | 1 small image | $0 |

**Realistic total if left running: ~$110-130/month.** AWS bills
hourly and charges at the end of the billing cycle — building,
verifying, and destroying within a single session (the practice
followed in every project so far) costs on the order of $1-2, not the
monthly figure.

## Security posture (running list, updated per phase)

- Phase 0: Terraform state reuses the existing encrypted, versioned,
  private S3 backend from projects 1-3.
- Phase 1: database subnets have zero route to the internet, same as
  projects 2-3. Public subnets exist for EKS worker nodes and the
  ALB — no NAT Gateway needed since nothing lives in a private,
  NAT-dependent subnet this time.
- Phase 2: RDS security group created with zero inbound rules — the
  database is unreachable from anything until Phase 4 explicitly
  grants EKS pod access. Not publicly accessible; sits in subnets
  with no internet route at all.
- Phase 3: worker node IAM role scoped to exactly the 3 managed
  policies a node needs (cluster communication, pod networking, ECR
  read-only) — nothing broader. EKS API server access uses the modern
  API-based access entry system, not a shared in-cluster ConfigMap.
  A cluster-specific OIDC provider (separate from the account-wide
  GitHub Actions one) sets up IRSA for later, so the Load Balancer
  Controller won't need any static AWS credentials either.

## Observability posture (running list, updated per phase)

- (To be added in a later phase.)

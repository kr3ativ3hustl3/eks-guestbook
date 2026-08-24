# EKS Guestbook — Kubernetes on AWS

The same guestbook app from [project 2](https://github.com/kr3ativ3hustl3/vpc-guestbook)
(EC2) and [project 3](https://github.com/kr3ativ3hustl3/ecs-guestbook)
(ECS Fargate), now on EKS — completing a direct three-way comparison
of AWS compute models running identical application code.

This is project 4 in a portfolio series:
- [Project 1](https://github.com/kr3ativ3hustl3/cloud-resume-challenge) — serverless (Lambda, DynamoDB, API Gateway)
- [Project 2](https://github.com/kr3ativ3hustl3/vpc-guestbook) — traditional (EC2, Auto Scaling Group, VPC)
- [Project 3](https://github.com/kr3ativ3hustl3/ecs-guestbook) — containers (ECS Fargate, ECR)
- **Project 4 (this one)** — orchestrated containers (EKS, Kubernetes)

**Status:** ✅ Complete (Phases 0-6).

## Architecture

```
                         Internet
                            │
                    ┌───────▼────────┐
                    │  Application    │   (created by the AWS Load
                    │  Load Balancer  │    Balancer Controller, via
                    └───────┬────────┘    a Kubernetes Ingress)
                            │
              ┌─────────────┴─────────────┐
              │                           │
      ┌───────▼───────┐           ┌───────▼───────┐
      │  Pod           │           │  Pod           │   (EKS managed
      │  (guestbook)   │           │  (guestbook)   │    node group,
      └───────┬───────┘           └───────┬───────┘    public subnets,
              │                           │             no NAT)
              └─────────────┬─────────────┘
                             │
                     ┌───────▼────────┐
                     │  RDS Postgres   │   (isolated subnet, no internet)
                     └────────────────┘

   GitHub Actions: docker build → push to ECR → kubectl rollout restart
```

Full reasoning behind every architectural decision in
[`docs/architecture.md`](docs/architecture.md), including the EKS-
specific gotchas that came up mid-build and aren't obvious from
documentation alone.

## Tech stack

- **Orchestration:** EKS, managed node group, Kubernetes Deployment/Service/Ingress
- **Load balancing:** AWS Load Balancer Controller (Helm) + Ingress
- **Networking:** VPC, public + database subnets, no NAT Gateway
- **Database:** RDS Postgres, isolated subnet
- **Containers:** Docker, ECR (all builds in GitHub Actions, never locally)
- **IaC:** Terraform for AWS infrastructure; plain YAML for Kubernetes resources
- **CI/CD:** GitHub Actions — build, push, `kubectl rollout restart`

## What this project actually demonstrates

- **Real Kubernetes literacy, not infrastructure hidden behind Terraform** — the Deployment, Service, and Ingress are plain YAML, applied via `kubectl`, the way most real teams actually work day to day.
- **A genuinely different EKS-specific security model** — IRSA (IAM Roles for Service Accounts) via a cluster-specific OIDC provider means the Load Balancer Controller runs with zero static AWS credentials, and two separate, differently-scoped EKS access entries (cluster-admin for the human deployer, namespace-scoped edit access for CI/CD) show a clear least-privilege distinction between human and automated access.
- **A handful of genuinely non-obvious EKS gotchas, found and fixed, not just read about:**
  - The IAM principal that *creates* an EKS cluster with API-based access management isn't automatically granted `kubectl` access — a real surprise, since older EKS clusters worked differently.
  - The AWS Load Balancer Controller's default VPC auto-detection via instance metadata can silently fail depending on cluster networking, with a documented fix (pass the VPC ID explicitly).
  - `kubectl` itself needed an older release to run on this project's development machine, the same class of macOS compatibility issue hit repeatedly across this whole project series.
- **A real three-way architecture comparison** — the same application running on EC2, ECS Fargate, and EKS, with an honest account of what changed operationally (and in cost) at each step.

## Cost

Roughly **$110-130/month** while running — the EKS control plane's
flat ~$73/month fee is the biggest single cost across all four
projects. AWS bills hourly; building, verifying, and destroying
within a session (the practice followed throughout) costs on the
order of a few dollars, not the monthly figure. Full breakdown in
[`docs/architecture.md`](docs/architecture.md).

## Repo structure

```
eks-guestbook/
├── docs/                    # architecture decisions, troubleshooting log
├── app/                     # Flask app + Dockerfile
├── k8s/                     # Kubernetes manifests (Deployment, Service, Ingress)
├── terraform/
│   └── modules/             # networking, database, ecr, eks, lb-controller-irsa, github-cicd
└── .github/workflows/       # build, push, and kubectl rollout pipeline
```

## Build log (phases)

- [x] **Phase 0** — Project scaffold, Terraform state (reusing projects 1-3's backend)
- [x] **Phase 1** — Networking: VPC, public + database subnets
- [x] **Phase 2** — Database: RDS Postgres
- [x] **Phase 3** — EKS cluster + managed node group
- [x] **Phase 4** — AWS Load Balancer Controller + Kubernetes manifests
- [x] **Phase 5** — CI/CD auto-deploy via kubectl rollout restart
- [x] **Phase 6** — Final polish & write-up (this README)

## Troubleshooting

Every real issue hit during the build — with root cause and fix — is
logged in [`docs/troubleshooting.md`](docs/troubleshooting.md),
including several EKS-specific gotchas not obvious from AWS's own
documentation, and a recurring macOS/Go-toolchain compatibility issue
that affected `kubectl` the same way it affected tools across every
project in this series.

## Security notes

- No static AWS credentials anywhere — the Load Balancer Controller
  uses IRSA, GitHub Actions uses OIDC (reusing the same account-wide
  provider from projects 1-3)
- Two distinct EKS access grants at two distinct trust levels: full
  cluster-admin for the human deploying infrastructure, namespace-
  scoped edit access only for CI/CD
- Every tier's security group accepts traffic ONLY from the specific
  tier in front of it
- Worker node IAM role scoped to exactly the 3 managed policies a node
  needs, nothing broader
- Full posture, updated per phase, in [`docs/architecture.md`](docs/architecture.md)

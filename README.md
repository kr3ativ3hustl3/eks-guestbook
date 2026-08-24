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

**Status:** 🚧 In progress — Phase 2 of 6 complete (RDS Postgres in
isolated subnets, locked down).

## ⚠️ Cost note

EKS has a **flat ~$73/month control plane fee** regardless of usage,
plus worker node and ALB costs — realistically **~$110-130/month**
if left running. AWS bills hourly and charges your account at the end
of the billing cycle, not upfront. This project follows the same
practice as projects 2-3: build, verify, `terraform destroy`. A few
hours of build-and-verify time costs roughly $1-2, not the monthly
figure.

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
```

**Key differences from project 3:**
- Kubernetes YAML manifests (Deployment, Service, Ingress), not
  Terraform-managed compute — real `kubectl`/YAML practice, not
  infrastructure hidden inside HCL
- AWS Load Balancer Controller (the real-world standard way EKS gets
  an ALB from an Ingress resource), installed via Helm
- GitHub Actions authenticates to the Kubernetes API itself (via EKS
  access entries), not just to AWS — a genuinely different, valuable
  CI/CD wiring problem than pushing to ECR/ECS

## Tech stack

- **Orchestration:** EKS, managed node group, Kubernetes Deployment/Service/Ingress
- **Load balancing:** AWS Load Balancer Controller (Helm) + Ingress
- **Networking:** VPC, public + database subnets, no NAT Gateway
- **Database:** RDS Postgres, isolated subnet
- **Containers:** Docker, ECR (all builds in GitHub Actions, never locally)
- **IaC:** Terraform for AWS infrastructure; plain YAML for Kubernetes resources
- **CI/CD:** GitHub Actions — build, push, `kubectl rollout restart`

## Repo structure

```
eks-guestbook/
├── docs/                    # architecture notes, troubleshooting log
├── app/                     # Flask app + Dockerfile
├── k8s/                     # Kubernetes manifests (Deployment, Service, Ingress)
└── terraform/
    └── modules/             # networking, database, ecr, eks, github-cicd
```

## Build log (phases)

- [x] **Phase 0** — Project scaffold, Terraform state (reusing projects 1-3's backend)
- [x] **Phase 1** — Networking: VPC, public + database subnets. See [`terraform/PHASE1-networking.md`](terraform/PHASE1-networking.md).
- [x] **Phase 2** — Database: RDS Postgres. See [`terraform/PHASE2-database.md`](terraform/PHASE2-database.md).
- [ ] **Phase 3** — EKS cluster + managed node group
- [ ] **Phase 4** — AWS Load Balancer Controller + Kubernetes manifests
- [ ] **Phase 5** — CI/CD: build, push, rolling deploy via kubectl
- [ ] **Phase 6** — Final polish & write-up

## Troubleshooting

Real issues hit while building this are logged in
[`docs/troubleshooting.md`](docs/troubleshooting.md).

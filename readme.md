# AWS EKS Preview Environments Platform

> Ephemeral, per-pull-request preview environments on Amazon EKS — powered by a cached CI/CD pipeline and serverless automation.

## Overview
 
Every open pull request in the target application repository automatically gets its own isolated environment on EKS — a dedicated namespace, database, and public URL with TLS — built through a heavily cached CI/CD pipeline and torn down automatically once the PR closes or expires.
 
This project is a hands-on exploration of **platform engineering** patterns: self-service ephemeral environments, CI/CD performance optimization through caching, GitOps-driven provisioning, and event-driven cost control via serverless automation.

## Roadmap
 
| Phase | Scope | Status |
|---|---|---|
| 0 | Repo structure, OIDC, remote state, budget alarms | ✅ |
| 1 | VPC + EKS + ECR + Karpenter (Terraform modules) | 🔲 |
| 2 | Demo app + baseline pipeline (no cache) | 🔲 |
| 3 | Layered CI/CD caching + measurements | 🔲 |
| 4 | ArgoCD ApplicationSet + DNS/TLS preview environments | 🔲 |
| 5 | Lambda automation (reaper, cost reporter, scale-to-zero, PR commenter) | 🔲 |
| 6 | Security scanning, Kyverno policies, External Secrets, dashboards | 🔲 |
| 7 | Metrics, architecture diagram, demo, final documentation | 🔲 |


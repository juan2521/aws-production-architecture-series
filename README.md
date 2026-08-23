# AWS Production Architecture Series

Production-grade AWS architecture articles focused on security, resilience, observability, cost awareness, and Infrastructure as Code.

## Practitioner perspective

This series is not intended to be a catalog of AWS icons or a rewritten service manual. I use each architecture to document **how I would reason about a production design**: the requirement behind a component, the risk it reduces, the trade-off it introduces, what I would validate operationally, and what I would change when the business context changes.

In real projects, architecture decisions are rarely made in isolation. Existing networks, security requirements, budget, operational maturity, legacy dependencies, recovery objectives, and team capabilities all influence the final design. For that reason, each article aims to distinguish between:

- **the reference pattern** — a technically sound starting point;
- **my architecture decision** — why I would choose or reject an option;
- **the production validation** — what I would test before trusting the design with a real workload.

I will also call out where additional resilience increases cost, where a security control can create operational friction, and where an Infrastructure as Code example is a deployable baseline rather than a universal production template.

The goal is simple: every architecture should be something I can **defend in a technical discussion**, not merely something that looks good in a diagram.

## Series

| # | Architecture | Focus | Status |
|---|---|---|---|
| 01 | [Secure Global Web Application Edge](articles/01-secure-global-web-application-edge/README.md) | Route 53, CloudFront, AWS WAF, Shield, ALB, ACM, CloudWatch | Published |

## Purpose

This repository is a hands-on architecture portfolio. Each article explains not only **what** AWS services are used, but **why**, the threat model being addressed, key design trade-offs, operational considerations, and an Infrastructure as Code starting point.

## 👤 About the Author

**Juan Gutierrez**  
Solutions Architect focused on Cloud Architecture, Kubernetes, Security, FinOps, and Cloud Modernization.

This series documents architecture decisions, trade-offs, security, resilience, cost, and Infrastructure as Code from a practitioner perspective.

🔗 [LinkedIn](https://www.linkedin.com/in/juan-gutierrez25)  
💻 [GitHub](https://github.com/juan2521)

> The examples in this repository are reference architectures for learning and portfolio purposes. Validate service limits, pricing, compliance requirements, security controls, and workload-specific requirements before production use.

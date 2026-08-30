# AWS Production Architecture Series

Production-grade AWS architecture articles focused on security, resilience, observability, cost awareness, and Infrastructure as Code.

## Practitioner perspective

This series is not intended to be a catalog of AWS icons or a rewritten service manual. I use each architecture to document **how I would reason about a production design**: the requirement behind a component, the risk it reduces, the advantages and compromises of each option, what I would validate operationally, and what I would change when the business context changes.

In real projects, existing networks, security requirements, budget, operational maturity, legacy dependencies, recovery objectives, and team capabilities all influence the final design. Each article distinguishes the reference pattern, my architecture decision, and production validation.

## Series

| # | Architecture | Focus | Status |
|---|---|---|---|
| 01 | [Secure Global Web Application Edge](articles/01-secure-global-web-application-edge/README.md) | Route 53, CloudFront, AWS WAF, Shield, ALB, ACM, CloudWatch | Published |
| 02 | [Building for Production with Multi-AZ](articles/02-production-multi-az-architecture/README.md) | VPC, Availability Zones, ALB, Auto Scaling, NAT Gateway, RDS Multi-AZ | Published |
| 03 | Kubernetes at Scale — Amazon EKS | EKS, node architecture, scaling, security, operations | Upcoming |
| 04 | Defense in Depth | AWS security architecture | Upcoming |
| 05 | The Serverless World | Event-driven and serverless architecture | Upcoming |
| 06 | The GenAI Era | Amazon Bedrock | Upcoming |
| 07 | The Data Path | Data architecture | Upcoming |
| 08 | Observing the Cloud | Observability | Upcoming |
| 09 | Architecture with FinOps | Cost-aware architecture | Upcoming |
| 10 | The Cloud Organization | Multi-account governance | Upcoming |
| 11 | Surviving a Region | Multi-Region resilience | Upcoming |
| 12 | The Final Architecture | Integrated production architecture | Upcoming |

## 👤 About the Author

**Juan Gutierrez**  
Solutions Architect focused on Cloud Architecture, Kubernetes, Security, FinOps, and Cloud Modernization.

🔗 [LinkedIn](https://www.linkedin.com/in/juan-gutierrez25)  
💻 [GitHub](https://github.com/juan2521)

> The examples in this repository are reference architectures for learning and portfolio purposes. Validate service limits, pricing, compliance requirements, security controls, and workload-specific requirements before production use.

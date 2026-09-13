# 🛡️ AWS Production Architecture Series — Article 04

# Defense in Depth — AWS Security Architecture

### *Designing so that one failed control does not become a complete compromise*

**Author:** Juan Gutierrez  
**Series:** AWS Production Architecture Series  
**Focus:** Production AWS architecture

---

Real security is not placing a WAF in front of an application and declaring the job done. In production I assume a credential can leak, a rule can become too permissive, a dependency can contain a vulnerability, and an operator can make a mistake. The architecture must constrain what happens next.

> **Mission:** build independent prevention, detection, and response layers so compromising one layer does not automatically grant identity, network, data, and administrative control.

## 🎯 Real requirements

- separate workloads, security tooling, logs, and networking through accounts with distinct responsibilities;
- federated human access with MFA and least privilege;
- temporary workload credentials instead of embedded access keys;
- protect the edge and minimize direct origin exposure;
- segment north-south and east-west traffic according to risk;
- encrypt data and secrets with explicit ownership and rotation;
- centralize evidence outside the workload account;
- detect threats, vulnerabilities, and configuration drift;
- automate low-risk response without turning a false positive into an outage;
- retain investigative capability after compromise.

---

## 🗺️ Architecture

<p align="center">
  <img src="./architecture/chapter-04-defense-in-depth-architecture.png" alt="AWS Production Architecture Series - Article 04 - Defense in Depth - Designed by Juan Gutierrez" width="1200">
</p>

> **Image pending manual upload:** `articles/04-defense-in-depth/architecture/chapter-04-defense-in-depth-architecture.png`

The reference design separates Workload, Security Tooling, Log Archive, and Network/Shared Services accounts. Web traffic crosses Route 53, CloudFront, WAF, and the load balancer; centralized network inspection is introduced only when the risk model justifies it. GuardDuty, Inspector, and Security Hub centralize detection while CloudTrail, Config, VPC Flow Logs, and application logs are retained independently from workload administrators.

---

# 🧠 Decision 01 — Separate the security plane from the workload

I do not want an application administrator to be able to erase the evidence explaining what happened. I use AWS Organizations and dedicated **Security Tooling** and **Log Archive** accounts. Security Hub, GuardDuty, and Inspector use delegated administration at organization level, while the Organizations management account is reserved for operations that truly require it.

**Trade-off:** more accounts mean more governance, pipelines, and cross-account troubleshooting. In return, duties are separated and the administrative blast radius is materially smaller.

---

# 🧠 Decision 02 — Identity first; network second

A VPN or private subnet does not make a privileged identity safe. Human access starts with IAM Identity Center, MFA, and role-based permission sets. Workloads receive IAM roles and temporary credentials with narrowly scoped policies.

Emergency access is explicit, audited, and temporary. Long-lived IAM user access keys are not a normal operating mechanism.

**Alternative:** direct IAM role federation remains workable for small organizations. Identity Center becomes more valuable as account and team count grows because lifecycle and assignments become centralized.

---

# 🧠 Decision 03 — The edge filters application attacks; it does not replace internal security

CloudFront + AWS WAF reduces exposure and supports managed rules, rate-based rules, and application-specific controls. Shield Standard provides baseline DDoS protection; I consider Shield Advanced when risk, criticality, and outage economics justify its additional capabilities.

I do not add rules merely to increase rule count. Every WAF rule needs an owner, metric, test strategy, and rollback criterion. New managed rules should normally be observed in `COUNT` first, reviewed for false positives, and then enforced.

**Trade-off:** aggressive inspection reduces attack surface but can block legitimate clients. A security control that cannot explain why it rejected a transaction becomes operational debt.

---

# 🧠 Decision 04 — Centralized inspection only with routing designed for it

In multi-VPC environments, Transit Gateway and AWS Network Firewall can centralize east-west, egress, and hybrid inspection. The hard part is not creating a firewall: it is preserving **flow symmetry**, correct route tables, and AZ failure domains.

I do not force all traffic through a firewall just because one exists. Security Groups remain the stateful control closest to the workload. Network Firewall is introduced for inspection, egress policy, signatures, or segmentation requirements that SGs/NACLs do not satisfy well.

**Trade-off:** centralized policy improves consistency but adds processing cost, Transit Gateway cost, data transfer, and a critical operational dependency. Distributed controls can be simpler for smaller estates.

---

# 🧠 Decision 05 — Evidence leaves the account that generates the event

Organization CloudTrail, AWS Config, VPC Flow Logs, and relevant workload logs are centralized. The archive bucket uses encryption, versioning, lifecycle, and permissions that prevent workload operators from altering retention.

I do not collect logs “just in case.” Each source must answer a forensic question. CloudTrail explains API activity; Flow Logs help reconstruct network patterns; Config reconstructs configuration change; application logs explain functional behavior.

---

# 🛡️ Controls by layer

| Layer | Primary controls | What it constrains |
|---|---|---|
| Organization | Organizations, SCPs, separate accounts | actions member accounts must never perform |
| Identity | Identity Center, MFA, IAM roles, Access Analyzer | credential abuse and excessive privilege |
| Edge | CloudFront, WAF, Shield | HTTP attacks, floods, direct exposure |
| Network | SG, NACL, TGW, Network Firewall | lateral movement and unauthorized egress |
| Workload | hardening, patching, Inspector, runtime controls | exploitation of hosts/images/packages |
| Data | KMS, Secrets Manager, resource policies | access to data and secrets |
| Detection | GuardDuty, Security Hub, Config, CloudTrail | time to discover suspicious behavior |
| Response | EventBridge, Lambda/SSM, SNS/ITSM | time to contain an incident |

---

# 🧯 Resilience is part of security

A centralized firewall in one AZ can be a security control and a single point of failure at the same time. Inspection endpoints, NAT, load balancing, and routing must preserve AZ failure domains. I also test what happens when a security automation revokes a policy, isolates an instance, or blocks legitimate traffic.

Critical backups and recovery paths should have access controls separated from workloads. Ransomware with workload administration should not automatically be able to destroy production **and** every recoverable copy.

---

# 🔭 Observability and response

Security Hub is an aggregation and prioritization plane, not a replacement for analysis. I correlate findings with asset context, exposure, and business criticality. GuardDuty contributes threat detection; Inspector vulnerability findings; Config configuration posture; CloudTrail API activity.

EventBridge can trigger response, but I separate actions into:

1. **Automatic and reversible:** enrich a finding, tag, ticket, notify, or block a high-confidence indicator.
2. **Automatic with guardrails:** isolate an instance or revoke a session only under verified conditions.
3. **Human-in-the-loop:** actions with high blast radius or material business impact.

Useful operational measures include MTTD, MTTR, open critical findings, account/Region coverage, patch latency, and resources missing expected telemetry.

---

# 💰 Security cost and FinOps

I review security cost as both inspection and telemetry:

- WAF Web ACLs, rules, and inspected requests;
- Network Firewall endpoints and processed GB;
- Transit Gateway and cross-AZ transfer;
- GuardDuty, Inspector, and Security Hub coverage/usage;
- Config recording and evaluations;
- CloudTrail data events when broadly enabled;
- CloudWatch/S3 ingestion, storage, and retention.

Keeping everything forever is not a strategy. I classify evidence by forensic/compliance value and apply lifecycle. I also do not disable important detection simply because it costs money; first reduce noise, unnecessary scope, and duplicate telemetry.

---

# ⚙️ Operations

- controls and rules versioned as code;
- WAF/firewall changes observed before enforcement when practical;
- runbooks for compromised credentials, compromised hosts, and public exposure;
- periodic review of permission sets, roles, and exceptions;
- owners and severity SLAs for findings;
- tabletop exercises and restore tests;
- exceptions with expiration dates;
- tested and monitored break-glass access.

---

# ⚠️ Common mistakes

- assuming private means secure;
- using the same administrator everywhere;
- giving pipelines `AdministratorAccess` for convenience;
- allowing workload accounts to delete central evidence;
- deploying Network Firewall without validating return routing/symmetry;
- moving hundreds of WAF rules directly into block mode;
- encrypting with KMS while leaving access policies excessive;
- storing secrets in Terraform variables, user data, or repositories;
- enabling detection services without a process to own findings;
- automating isolation without rollback.

---

# 🧪 What I validate before production

- [ ] Are Security Tooling and Log Archive separated from workloads?
- [ ] Is human access federated with MFA and least privilege?
- [ ] Do workloads use temporary roles instead of static keys?
- [ ] Do SCPs deny truly prohibited actions without breaking recovery?
- [ ] Was WAF tested against representative traffic with metrics and rollback?
- [ ] Does the origin accept only required traffic paths?
- [ ] Are inspection routes symmetric and Multi-AZ?
- [ ] Do SG/NACL/firewall policies match documented flows?
- [ ] Do CloudTrail/Config/Flow Logs reach protected central storage?
- [ ] Do GuardDuty/Inspector/Security Hub cover target accounts and Regions?
- [ ] Does every critical finding have an owner, SLA, and escalation path?
- [ ] Are response automations reversible or approval-gated?
- [ ] Are backups and keys sufficiently separated from workload compromise?
- [ ] Have recovery and incident response actually been exercised?

---

# 🧱 Terraform baseline

The [`terraform/`](./terraform/) directory provides a small deployable detection baseline: CloudTrail with an encrypted/versioned bucket and GuardDuty. It intentionally does not pretend to create a universal landing zone or centralized firewall without knowing real CIDRs and routes.

That is an important practical decision: **useful IaC does not mean giant IaC**. A security module should be verifiable, clearly owned, and should not hide network decisions behind defaults.

---

# 🧭 Architecture lesson

Defense in depth does not mean buying eight security services. It means designing controls that fail independently while preserving enough evidence to discover which layer failed.

My mental test is simple: **if an application credential is compromised tomorrow, what other decision must fail before the attacker can reach critical data, erase evidence, and remain undetected?** If the answer is “none,” the design still does not have defense in depth.

---

## 📚 Official references

- AWS Security Reference Architecture — Security Tooling account
- AWS Security Hub — Organizations and delegated administration
- AWS WAF / Shield — DDoS and application-layer protections
- Building a Scalable and Secure Multi-VPC AWS Network Infrastructure
- AWS Network Firewall — centralized inspection patterns
- AWS CloudTrail — organization trails
- Amazon GuardDuty — multi-account management
- Amazon Inspector — multi-account management

---

**Juan Gutierrez**  
Solutions Architect · Cloud Architecture · Kubernetes · Security · FinOps · Cloud Modernization

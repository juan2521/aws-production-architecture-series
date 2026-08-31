# AWS Production Architecture #02 — Building for Production with Multi-AZ

**ALB → Auto Scaling across AZs → Private Application Tier → Amazon RDS Multi-AZ**

**Author:** Juan Gutierrez

> A production-oriented regional architecture that treats Availability Zones as failure-isolation boundaries instead of simply duplicating resources.

---

## The real problem

“Two servers” does not automatically mean high availability. If both servers depend on one Availability Zone, one egress path, or one Single-AZ database, the workload still contains shared failure points capable of taking the service down.

AWS Well-Architected recommends operating production workloads in at least two Availability Zones. My objective is therefore not redundancy for its own sake; it is to remove **correlated dependencies** while keeping the platform understandable and operable.

### Requirements

- application capacity in at least two AZs;
- private compute without public IPs;
- health-based load balancing and automatic replacement;
- AZ-local egress rather than a cross-AZ NAT dependency;
- managed relational database failover;
- observable availability and saturation;
- explicit cost/resilience trade-offs.

---

## Architecture

<p align="center">
  <img src="./architecture_exact_lossless.png" alt="AWS Production Architecture #02 - Production Multi-AZ Architecture" width="1200">
</p>

> The ALB distributes requests across private application capacity in AZ-A and AZ-B. An Auto Scaling Group maintains replaceable compute. Each AZ has its own NAT Gateway for outbound dependencies, while Amazon RDS Multi-AZ provides a synchronous standby in another AZ.

```text
Internet → Multi-AZ ALB
              │
       ┌──────┴──────┐
       │             │
      AZ-A          AZ-B
       │             │
   App / ASG      App / ASG
       │             │
     NAT-A          NAT-B
       └──────┬──────┘
              │
       RDS Multi-AZ
     Primary ⇄ Standby
```

The design principle is simple: **redundant components are useful only when their critical dependencies are also failure-isolated**.

---

## Decision 01 — Two AZs are the minimum production baseline

I distribute application capacity across two AZs. The ALB removes unhealthy targets from routing and Auto Scaling restores desired capacity.

**Alternative:** one AZ is cheaper and simpler, and can be appropriate for development. The trade-off is accepting an AZ event as a workload outage.

**Practitioner judgment:** Multi-AZ does not fix a stateful application. Local sessions, instance-local files, or singleton workers can still make failover fail at the software layer.

## Decision 02 — Subnets express trust and routing boundaries

Per AZ I separate:

- public subnets for ALB and NAT Gateway;
- private application subnets for compute;
- private database subnets for RDS.

A subnet is not private because its name says `private`; its route table determines reachability. Application instances have no direct Internet Gateway route or public IP.

## Decision 03 — NAT Gateway per AZ

A NAT Gateway is created in a specific AZ. AWS explicitly warns that sharing one NAT across workloads in multiple AZs creates an egress dependency on the NAT's AZ. For production resilience, I route each private application subnet to a NAT Gateway in the same AZ.

**Trade-off:** this costs more. In non-production I may deliberately use one NAT. I also evaluate VPC endpoints for supported AWS services to reduce NAT processing, egress exposure, and unnecessary data paths.

## Decision 04 — ALB plus Auto Scaling

The ALB decouples the service endpoint from instance lifecycle. Auto Scaling makes instances disposable and restores capacity after failures.

I would not default to CPU-only scaling. Depending on the workload, `RequestCountPerTarget`, latency, memory, queue depth, or a business metric can represent demand more accurately.

**Operational consequence:** immutable/repeatable provisioning becomes mandatory. Manual changes inside instances are no longer a safe operating model.

## Decision 05 — RDS Multi-AZ is HA, not read scaling

For a traditional relational workload, I use RDS Multi-AZ when the availability objective justifies it. A Multi-AZ DB instance maintains a synchronous standby in another AZ and RDS can fail over automatically. The standby is not a read replica.

AWS states that Multi-AZ DB instance failovers are typically around 60–120 seconds, though workload activity and recovery can extend this. Applications must reconnect and handle DNS changes. **Buying Multi-AZ does not make a poorly designed database client resilient.**

---

## Security model

- expose only the ALB listener required by the application;
- application SG accepts traffic only from the ALB SG;
- database SG accepts traffic only from the application SG;
- no public IPs on application instances;
- EC2 IAM roles instead of long-lived access keys;
- Secrets Manager/Parameter Store rather than credentials in code or user data;
- prefer Systems Manager Session Manager over internet-facing administrative SSH;
- encrypt EBS/RDS and use TLS to the database when required.

More subnets do not equal more security. The goal is to make **allowed relationships explicit and testable**.

---

## Failure behavior

| Failure | Expected behavior | Production validation |
|---|---|---|
| One instance | ALB removes it; ASG replaces it | health-check and replacement time |
| Application AZ | remaining AZ serves traffic | surviving capacity handles peak load |
| NAT in AZ-A | AZ-B keeps independent egress | route tables are truly AZ-local |
| RDS primary | RDS promotes standby | connection retry, DNS and pool behavior |
| Bad deployment | may break both AZs | rolling/blue-green and rollback |

Multi-AZ is strongest against infrastructure failure. It does **not** protect you from deploying the same defect everywhere.

---

## Observability

My minimum useful signals include:

```text
ALB: HealthyHostCount, UnHealthyHostCount, TargetResponseTime, HTTPCode_Target_5XX_Count
ASG/EC2: InService capacity, status checks, CPU and memory via CloudWatch Agent
NAT: ErrorPortAllocation, PacketsDropCount, BytesOutToDestination
RDS: CPUUtilization, DatabaseConnections, FreeStorageSpace, FreeableMemory, ReadLatency, WriteLatency
```

I also keep the relevant ALB access logs and RDS/Auto Scaling events. Every alarm should have an owner and expected response; dashboards without operational decisions are decoration.

---

## Cost and trade-offs

The major cost drivers are ALB hours/LCUs, minimum compute across two AZs, NAT Gateway hours and processed data, inter-AZ transfer where applicable, and RDS Multi-AZ.

The architecture question is not “how do I remove redundancy to save money?” It is **what RTO/RPO and availability does the extra spend buy?** Development may intentionally use one NAT and Single-AZ RDS. If production requires zonal resilience, those same savings simply transfer financial risk to the outage.

---

## Common mistakes

1. Two instances in one AZ.
2. Two application AZs sharing one NAT Gateway.
3. Treating RDS Multi-AZ as a read replica.
4. An ASG with minimum capacity of one while claiming HA.
5. Critical session/file state stored locally.
6. Health checks that return 200 while dependencies are broken.
7. Scaling only on CPU.
8. Designing failover but never testing it.

---

## Before production

- [ ] Minimum capacity exists in at least two AZs.
- [ ] Subnets and route tables are reviewed AZ by AZ.
- [ ] Each private app subnet uses local NAT or appropriate endpoints.
- [ ] Security Groups reference other SGs where appropriate.
- [ ] ASG replaces a terminated instance automatically.
- [ ] Application survives losing all targets in one AZ.
- [ ] Health checks represent real service health.
- [ ] RDS failover is tested and timed.
- [ ] Database clients reconnect after DNS changes.
- [ ] Backups and restores are tested; HA is not backup.
- [ ] Logs, alarms, runbooks, and ownership are defined.
- [ ] NAT, inter-AZ, compute, and database costs are modeled.

---

## Infrastructure as Code — Terraform

The [`terraform/`](./terraform/) directory contains a deployable baseline for a VPC, two AZs, public/application/database subnets, Internet Gateway, NAT per AZ, ALB, Auto Scaling, and PostgreSQL RDS Multi-AZ.

```bash
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
```

This is intentionally a small lab baseline, not a universal production template. Use only non-production credentials, review pricing before `apply`, and destroy the lab when finished.

---

## Practitioner takeaway

High availability is not a resource count. It is the discipline of asking **which shared dependency can still take down all the copies that look independent on the diagram**.

My regional baseline starts with two AZs, but the final architecture must be defended with business RTO/RPO, application state, traffic profile, operational maturity, and budget.

---

**Juan Gutierrez** · AWS Production Architecture Series · Multi-AZ · Reliability · VPC · Auto Scaling · RDS · Terraform
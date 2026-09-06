# ☸️ AWS Production Architecture Series — Article 03

# Kubernetes at Scale — Amazon EKS

### *Designing a container platform that remains operable as teams, nodes, and failure modes grow*

**Author:** Juan Gutierrez  
**Series:** AWS Production Architecture Series  
**Focus:** Production AWS Architecture

---

EKS solves one difficult problem: operating the Kubernetes control plane. It does not solve IP capacity, Pod placement, workload identity, node strategy, upgrades, or idle-capacity cost for us. In real environments, those boundaries are where production problems usually surface.

> **Mission:** design a private, regional, Multi-AZ EKS platform that can scale applications and compute capacity without turning the cluster into a collection of manual exceptions.

## 🎯 Real requirements

- distribute nodes and replicas across at least two AZs;
- keep workers private and constrain API server access;
- separate human identity from workload identity;
- scale Pods from demand and nodes from unschedulable capacity;
- prevent voluntary disruption from removing too many replicas;
- restrict east-west traffic and container privileges;
- centralize metrics, logs, and audit evidence;
- make node replacement and upgrades repeatable;
- control cost without destroying failure-domain diversity.

AWS recommends Multi-AZ EKS deployments and topology controls for Pod placement. Current AWS guidance also favors EKS Cluster Access Management (access entries) for new clusters and EKS Pod Identity for supported workloads.

---

## 🗺️ Architecture

<p align="center">
  <img src="./architecture/architecture_exact_lossless.png" alt="AWS Production Architecture Series - Article 03 - Amazon EKS at scale" width="1200">
</p>

> **Architecture for this article.** An ALB managed by AWS Load Balancer Controller exposes services. The managed EKS control plane connects to private workers across three AZs. A small Managed Node Group provides stable platform capacity while Karpenter provisions dynamic application capacity. EKS Pod Identity provides temporary per-application AWS credentials; CloudWatch and CloudTrail cover operations and audit.

```text
Users → ALB → Ingress / Services
                 │
            Amazon EKS
      ┌──────────┼──────────┐
     AZ-A       AZ-B       AZ-C
    workers    workers    workers
      └──────────┼──────────┘
           Pods / HPA
                 │
    Pod Identity → AWS APIs

Managed Node Group → stable platform capacity
Karpenter          → dynamic application capacity
CloudWatch/CloudTrail → operations and audit
```

---

# 🧠 Decision 01 — The cluster is not the unit of high availability

EKS operates a highly available control plane, but an application can still be fragile if all three replicas land on one node or one AZ. I therefore design availability at two layers: infrastructure and scheduling.

For production I prefer three AZs when the Region and budget allow it. Deployments use `topologySpreadConstraints` across `topology.kubernetes.io/zone` and `kubernetes.io/hostname`; critical services also receive PodDisruptionBudgets.

**Trade-off:** more AZs improve failure tolerance but can increase inter-AZ data transfer and storage complexity. I do not force distribution blindly for workloads with heavy replica-to-replica traffic without measuring that cost.

---

# 🧠 Decision 02 — Stable Managed Node Group + dynamic Karpenter capacity

I do not place the entire platform behind one autoscaling mechanism. A small Multi-AZ On-Demand Managed Node Group hosts critical platform components. Karpenter supplies variable application capacity and can select instance types from declared workload constraints.

This avoids a circular dependency: the component responsible for creating nodes should not depend exclusively on nodes it creates. It also combines predictable baseline capacity with Spot where interruption is acceptable.

**Alternative:** Cluster Autoscaler with Managed Node Groups remains valid and may be simpler for teams already operating defined groups. Karpenter gains provisioning flexibility and speed, but requires discipline around NodePools, limits, disruption, and instance selection.

---

# 🧠 Decision 03 — Human access and Pod access are different problems

For administrators I use IAM Identity Center + EKS access entries with least-privilege RBAC. I avoid permanent IAM users and do not make `cluster-admin` the normal operating role.

For applications I use **EKS Pod Identity** on compatible runtimes, with one IAM role per application. I do not expand the EC2 node role just because a Pod needs an AWS API permission; that increases blast radius.

IRSA remains a supported alternative when runtime or integration requirements make it a better fit.

---

# 🧠 Decision 04 — Private networking by default

Workers live in private subnets. I prefer a private Kubernetes API endpoint; where public access is operationally required, I restrict it to known corporate CIDRs and keep strong authentication and authorization.

The VPC CNI gives Pods VPC-native networking, but IP addresses become capacity. Before production I model Pod growth, subnet/prefix sizing, and ENI limits. A cluster can have spare CPU and still fail scheduling because it ran out of addresses.

I enable VPC CNI Network Policy and use deny-by-default for sensitive namespaces, opening only required flows.

---

# 🛡️ Security

- EKS access entries + RBAC; no static human credentials.
- EKS Pod Identity/IRSA with least-privilege roles per workload.
- KMS encryption where the threat model requires it; external secret integration for managed rotation.
- ECR image scanning and controlled image promotion.
- `runAsNonRoot`, `allowPrivilegeEscalation: false`, and read-only root filesystems where applications allow it.
- Pod Security Standards/policy-as-code to reject privileged configurations.
- Network Policies to reduce lateral movement.
- CloudTrail and control-plane audit logs for investigation.

---

# 🧯 Resilience

`replicas: 3` is not a resilience strategy by itself. I validate actual placement, requests/limits, probes, and behavior during drains.

```yaml
spec:
  replicas: 3
  template:
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: api
```

For critical workloads I test node loss and loss of capacity in one AZ. A PDB protects against **voluntary** disruptions; it does not replace replicas, topology controls, or recovery from involuntary failures.

---

# 🔭 Observability

I do not consider EKS observable because `kubectl get pods` says `Running`. I monitor four planes:

1. **Application:** latency, errors, throughput, and business metrics.
2. **Kubernetes:** Pending Pods, restarts, OOMKilled, scheduling, HPA, PDB, and events.
3. **Nodes/network:** CPU/memory, disk pressure, available IPs, CNI errors, and capacity per AZ.
4. **Control/security:** API audit, authentication, IAM changes, CloudTrail, and security findings.

CloudWatch Container Insights is a reasonable baseline; Prometheus/Grafana or OpenTelemetry can complement it when portability or workload-specific telemetry matters.

---

# 💰 Cost and FinOps

The EKS cluster fee is not the full platform cost. I review:

- EC2/Fargate and actual utilization;
- NAT Gateway and data processing;
- ALB/NLB;
- CloudWatch Logs and retention;
- EBS/EFS;
- inter-AZ transfer;
- On-Demand versus Spot capacity.

Spot is excellent for interruption-tolerant workers, but not a universal default. The correct choice depends on PDBs, startup time, statefulness, and retry behavior.

---

# ⚙️ Operations and upgrades

I treat upgrades as a platform process: review Kubernetes/add-on versions and deprecated APIs, verify controller compatibility, create replacement capacity, drain gradually, validate SLOs, and only then retire old nodes. I do not blindly update the control plane, CNI, CoreDNS, kube-proxy, and every worker in one shot.

Add-ons stay explicit in IaC and changes are tested in a representative environment. For major transitions, a blue/green cluster costs more but can reduce the risk of an in-place upgrade that is difficult to reverse.

---

# ⚠️ Common mistakes

- assuming managed EKS means Kubernetes without operations;
- one node group for platform and every application;
- Pods without requests/limits and then blaming the autoscaler;
- three replicas concentrated in one AZ;
- expanding the node IAM role to quickly fix an application permission;
- public API endpoint open to `0.0.0.0/0`;
- failing to budget VPC CNI IP capacity;
- PDBs so strict that upgrades cannot progress;
- Spot for components that cannot tolerate interruption;
- indefinite retention of every log stream.

---

# 🧪 Validate before production

- [ ] Do subnets cover 2–3 AZs with enough IP capacity?
- [ ] Does the cluster endpoint have the minimum required exposure?
- [ ] Do administrators use access entries/RBAC?
- [ ] Does each AWS-integrated workload have least-privilege Pod Identity/IRSA?
- [ ] Are critical replicas spread across zones and hosts?
- [ ] Were requests, limits, HPA, and PDB behavior tested under load?
- [ ] Does Karpenter/Cluster Autoscaler have explicit limits and fallback capacity?
- [ ] Are Network Policies and Pod Security controls enforced?
- [ ] Do control-plane logs, metrics, and alerts have defined retention?
- [ ] Was drain, node loss, and AZ-capacity recovery tested?
- [ ] Is there an upgrade and rollback runbook?
- [ ] Were NAT, inter-AZ transfer, and logging costs measured?

---

# 🧱 Terraform baseline

The [`terraform/`](./terraform/) directory provides a deployable baseline: Multi-AZ VPC, public/private subnets, one NAT per AZ, private-endpoint EKS cluster, access entries, Managed Node Group, and essential add-ons. It is deliberately a **baseline**, not a universal platform.

Before production I would add, according to context: Karpenter, AWS Load Balancer Controller, ExternalDNS, secrets integration, observability, GitOps, and organizational policy controls.

---

# 🧭 Architecture lesson

Kubernetes scale does not begin at one hundred nodes. It begins when the next node, Pod, permission, upgrade, or failure no longer depends on a human remembering a special case.

My rule is simple: **if recovery requires remembering which AZ, node group, or role “used to work,” the platform is not designed for scale yet.**

---

## 📚 Official references

- Amazon EKS Best Practices Guide — VPC and Subnet Considerations
- Amazon EKS Best Practices Guide — Identity and Access Management
- Amazon EKS Best Practices Guide — Cluster Access Management
- Amazon EKS Best Practices Guide — Karpenter
- Amazon EKS Best Practices Guide — Running highly-available applications
- Amazon EKS Best Practices Guide — Network Security
- Amazon EKS Best Practices Guide — Pod Security

---

**Juan Gutierrez**  
Solutions Architect · Cloud Architecture · Kubernetes · Security · FinOps · Cloud Modernization

# 🤖 AWS Production Architecture Series — Chapter 06

# The GenAI Era — Amazon Bedrock

### *Taking RAG to production: grounding, guardrails, capacity, and operations before a polished demo*

**Author:** Juan Gutierrez  
**Series:** AWS Production Architecture Series  
**Focus:** Production AWS architecture

---

A GenAI demo can impress with ten documents and a prompt. Production starts when answers must respect permissions, cite evidence, survive throttling, control cost per conversation, and let operators explain why the system answered the way it did. I start with business risk, not the model.

> **Mission:** design an enterprise assistant on Amazon Bedrock that grounds answers with private knowledge, applies controls around inference, and can be measured, degraded, and operated like any other critical system.

## 🎯 Real requirements

- grounded answers backed by authorized, traceable knowledge;
- data isolation, least privilege, and encryption;
- controls against disallowed content and sensitive-data exposure;
- explicit latency, token, concurrency, and quota management;
- bounded recovery from transient capacity failures;
- offline evaluation before release and online telemetry afterward;
- versioned prompts, sources, and configuration;
- cost attribution by application/use case;
- an explicit data-residency decision before cross-Region inference.

---

## 🗺️ Architecture

<p align="center">
  <img src="./architecture/chapter-06-genai-bedrock-production-architecture.png" alt="AWS Production Architecture Series - Chapter 06 - The GenAI Era - Designed by Juan Gutierrez" width="1200">
</p>

> **Image pending manual upload:** `articles/06-genai-era-amazon-bedrock/architecture/chapter-06-genai-bedrock-production-architecture.png`

The pattern separates the **application plane**, **knowledge plane**, and **control plane**. API Gateway/Lambda authenticate, authorize, and construct the request. Bedrock Guardrails evaluates input/output. Knowledge Bases retrieves context from governed documents; the selected model generates against that context. CloudWatch/CloudTrail plus an evaluation pipeline make quality, safety, latency, and cost observable without indiscriminately logging sensitive prompts.

---

# 🧠 Decision 01 — RAG before “teaching the model everything”

For changing enterprise knowledge I prefer RAG: versioned documents in S3, controlled ingestion, embeddings, and retrieval before generation. That decouples document freshness from the model lifecycle and lets the application return evidence/citations.

I do not use RAG by default. If a use case only needs general reasoning, retrieval adds latency and cost. If specialized stable behavior is required, I evaluate prompt engineering or model customization/fine-tuning where supported. **RAG improves grounding; it does not turn generated text into truth.**

Chunking, metadata filters, result count, and source quality are tested with real questions. Retrieving more chunks may improve recall while hurting precision, token use, and latency.

---

# 🧠 Decision 02 — Treat the model as a replaceable dependency

The application should not leak one model provider's details through every layer. I encapsulate inference behind a contract and use Converse where appropriate to reduce coupling. A use-case evaluation set compares quality, latency, and cost before a model change.

The largest model does not automatically win. Classification, extraction, or simple Q&A may meet the SLO with a smaller model at lower cost/latency. Complex reasoning can justify more expensive inference when evaluation proves value.

**Trade-off:** abstraction improves portability, but reducing every model to a lowest common denominator can waste useful capabilities. Isolate dependency without pretending models are identical.

---

# 🧠 Decision 03 — Guardrails is a layer, not the whole security model

Bedrock Guardrails can evaluate prompts and responses using content, denied-topic, sensitive-information, and other policies. I use it as defense in depth; authentication, authorization, source access control, and action validation remain application responsibilities.

A blocked response is an operational outcome that should be measured. Policies need positive/negative tests to balance bypass risk and false positives. In RAG, users must only retrieve content they are authorized to see: **filtering after retrieval is too late**.

---

# 🧠 Decision 04 — Engineer capacity before launch

I measure input/output tokens, concurrency, p50/p95/p99 latency, and capacity errors. Retries are bounded with backoff/jitter. During sustained 503/529 conditions I do not amplify load with infinite retries: stop the ramp, cap concurrency, queue/defer work, and degrade lower-priority traffic.

Where the model supports it, cross-Region inference can improve throughput and resilience; however, prompts/responses can be processed outside the source Region within the configured geography. Residency/compliance comes first. For sustained predictable demand I evaluate Provisioned Throughput.

---

# 🧠 Decision 05 — Evaluate before trusting

I do not promote a prompt/model because it “looks better.” I maintain a representative dataset and acceptance criteria for groundedness, relevance, completeness, safety, format, latency, and cost.

Platform health and answer quality are separate dimensions. A 99.9%-available endpoint that confidently gives bad answers is still a product incident.

---

# 🔐 Security

- workload IAM roles; no embedded access keys;
- VPC endpoints/PrivateLink where the network pattern and service support require it;
- encrypted S3/vector stores and KMS where explicit key policy/control is required;
- Secrets Manager for external integration secrets;
- authorize before retrieval and apply metadata filters where appropriate;
- Guardrails on input/output without substituting authorization;
- CloudTrail for API activity and organizational controls for approved models/Regions;
- treat prompts/logs as potentially sensitive data: redact and minimize retention.

---

# 🧯 Resilience

I define an end-to-end timeout budget across retrieval and inference. Retries apply only to transient failures and actions with side effects require idempotency. If GenAI enhances rather than defines the product, I design degradation: traditional search, an approved cached answer, or a clear unavailable state.

For agentic actions I would use allowlists, narrow scopes, and human-in-the-loop for high-impact operations. The model proposes; a deterministic layer authorizes and executes.

---

# 🔭 Observability

I correlate `requestId`, session, prompt version, model/inference profile, and index version without storing sensitive content by default. I watch:

- API, retrieval, and inference latency;
- input/output tokens and estimated cost;
- throttles/5xx and retries;
- Guardrail interventions;
- retrieval quality and unsupported answers;
- feedback/evaluation by release;
- ingestion failures and source freshness.

CloudWatch carries metrics/alarms and CloudTrail supplies API audit. Dashboards must answer whether **service health or answer quality** degraded.

---

# 💰 Cost and FinOps

Real cost includes inference tokens, embeddings, vector search/storage, ingestion, Guardrails, logs, and networking. I use application inference profiles where useful for usage/cost attribution and compare cost per successfully resolved conversation rather than only price per million tokens.

Removing irrelevant context, bounding output, safe caching, and right-sizing the model usually matter more than micro-optimizing Lambda. Provisioned Throughput makes sense only when utilization/SLOs justify committed capacity.

---

# ⚙️ Operations

- version prompts, guardrails, and infrastructure;
- run an evaluation dataset in CI/CD before promotion;
- canary/A-B model or prompt changes;
- maintain runbooks for throttling, retrieval degradation, and unsafe output;
- define index re-ingestion and rollback procedures;
- review quotas before launches/campaigns;
- assign owners and freshness policy to knowledge sources;
- review Region/model changes against compliance.

---

# ⚠️ Common mistakes

- choosing the model before defining the problem;
- treating RAG as a guarantee of correctness;
- stuffing every document into context;
- retrieving data before checking authorization;
- logging complete prompts/responses in production;
- unbounded retries during capacity pressure;
- enabling cross-Region without residency review;
- measuring uptime but not quality;
- leaving prompts/guardrails outside version control;
- allowing an agent to execute critical actions without deterministic authorization.

---

# 🧪 Production validation

- [ ] Is there a representative evaluation dataset and release threshold?
- [ ] Does retrieval enforce authorization before returning context?
- [ ] Was Guardrails tested for abuse and false positives?
- [ ] Are prompt, model, inference profile, and index versions traceable?
- [ ] Do p95/p99 and token usage meet SLO/budget?
- [ ] Are retries bounded and concurrency controls protecting capacity/downstreams?
- [ ] Does cross-Region usage satisfy residency plus IAM/SCP policy?
- [ ] Is there a degraded mode when inference/retrieval fails?
- [ ] Do logs avoid unnecessary PII/secrets and have defined retention?
- [ ] Can cost be attributed by application/use case?
- [ ] Was rollback of prompt/model/source tested?
- [ ] Do high-impact actions require authorization outside the LLM?

---

# 🧱 Terraform baseline

[`terraform/`](./terraform/) creates a versioned Guardrail and a least-privilege execution role for an application invoking Bedrock. It is intentionally small: the knowledge base, vector store, and API depend on data/network requirements. The first deployment should already treat security and permissions as code.

---

# 🧭 Architecture lesson

My practical rule: **a GenAI application is production-ready when I can explain what it knows, what it can do, what it cannot see, what it costs, and how it fails**. The model matters; the system around it determines whether I can trust it.

---

## 📚 Official references

- Amazon Bedrock — Guardrails and input/output policies
- Amazon Bedrock — Knowledge Bases / RAG
- Amazon Bedrock — Scaling and throughput best practices
- Amazon Bedrock — Inference profiles and cross-Region inference
- AWS Well-Architected — Generative AI Lens

---

**Juan Gutierrez**  
Solutions Architect · Cloud Architecture · Kubernetes · Security · FinOps · Cloud Modernization
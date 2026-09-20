# ⚡ AWS Production Architecture Series — Chapter 05

# The Serverless World — Event-Driven Architecture

### *Designing for bursts, retries, and partial failure without turning Lambda into a distributed monolith*

**Author:** Juan Gutierrez  
**Series:** AWS Production Architecture Series  
**Focus:** Production AWS architecture

---

Serverless removes servers to manage; it does not remove architecture decisions. The real test begins when an API gets a burst, a dependency slows down, an event is delivered twice, or a poison message breaks a batch. I design for those conditions rather than the happy path.

> **Mission:** build an event-driven transactional platform where the synchronous path stays short, decouplable work becomes asynchronous, and every failure has an explicit recovery path.

## 🎯 Real requirements

- accept variable HTTP traffic without idle compute capacity;
- respond without waiting for secondary work;
- absorb bursts and backpressure;
- assume at-least-once delivery and build idempotent consumers;
- isolate messages that cannot be processed;
- use temporary credentials and least privilege;
- trace a request across events and consumers;
- protect constrained downstream systems with concurrency controls;
- safely replay failures;
- understand cost per request, event, transition, and telemetry.

---

## 🗺️ Architecture

<p align="center">
  <img src="./architecture/chapter-05-serverless-event-driven-architecture.png" alt="AWS Production Architecture Series - Chapter 05 - The Serverless World - Designed by Juan Gutierrez" width="1200">
</p>

> **Image pending manual upload:** `articles/05-serverless-world/architecture/chapter-05-serverless-event-driven-architecture.png`

The reference architecture separates two paths. The **synchronous path** uses Amazon API Gateway, Lambda, and DynamoDB to accept and persist intent quickly. The **asynchronous path** publishes domain events to EventBridge, buffers work with SQS, and runs independent Lambda consumers. Step Functions is introduced only where a workflow genuinely needs visible state, compensation, or decisions.

---

# 🧠 Decision 01 — Keep the synchronous path short

I do not chain five Lambda functions behind one HTTP request. Every hop adds latency, failure modes, and coupling. If the caller only needs confirmation that work was accepted, I persist the minimum state and decouple secondary effects.

API Gateway provides the HTTP contract, authentication integration, and throttling; Lambda runs business logic; DynamoDB is a low-operations persistence option. If the workload requires relational queries or SQL transactions, Aurora Serverless v2 may be a better fit: **serverless compute does not require NoSQL**.

**Trade-off:** returning `202 Accepted` improves isolation and resilience, but the client needs a status resource or later notification. Operations requiring an immediate result remain synchronous with an explicit latency budget.

---

# 🧠 Decision 02 — EventBridge routes; SQS absorbs pressure

EventBridge and SQS solve different problems. I use **EventBridge** to route domain events by rules and let new consumers subscribe without changing the producer. I use **SQS** before consumers when I need buffering, backpressure, and control over processing rate.

I do not add a queue between every component by default. If a consumer can safely process an event directly and its failure model is simple, direct integration reduces cost and operational surface.

**Trade-off:** decoupling improves failure isolation but introduces eventual consistency, distributed observability, and DLQ operations.

---

# 🧠 Decision 03 — At-least-once changes business logic

An event can be processed more than once. A Lambda that charges, reserves inventory, or creates an order cannot equate “one invocation” with “one business effect.”

I use a stable **idempotency key** such as `orderId + operation` and a conditional DynamoDB record with TTL. A duplicate either returns the previous outcome or becomes a no-op, depending on the operation. Idempotency must protect the business side effect, not just the handler.

For SQS batch consumers I enable partial batch responses so one poison message does not force successful records to be processed again.

---

# 🧠 Decision 04 — A DLQ is not a recovery strategy

Critical queues get a redrive policy and DLQ, but a DLQ without an alarm, owner, and runbook is only error storage.

I define retry count, transient versus permanent errors, DLQ depth/age alarms, inspection/redrive procedure, and safeguards against replaying non-idempotent effects. SQS visibility timeout must reflect actual processing time. Lambda concurrency is capped when the downstream API or database cannot scale as quickly as the queue.

---

# 🧠 Decision 05 — Orchestrate when state matters

I use Step Functions when the process has steps, timeouts, retries, branches, compensation, or waits and I want state to be visible. I do not use orchestration to replace three lines of application code.

For long-running or auditable business workflows I favor explicit orchestration. For independent fan-out, event choreography is often simpler. The architectural question is **where the knowledge of the business process should live**.

---

# 🔐 Security

- Choose API Gateway authentication based on the caller; add WAF when exposure and risk justify it.
- Use a narrow execution role per function/responsibility rather than broad shared roles.
- Store secrets/configuration in Secrets Manager or Parameter Store, never source code.
- Use KMS where explicit key ownership and policy control are required.
- Apply EventBridge/SQS resource policies for cross-account integrations.
- Do not place Lambda in a VPC by habit; do it when private resources or network controls require it.
- Validate payloads and authorize the business action; do not trust data merely because it came through an AWS service.

---

# 🧯 Resilience

Serverless still has limits. I design around Lambda concurrency, service quotas, downstream capacity, and message size/retention.

A queue is a shock absorber, but I monitor **message age**, not just depth. A stable backlog can hide a 40-minute business delay. External calls get aggressive timeouts, backoff/jitter retries, and circuit-breaking where appropriate.

If strict ordering or SQS deduplication is a real requirement, I evaluate FIFO and its throughput/message-group implications. I do not choose FIFO simply because it sounds safer.

---

# 🔭 Observability

I propagate `requestId`, `correlationId`, and business identifiers through API calls, events, and consumers. Structured logs and metrics should represent customer experience as well as infrastructure:

- API Gateway and Lambda latency/errors/throttles;
- Lambda duration and concurrency;
- SQS/DLQ age and depth;
- Step Functions failures;
- failed/discarded events;
- end-to-end transaction duration.

CloudWatch provides logs, metrics, and alarms; tracing helps follow distributed transactions. I avoid logging full payloads containing PII just because it makes debugging easier.

---

# 💰 Cost and FinOps

Serverless is compelling for variable demand, but it is not automatically cheaper. I model API Gateway requests/data transfer, Lambda invocation/duration/memory, SQS/EventBridge requests, DynamoDB capacity/storage, Step Functions transitions, CloudWatch ingestion/retention, and NAT Gateway when VPC-attached functions need Internet egress.

Lambda memory tuning can reduce both duration and total cost. Before putting functions in private subnets, I model NAT cost and consider private endpoints. At high, steady utilization I compare ECS/Fargate or persistent compute: the right answer depends on the demand curve and operational cost, not the “serverless” label.

---

# ⚙️ Operations

- version event contracts and preserve backward compatibility;
- use versions/aliases and gradual deployment for critical functions;
- apply reserved concurrency where it protects downstreams;
- test DLQ/redrive rather than merely configuring it;
- build dashboards around business journeys;
- give actionable alarms an owner and runbook;
- load-test bursts, poison messages, duplicates, and slow downstreams;
- manage queues, rules, permissions, and alarms as code.

---

# ⚠️ Common mistakes

- turning one Lambda into a 30-responsibility monolith;
- synchronous Lambda → Lambda → Lambda chains;
- assuming exactly-once processing;
- DLQs without alarms or redrive procedures;
- retrying permanent errors until capacity is consumed;
- unlimited concurrency against constrained dependencies;
- choosing EventBridge when buffering is required;
- choosing SQS when flexible routing/fan-out is required;
- putting every Lambda in a VPC “for security”;
- logging tokens, PII, or complete payloads;
- ignoring observability and NAT costs.

---

# 🧪 Production validation

- [ ] Is the synchronous path limited to what the caller must wait for?
- [ ] Does each event have a schema, owner, version, and correlation identifier?
- [ ] Are consumers idempotent under duplicate delivery?
- [ ] Are SQS visibility timeout and Lambda timeout coherent?
- [ ] Are partial batch responses enabled where appropriate?
- [ ] Does every critical DLQ have an alarm, runbook, and tested redrive?
- [ ] Does reserved concurrency protect constrained dependencies?
- [ ] Do retry policies distinguish transient from permanent failures?
- [ ] Does each function use least-privilege IAM?
- [ ] Are secrets and unnecessary PII absent from logs/events?
- [ ] Do dashboards expose end-to-end latency and backlog age?
- [ ] Have burst, duplicate, poison-message, and downstream-failure tests passed?
- [ ] Was cost compared with a non-serverless alternative at expected load?

---

# 🧱 Terraform baseline

[`terraform/`](./terraform/) deploys a deliberately small EventBridge custom bus → SQS → Lambda pattern with a DLQ, least-privilege permissions, and partial batch responses. It is a deployable baseline for decoupling and idempotency exercises; API, business datastore, and authentication should be added for the actual workload.

---

# 🧭 Architecture lesson

My practical rule is: **serverless works best when each component has a small responsibility and failure is part of the contract**. The question is not “can I build this with Lambda?” but “what happens to the business when this event arrives twice, 20 minutes late, or cannot be processed?”

If the architecture cannot answer that, it is still a demo.

---

## 📚 Official references

- AWS Lambda — Designing Lambda applications / event-driven architectures
- AWS Lambda — Best practices
- AWS Lambda + Amazon SQS — event source mappings and partial batch responses
- AWS Prescriptive Guidance — partial batch responses and DLQ patterns
- Amazon EventBridge — event-driven architectures
- AWS Step Functions — orchestration and EventBridge integration

---

**Juan Gutierrez**  
Solutions Architect · Cloud Architecture · Kubernetes · Security · FinOps · Cloud Modernization

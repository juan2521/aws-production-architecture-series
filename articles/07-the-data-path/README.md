# 📊 AWS Production Architecture Series — Chapter 07

# The Data Path — Governed Analytics on AWS

### *From scattered files and events to trustworthy, traceable, operable data*

**Author:** Juan Gutierrez  
**Series:** AWS Production Architecture Series  
**Focus:** Production AWS architecture

---

A data lake is not a collection of buckets. The real risk is not storing terabytes; it is shipping incorrect decisions because a schema changed, duplicating records during replay, granting excessive access, or discovering that every query scans every file. I design for data ownership, quality, and recovery before choosing services.

> **Mission:** deliver batch and streaming ingestion, replayable raw storage, validated transformations, governed curated datasets, cost-controlled analytics, and production runbooks.

## 🎯 Real requirements

- Ingest CSV/JSON batches and continuous events without tightly coupling producers to consumers.
- Retain replayable source data, enforce data quality, quarantine bad records, and maintain lineage.
- Provide SQL access to curated data; add a warehouse only when query patterns justify it.
- Enforce dataset/table/column permissions across teams and environments.
- Agree on freshness, RPO/RTO, operational ownership, and alerting per dataset.
- Measure storage, ETL, streaming, and query cost.
- Version infrastructure, schema, and transformations; trace every pipeline run.

## 🗺️ Architecture

![The Data Path — AWS production architecture by Juan Gutierrez](./architecture/chapter-07-data-path-architecture.png)

**Awaiting manual image upload:** `articles/07-the-data-path/architecture/chapter-07-data-path-architecture.png`.

**Flow:** batch producers → S3 raw; event producers → Kinesis Data Streams → S3 raw landing consumer; AWS Glue validates and transforms, sends rejects to S3 quarantine, and writes compressed Parquet to S3 curated; Glue Data Catalog and Lake Formation govern access; Athena queries curated data and Redshift serves selected warehouse workloads. CloudWatch and CloudTrail cover operational telemetry and API auditing. **This is a reference pattern, not a mandate to deploy every component on day one.**

---

## 🧠 Decision 01 — Raw is the recovery contract, not the query layer

Preserve source objects in S3 with source/ingestion-date prefixes, encryption, appropriate versioning, provenance metadata, batch IDs, and checksums. Analysts should not have unrestricted raw access: data may include PII, invalid records, and incomplete batches.

**Alternative:** transform before landing. This reduces temporary storage but makes incident replay and rule changes harder. S3 is not inherently WORM; if immutable retention is mandatory, evaluate S3 Object Lock and regulatory retention requirements.

## 🧠 Decision 02 — Stream only when freshness requires it

Kinesis Data Streams decouples producers and consumers and supports configurable retention for replay. A landing consumer writes events to S3. Retries and delivery semantics can produce duplicates; use stable event IDs, checkpoints, and idempotent processing rather than claiming end-to-end exactly-once behavior.

**Alternative:** periodic batch or managed delivery to S3. If the business tolerates 15–60 minute freshness, I would not run a streaming pipeline for fashion. Streaming buys low latency but adds capacity management, consumer lag, per-key ordering, backpressure, and on-call complexity.

## 🧠 Decision 03 — Curated is a data contract, not a folder

Glue transforms source data, checks schema, nullability, uniqueness, and business ranges, quarantines rejects, and writes compressed Parquet. Choose partitions with sensible cardinality rather than unique IDs; compact small files. Publish a dataset version or manifest only after a successful complete run to prevent partial reads.

**Alternative:** Athena/Redshift SQL ELT for simple workloads. Glue/Spark is justified by transformation complexity and volume, not by service popularity. Parquet helps columnar reads but cannot rescue a poor partition design.

## 🧠 Decision 04 — Governance must be enforced

Glue Data Catalog describes datasets; Lake Formation can centrally grant fine-grained permissions over supported structured tables/columns and additional granular controls depending on engine integration. Register S3 locations and explicitly test that IAM/bucket permissions cannot bypass intended governance. Classification, stewardship, and retention are part of the contract.

**Trade-off:** central policy improves auditability but complicates grants, roles, and troubleshooting. A catalog alone is not authorization; different engines and access paths must be tested individually.

## 🧠 Decision 05 — Athena first; Redshift when measurements support it

Athena offers serverless SQL on curated S3 data, with workgroups, encrypted results, and scan limits. Redshift becomes valuable for dimensional models, sustained SQL transformations, predictable concurrency, or proven performance needs. I would not automatically copy every dataset into a warehouse.

**Trade-off:** Athena minimizes infrastructure operations but query latency and spend depend on data scanned and access frequency; Redshift adds capacity/operations and a different cost model in exchange for warehouse capabilities.

## 🔐 Security

- Least-privilege temporary IAM roles for ingestion, Glue, and readers; environment separation.
- S3 Block Public Access, TLS, bucket policies, encryption (SSE-KMS when key governance requires it), and private connectivity where appropriate.
- Lake Formation permissions and Catalog governance; test direct S3 access and alternate credentials for bypass.
- Classify, tokenize, or mask sensitive fields before publication to curated.
- CloudTrail for API audit; enable S3 data events selectively according to risk and cost.
- Explicit retention, deletion, and access controls for raw and quarantine.

## 🧯 Resilience and consistency

Raw enables curated rebuilds. Record `run_id`, watermark, schema version, input/output/rejected counts, and checksums where useful. Bounded retries must not duplicate outputs; use staging and controlled publication. Monitor Kinesis consumer lag against remaining retention. Cross-Region recovery and replication require separate RPO/RTO and residency decisions; neither happens automatically.

## 🔭 Observability

Per-dataset dashboard: freshness, completeness, reject ratio, Glue duration/failures, Kinesis lag, raw/curated volumes, Athena query failures and bytes scanned. Alert on business thresholds, not only infrastructure errors. CloudWatch carries metrics/logs, CloudTrail carries audit; never indiscriminately log sensitive record values.

## 💰 Cost and FinOps

Account for S3 storage/requests/lifecycle, Kinesis capacity/retention, Glue compute, governance, Athena scanned bytes, optional Redshift, KMS, logs, and data transfer. Compressed Parquet, partition discipline, and small-file compaction often matter more than micro-optimizing transformation code. Tag domains, budget by owner, and measure cost per useful query and processed GB.

## ⚙️ Operations and practitioner judgment

Every dataset needs an owner, schema, freshness SLA, quality policy, retention, and runbook. Incompatible schema changes should fail to quarantine or be versioned, never silently leak into business reports. Reprocessing requires a bounded window and a safe publish/rollback process. Automate infrastructure and transformation tests, but subject business grants to review.

## ⚠️ Common mistakes

- Querying raw directly and assuming that data stored in S3 is governed.
- High-cardinality partitions and millions of tiny files.
- Ignoring duplicates, retries, late events, and watermark policy.
- Assuming Lake Formation alone blocks every direct S3 access path.
- No quality contract, owner, or freshness alarm; treating a SUCCESS job as proof of correct data.
- Enabling streaming and a warehouse without a measurable SLA.
- Overlooking CloudTrail data-event, repeated-query, and logging costs.

## 🧪 Validate before production

- [ ] Can curated be rebuilt from raw consistently?
- [ ] Are duplicates and out-of-order events handled without corrupting business metrics?
- [ ] Does partial failure quarantine rejects without publishing incomplete results?
- [ ] Do unauthorized users get AccessDenied via Athena and direct S3 paths?
- [ ] Does every critical dataset have a freshness/completeness SLO, dashboard, alarm, and owner?
- [ ] Is stream retention sufficient for the worst planned recovery window?
- [ ] Have Parquet, partitioning, and file size reduced measured query scan?
- [ ] Are quotas, lifecycle, load tests, and budget alarms defined?
- [ ] Are recovery, schema rollback, and regulatory deletion procedures tested?

## 🧱 Infrastructure as Code — Terraform

The [terraform/](./terraform/) baseline provisions separate raw/curated/quarantine buckets with encryption, versioning and public-access blocks, a Kinesis stream, Glue Catalog database, and an Athena workgroup with scan limits. **This is a deployable infrastructure baseline, not a complete production ETL application:** domain-specific producers, Glue jobs, IAM/Lake Formation grants, and alarms must be added before production.

### Official AWS references

- [AWS Lake Formation](https://docs.aws.amazon.com/lake-formation/latest/dg/what-is-lake-formation.html)
- [Athena columnar storage](https://docs.aws.amazon.com/athena/latest/ug/columnar-storage.html)
- [AWS Glue Data Quality](https://docs.aws.amazon.com/glue/latest/dg/glue-data-quality.html)
- [Kinesis Data Streams concepts](https://docs.aws.amazon.com/streams/latest/dev/key-concepts.html)

---

**Juan Gutierrez** · AWS Production Architecture Series · Security · Data · Resilience · FinOps

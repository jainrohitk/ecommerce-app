# SRE and Skew: A Beginner's Guide

**Current deployment:** This project now uses prebuilt OpenTelemetry Demo images. `checkout` represents order processing, `email` represents notification, PostgreSQL holds catalog data, and Redis stores carts. The SLO numbers and advanced idempotency, reconciliation, and outbox practices below are teaching examples, not guarantees implemented by those images. A Redis outage affects carts; there is no cart-to-database fallback.

## 1. What Is SRE?

**Site Reliability Engineering (SRE)** applies software engineering to keeping services reliable. It combines measurement, automation, failure handling, and operational practices.

For this e-commerce project, reliability means customers can browse products, submit orders, receive correct payment outcomes, and get notifications within acceptable times.

SRE is not just keeping Kubernetes pods running. A healthy pod can still return incorrect orders or fail to reach the database.

This guide describes learning goals, not an already implemented system. The default low-memory profile uses one kind node: it supports pod and dependency failure exercises, but not cross-node scheduling or node-failure recovery. A future multi-node kind setup still runs on one host and does not provide independent-host availability or prove production readiness.

## 2. SLI, SLO, and SLA

| Term | Meaning | E-commerce example |
|---|---|---|
| SLI: service-level indicator | A measurement of user-visible service quality. | Fraction of eligible catalog requests served successfully. |
| SLO: service-level objective | A target for an SLI over a defined period. | At least 99.9% of eligible catalog requests succeed over a rolling 30 days. |
| SLA: service-level agreement | An agreement with customers that defines service commitments and consequences for missing them. | A contractual availability commitment with service credits. |

Remember: **SLI = what we measure; SLO = our target; SLA = our agreement.**

This learning project needs example SLOs, not a real customer SLA.

### Define the measurement before choosing a target

Every SLO should specify:

- The user journey and measurement point.
- What makes an event eligible, good, or bad.
- The target and measurement window.
- The telemetry source and how missing data is handled.
- An owner and the action to take when reliability deteriorates.

For example, invalid customer inputs and expected payment declines are not automatically infrastructure failures. A payment timeout with an unknown outcome is not a successful checkout. Document these distinctions rather than counting every HTTP response the same way.

### Illustrative starting targets

These are learning examples, not validated requirements or promises. Adjust them after observing baseline behavior.

| Journey | Example SLI | Example SLO |
|---|---|---|
| Browse catalog | Successful eligible requests / all eligible requests | At least 99.9% over 30 days |
| Catalog speed | Successful eligible requests completed within 500 ms / all eligible requests | At least 99% over 30 days |
| Checkout | Eligible submissions that reach the correct durable order/payment outcome within 5 seconds / all eligible submissions | At least 99.5% over 30 days |
| Notifications | Notifications delivered within 60 seconds / all notifications due | At least 99% over 30 days |

Count each logical checkout once, not every internal retry. Measure notification completion, not merely acceptance into a retry mechanism. Use short test windows for exercises, but do not claim they establish a 30-day SLO.

## 3. Error Budgets and Burn Rate

An **error budget** is the amount of unreliability an SLO permits.

```text
Allowed bad-event fraction = 1 - SLO target
Allowed bad events = eligible events in the window x allowed bad-event fraction
```

For a 99.9% request-success SLO and 100,000 eligible requests, the budget is 100 bad requests. If 60 requests fail, 40 remain within the budget for that window. In a rolling window, old events eventually leave the calculation.

For a separate time-based availability SLO, 99.9% over 30 days allows 43.2 minutes of unavailability. Do not substitute this downtime allowance for a request-based budget: traffic volume changes the impact.

**Burn rate** tells you how quickly you are spending the budget:

```text
Burn rate = observed bad-event fraction / allowed bad-event fraction
```

With a 99.9% SLO, a 1% error rate gives a burn rate of 10. If sustained under the same traffic assumptions, failures consume the budget ten times faster than the sustainable rate.

Use short and long alert windows together to catch sustained harm without paging on every brief spike. A simple learning policy is to prioritize reliability fixes over nonessential releases when the budget is exhausted.

## 4. What to Observe

Start with four signals:

| Signal | Question | Example |
|---|---|---|
| Latency | How long do requests take? | Catalog p95 and p99 latency |
| Traffic | How much work arrives? | Requests per second |
| Errors | How much work fails? | Checkout failures and payment timeouts |
| Saturation | How close are resources to their limits? | CPU throttling, database connection usage, retry backlog |

**p95 latency** means 95% of measured requests completed at or below that duration. An average can hide a small number of very slow requests. Do not average pod-level p95 values to obtain a service-wide p95; aggregate compatible histogram buckets and then calculate the percentile.

### Roles of this project's observability tools

- **OpenTelemetry:** Instruments requests and propagates trace context between services.
- **Prometheus:** Stores metrics used for dashboards, SLI calculations, and alert rules.
- **Grafana Tempo:** Stores distributed traces for investigating individual request paths.
- **Grafana:** Queries these backends and displays dashboards, traces, and service maps.
- **Tempo service graph metrics:** Describe observed service connections, request rates, latency, and errors; write them to Prometheus for Grafana's service map.

A service map is not an inventory of every possible dependency. Missing instrumentation, broken context propagation, sampling, and unpaired spans can leave connections missing. Trace sampling also means traces alone may not provide complete SLI counts.

Application logs add failure details. Prometheus does not store application logs, and Tempo is not a general-purpose log backend. This project has not selected a centralized log backend.

Use low-cardinality metric labels such as service name and route template. Do not use order IDs, customer IDs, secrets, or payment details as metric labels. Where configured, exemplars can link a metric observation to a trace without turning trace IDs into labels.

## 5. What Does "Skew" Mean?

**Skew means a difference or imbalance.** It is not a single SRE framework or a standard acronym. Always ask: what is different, compared with what, and why does the difference matter?

### Clock skew

Two machines disagree about the current time.

- **Example:** A payment service records a timestamp later than an order service's completion timestamp.
- **Impact:** Confusing trace timelines, incorrect expiry checks, and unreliable timestamp-based ordering.
- **Response:** Synchronize host clocks using NTP or an equivalent time service. Use monotonic clocks for measuring elapsed time and trace parent-child relationships for causality, rather than relying only on wall-clock timestamps.
- **kind caveat:** Containers on one host generally share its clock, so this setup does not reproduce independent-machine clock drift. Do not change the shared host clock for an exercise.

### Kubernetes version skew

Kubernetes components run different versions.

- **Example:** `kubectl`, the API server, and worker-node kubelets use different minor versions.
- **Impact:** Unsupported combinations can cause compatibility problems.
- **Response:** Check the official version-skew policy before installation or upgrades. Pin compatible kind node images and tooling versions.

The current policy supports `kubectl` within one minor version older or newer than the API server. A kubelet must not be newer than the API server; the allowed older-version gap depends on the component versions. Other components have their own rules, and deployment tools may add restrictions. Do not apply the `kubectl` rule to every component.

### Application version and configuration skew

Application replicas have different code, API expectations, or settings.

- **Example:** During a rolling deployment, old order-service replicas cannot read a new payment response or database schema.
- **Impact:** Only some requests fail, making the problem appear intermittent.
- **Response:** Use backward-compatible API and schema changes, pinned image versions, consistent configuration, and a tested rollback path. Monitor failures by release version.

Temporary mixed versions during a rollout are normal; incompatibility is the problem.

### Traffic and load skew

Some replicas, services, or nodes receive much more work than others.

- **Example:** One catalog replica handles most requests because of sticky sessions or long-lived connections.
- **Impact:** That replica becomes slow while others remain mostly idle.
- **Response:** Compare request rates and resource usage per replica. Investigate routing and connection reuse before simply adding replicas.

Pod placement imbalance is related but different. Topology spread constraints can spread pods across nodes, but they do not guarantee balanced request traffic.

### Data skew

Some keys, products, or partitions account for disproportionate data or activity.

- **Example:** A promotion makes one product extremely popular, creating a hot row or cache key.
- **Impact:** Contention, slow queries, uneven cache performance, or hot database partitions.
- **Response:** Measure query latency and contention, inspect query plans, and consider suitable indexes or caching before introducing partitioning.

Data skew matters even with one database. Sharding is not required for this learning project.

### Latency distribution skew

Most requests are fast, but a small tail is much slower.

- **Example:** Cache misses or payment timeouts affect only a small fraction of checkouts.
- **Impact:** Average latency looks acceptable while some customers have a poor experience.
- **Response:** Inspect latency histograms, p95/p99, and slow traces. Compare routes and outcomes to find the slow dependency.

This is a statistical use of "skew," not a separate universal SRE metric.

## 6. Reliability Practices for This Project

- **Timeouts:** Bound dependency calls and keep them within the overall request deadline.
- **Retries:** Retry only suitable transient failures, with a limit, backoff, and jitter. Uncontrolled retries can amplify an outage.
- **Idempotency:** Repeating the same logical payment or order request must not create duplicate side effects.
- **Graceful degradation:** A failed notification must not undo a completed order. Make the failure visible and retry within a defined policy.
- **Health probes:** Readiness controls traffic eligibility; liveness can trigger restarts. Do not make liveness depend on every downstream service, which can cause cascading restarts.
- **Capacity planning:** Observe CPU, memory, connection limits, and latency as traffic increases.
- **Recovery:** Persistent volumes help retain data across pod replacement, but they are not backups. Real recovery needs backup and restore testing.
- **Toil reduction:** Automate repetitive setup and diagnosis; keep installation repeatable and failures explicit.

## 7. Safe Learning Exercises

Perform fault injection only in a dedicated local cluster, with synthetic data, bounded traffic, a rollback step, and an owner. Do not target a shared environment.

| Exercise | Observe | Expected learning outcome |
|---|---|---|
| Inject a dummy payment timeout | Checkout errors, traces, order/payment states | No false success or duplicate payment; unknown outcomes are reconciled |
| Make notification delivery unavailable | Retry counts, backlog, delivery SLI | Completed orders remain valid; exhausted retries are visible |
| Replace one application pod | Readiness, request errors, recovery time | Measure the impact; surviving capacity determines continuity |
| Increase traffic for one product | Replica load, query latency, tail latency | Identify traffic or data hotspots |
| Deploy compatible mixed application versions | Errors grouped by version, trace paths | Confirm rolling-deployment compatibility |

For each exercise, record the baseline, injected failure, user impact, SLI changes, recovery time, and preventive action. Generate enough events to interpret ratios; no traffic or missing telemetry is not evidence of 100% reliability.

## 8. A Simple Incident Runbook

1. Confirm user impact and affected journeys in Grafana.
2. Check error-budget burn, errors, latency, and missing telemetry.
3. Use the service map to narrow the dependency, then inspect relevant Tempo traces and application logs.
4. Check recent deployments, pod readiness, resource pressure, and database connectivity.
5. Mitigate with a known-safe action, such as reverting a compatible release or reducing load.
6. Verify that user journeys recover, not merely that pods become healthy.
7. Write a blameless review: timeline, impact, contributing causes, what helped, and owned follow-up actions.

Do not log secrets during diagnosis. An alert should have an owner and a clear action; a dashboard alone is not incident response.

## 9. Suggested Learning Order

1. Understand one successful checkout and its distributed trace.
2. Build traffic, error, latency, and saturation dashboards.
3. Define one catalog SLO and its error budget.
4. Run a bounded failure exercise and follow the runbook.
5. Investigate traffic/data skew and rollout compatibility.
6. Study Kubernetes version skew before changing cluster versions.

## References

- [Google SRE Workbook: Implementing SLOs](https://sre.google/workbook/implementing-slos/)
- [Google SRE Workbook: Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- [Kubernetes Version Skew Policy](https://kubernetes.io/releases/version-skew-policy/)

Version policies can change. Consult the official policy for the specific versions used by the project.

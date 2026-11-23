# E-Commerce Interview Preparation

**Purpose:** prepare for interviews, not run the demo. Answers below describe a simple design and proposed improvements; they are not claims of a successfully tested deployment.

## 1. Explain the Project in 30 Seconds

> "I designed a small e-commerce system with a frontend, catalog, order, dummy payment, and notification service. The deployment design uses Kubernetes and Kustomize, PostgreSQL for persistent data, and Redis for carts. OpenTelemetry sends telemetry through a Collector to Prometheus and Grafana Tempo, with Grafana for dashboards and service maps. I explored resource sizing, dependency failures, and security. The local demo was not fully validated, so I distinguish the design from proven runtime behavior."

For discussion, keep the scope to **five application services**:

```text
Frontend --> Catalog
Frontend --> Order --> Dummy Payment
                  --> Notification

PostgreSQL: catalog and proposed durable order records
Redis: carts
OpenTelemetry --> Collector --> Tempo / Prometheus --> Grafana
```

Databases and observability tools are infrastructure, not extra business services. This simplified design is different from the larger prebuilt demo currently represented by the manifests. A real cart API would belong to the frontend/backend or a separate service; Redis itself does not provide a customer-facing API.

## 2. Architecture and Data

### 1. Why split the application into services?
Separate responsibilities and allow independent deployment and scaling. The trade-off is network failures, harder debugging, and operational overhead. For a small application, a modular monolith may be simpler.

### 2. Walk through checkout.
The frontend submits a cart to the order service. It validates products and prices, records an order, calls payment, records the result, and requests a notification. Durable order recording is a proposed improvement, not a verified feature of the prebuilt demo.

### 3. Why PostgreSQL and Redis?
PostgreSQL provides transactions and durable relational records. Redis provides fast cart access. In the current design, Redis is cart storage, not a catalog cache.

### 4. What happens if Redis fails?
Cart operations can fail. Return a clear temporary error and preserve recoverable data. Do not claim PostgreSQL automatically supplies missing cart data unless that fallback is explicitly implemented.

### 5. Does a persistent volume replace backups?
No. A PVC supplies storage; Redis AOF helps recover persisted writes. Neither protects against every deletion, corruption, or host failure. Backups require tested restoration.

## 3. Kubernetes and Deployment

### 6. What are a Pod, Deployment, and Service?
A Pod runs containers. A Deployment maintains the desired replicas and manages rollouts. A Service provides stable routing to selected Pods.

### 7. Why use Kustomize?
It combines plain Kubernetes manifests and configuration without a custom renderer. Preview with `kubectl kustomize kubernetes`; deploy with `kubectl apply -k kubernetes` using the intended kubeconfig and context.

### 8. What are requests and limits?
Requests guide scheduling and resource allocation. CPU limits throttle execution; exceeding memory limits can cause an OOM kill. Low requests do not guarantee low actual usage.

### 9. How would you size this application?
Measure idle, startup, and loaded memory; observe latency, CPU throttling, and restarts. Leave headroom for Kubernetes and bursts. Do not size a cluster from application requests alone.

### 10. How do startup, readiness, and liveness probes differ?
Startup allows initialization before readiness/liveness probes run. Readiness determines whether a Pod receives Service traffic. Liveness detects a stuck process and can restart it. A shared dependency failure should not cause every Pod to restart.

### 11. Does one kind node provide high availability?
No. It is useful for local learning. Even multiple kind nodes on one machine share a host failure domain.

### 12. What does NetworkPolicy do?
It controls allowed Pod network traffic when enforced by a compatible CNI, such as Calico. Start with default deny, then permit DNS and required dependencies. It is not a substitute for authentication.

## 4. OpenTelemetry and SRE

### 13. What is the role of each observability tool?
- **OpenTelemetry SDKs:** create traces, metrics, and logs.
- **Collector:** receives, processes, and exports telemetry.
- **Prometheus:** stores and queries metrics.
- **Tempo:** stores and queries traces.
- **Grafana:** visualizes metrics and traces.

### 14. What is a trace, and how does it cross services?
A trace describes one request as related spans. Services propagate trace context, commonly through W3C `traceparent`, so downstream spans can be linked to the same request.

### 15. How does Grafana's service map work?
Tempo's metrics-generator derives service-graph metrics from suitable spans and remote-writes them to Prometheus. Grafana's Tempo datasource links to Prometheus. Missing context, missing spans, or no recent traffic can produce missing edges.

### 16. Do namespace annotations enable OpenTelemetry automatically?
Not by themselves. Operator-based injection requires the OpenTelemetry Operator and appropriate instrumentation configuration. The selected prebuilt images already include instrumentation; injecting another agent can duplicate it.

### 17. Which signals would you watch first?
Request rate, error rate, latency distributions, and resource saturation. For checkout, also measure successful business outcomes: HTTP success alone does not prove a correct payment or order.

### 18. What are SLI, SLO, SLA, and error budget?
An SLI is a measurement; an SLO is its target; an SLA is an agreement, often with consequences. For a 99.9% success SLO, the error budget is the allowed 0.1% failure fraction over the defined window.

### 19. What does p95 latency mean?
95% of measured requests completed at or below that latency. It is not the average. To calculate a combined percentile, aggregate compatible histogram buckets rather than averaging replica percentiles.

### 20. What traffic does this project propose?
10 concurrent HTTP users for 600 seconds, ramping up at one user per second. Concurrency is not requests per second; throughput depends on task mix, pauses, and response times. No successful full-run results have been established.

## 5. Failure and Security Scenarios

### 21. Payment timed out. Should you retry?
The result may be uncertain: the provider could have charged before the response was lost. Use a stable idempotency key and reconcile provider status before issuing another charge.

### 22. How would you avoid losing a notification after an order commits?
Write the order and an outbox event in the same database transaction. A worker delivers the event with bounded retries. Consumers should handle duplicates; this is not an automatic exactly-once guarantee.

### 23. How can retries worsen an outage?
They multiply load on an unhealthy dependency. Use deadlines, retry limits, exponential backoff with jitter, and idempotency for side effects.

### 24. How would users log in?
The current prebuilt demo is guest-only. A real design could use an OIDC identity provider; the frontend/backend must integrate with it and enforce user-specific authorization. Deploying an identity provider alone does not add login.

### 25. How would you secure secrets and telemetry?
Use Secrets rather than ConfigMaps for credentials, restrict access, and enable appropriate encryption at rest. Base64 is not encryption. Avoid recording passwords, tokens, and payment data; Collector filtering does not protect raw container logs.

### 26. Checkout is slow. How would you investigate?
Check user-visible latency and errors, inspect a slow trace, identify the slow dependency, then examine its resource usage, database calls, timeouts, and recent changes. Avoid restarting everything before identifying the cause.

### 27. A Pod is restarting. What would you check?
Inspect its last termination reason, previous logs, events, and probe failures. Distinguish OOM kills, application errors, and failed probes before changing limits or code.

### 28. What did the unsuccessful local deployment teach you?
Keep dependencies and operational scope small, validate the smallest user journey early, and measure host capacity before adding infrastructure. Static YAML validation does not prove a working application.

## 6. How to Practise

1. Explain the five-service flow without looking at the diagram.
2. Answer questions 6-20 in 30-60 seconds each.
3. Practise payment timeout, slow checkout, and Pod restart scenarios aloud.
4. Say **"I would implement"** for proposed features and **"I verified"** only for demonstrated results.

Further reading: [Kustomize basics](../Kustomize-readme.md) and [SRE concepts](../SRE-readme.md).

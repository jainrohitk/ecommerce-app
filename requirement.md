# E-Commerce Project Requirements

## 1. Project Objective

Build a learning-focused e-commerce application that follows real-world production practices and uses a microservices architecture.

### Approved Implementation Approach

- Deploy published OpenTelemetry Demo 3.1.0 images; do not create custom application code or build application images.
- Keep readable, checked-in YAML under `kubernetes/<service>/`, with component configuration beside its manifest.
- Use kubectl's built-in Kustomize to apply these files; do not depend on a custom manifest renderer.
- Include the upstream supporting services needed by the storefront and checkout.
- Treat advanced reliability and identity requirements below as documented learning goals where the prebuilt demo does not implement them. Do not claim Kubernetes manifests add application-level guarantees.

## 2. Application Components

The application must include:

- A user-facing frontend.
- A product catalog service.
- A dummy payment application.
- An order processing service.
- A notification service.
- A database service using MongoDB or PostgreSQL.
- A Redis service for cart storage, replacing the demo's Redis-compatible Valkey store. PostgreSQL remains the source of catalog data.

Explain the upstream components' languages and roles. Use ready-made images for both the application and infrastructure.

## 3. Deployment

- Default to a single-node kind cluster with a low-memory profile for a Docker allocation of approximately 4 GB. Retain shopping/checkout, Redis/PostgreSQL, and the Prometheus/Grafana/Tempo tracing and service-map path.
- Keep required upstream dependencies; exclude optional services only where the unchanged images support doing so without failed requests.
- Define explicit CPU and memory requests/limits, reduce runtime heaps and telemetry buffers, and validate actual consumption and restarts under load. Container requests alone do not establish sufficient cluster memory.
- Treat multi-node scheduling and node-failure exercises as a future larger-memory configuration, not a capability of the default local setup.
- Provide a one-shot installation shell script.

## 4. Traffic Generation

Provide a traffic generation script to exercise the application and observe its behavior in real time.

Default to 10 concurrent HTTP users for 600 seconds, ramping up at one user per second. Allow smaller runs and retain the maximum of 10 users / 600 seconds.

## 5. Observability

- Instrument the application components with OpenTelemetry.
- Use Prometheus as the metrics backend and Grafana for visualization and dashboards.
- Use Grafana Tempo as the trace backend and configure Grafana to query Tempo for inspecting distributed traces.
- Provide a service map in Grafana using Tempo's service graph metrics. Enable Tempo's metrics-generator service graphs processor, remote-write its metrics to Prometheus, and link the Tempo data source to the Prometheus data source in Grafana. Ensure traces include consistent service names and propagated trace context so the map shows service dependencies, request rates, latency, and errors.
- Provide dashboards for request rates, error rates, latency, and service health.
- Monitor Redis keyspace hit/miss rates, cart storage latency, errors, memory usage, and evictions. Include cart-to-Redis calls in distributed traces and the Grafana service map.
- Make calls between services observable so that request flows and service interactions can be understood.
- Document instrumentation in `doc/appdynamics/README.md`.

## 6. Failure Handling and Learning Goals

- Demonstrate upstream fault flags, dependency unavailability, and resulting errors using telemetry.
- Configure deployment health probes, gateway deadlines, database connection deadlines, and bounded traffic generation.
- Document upstream retry behavior and the risk of retrying side effects without idempotency.
- Explain payment/order idempotency, explicit uncertain states, reconciliation, transactional notification outboxes, and bounded delivery retries as advanced learning goals, not implemented guarantees of the core demo.
- Persist Redis cart data using a PVC and AOF. Document that Redis unavailability affects carts; there is no catalog-cache or cart-to-PostgreSQL fallback.
- Validate the running storefront, checkout, database, Redis, and service-map paths when local resources permit; identify any unverified behavior explicitly.

## 7. Security

- Use synthetic customer data and dummy payments only; do not collect real payment information.
- Keep credentials and secrets out of source code, container images, and documentation. Supply them through Kubernetes Secrets and document secure local setup.
- Document input validation supplied by the upstream demo and its lack of production identity/authorization. Treat a real identity provider and user-specific order authorization as learning goals before non-local deployment.
- Apply least-privilege permissions to application, database, and Kubernetes service accounts.
- Run application containers as non-root users and restrict network access to required service connections.
- Do not expose databases or internal services publicly. Document TLS requirements for any access beyond the local learning environment.
- Keep Redis accessible only to the cart service and its local exporter, configure authentication using Kubernetes Secrets, and do not store credentials or payment information in cart data.
- Exclude secrets, payment information, and sensitive customer data from logs, traces, and metric labels.
- Check application dependencies and container images for known vulnerabilities and document how to address findings.

## 8. Documentation

- **Project overview (`README.md`):** Provide concise project details, including the architecture, technology choices, setup instructions, service interactions, failure handling, and security practices.
- **Architecture diagram (`README.md`):** Include a Mermaid diagram showing the application components, database, Redis, calls between services, Prometheus, Grafana Tempo, Grafana, and deployment within the default single-node kind cluster.
- **Interview questionnaire (`doc/questionnaire/README.md`):** Include potential interview questions related to the project.
- **SRE concepts ([`doc/SRE-readme.md`](doc/SRE-readme.md)):** Provide a beginner-friendly guide to SLAs, SLOs, SLIs, error budgets, monitoring, incident response, and clock, Kubernetes version, application/configuration, traffic/load, data, and latency distribution skew, with project-specific examples and safe learning exercises.
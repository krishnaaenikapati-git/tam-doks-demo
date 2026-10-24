# Interview walkthrough

## Opening (45 seconds)

The customer wants a web application that can grow with demand while keeping costs understandable. I prepared a stateless Node.js application, a Docker image definition and Kubernetes configurations on DigitalOcean. The design uses a managed load balancer and CPU-based pod scaling. I distinguish the tests I have actually run from the cloud checks still pending.

After deployment, replace the last sentence with your measured results. Do not describe pending steps as completed.

## Demonstration sequence (8-10 minutes)

1. State customer goals: growth, response time, availability and cost control.
2. Show the architecture and explain image, container, pod, node and Service.
3. Open the application and show the serving instance.
4. Show two ready replicas and their node placement.
5. Explain requests, limits, readiness and liveness probes.
6. Show the HPA target and start the bounded authorized load test.
7. Show the captured replica timeline and measured latency/error results.
8. Explain the recovery test and its limitations.
9. Compare cost scenarios and explain why pods do not directly determine the bill.
10. Finish with customer recommendations and the next decision needed.

## Questions to rehearse

Q: Why did you choose Node.js without dependencies?
A: The assignment allows a simple application. This keeps the packaging easy to inspect and focuses the demonstration on deployment, reliability and customer outcomes. Node and the base image still require patching and vulnerability review.

Q: What does the 60% HPA target mean?
A: It is average CPU utilization relative to the container CPU request. With a 100m request, 60% is approximately 60m per pod, not 60% of a worker server.

Q: Why might six pods still be slow?
A: CPU throttling, insufficient resource requests, network distance, the load generator, or downstream services may dominate. Inspect p95 latency, errors and pod CPU together before changing limits.

Q: Will adding replicas save money?
A: Adding replicas increases application capacity. Lowering replicas frees worker capacity. Worker charges decline only when billed infrastructure is removed or sized down.

Q: What happens when a node fails?
A: Surviving replicas can continue serving. Kubernetes can replace missing pods after failure detection if capacity is available. We need a distinct node failure test before claiming a recovery time.

Q: Why soft topology spreading?
A: It favors separate worker placement but allows fallback when only one worker is available. I verify placement and explain the availability tradeoff. Strict spreading could leave replacement pods pending in some failure conditions.

Q: Does a disruption budget guarantee availability?
A: It constrains supported voluntary evictions. It does not protect against every failure, direct pod deletion or a region outage.

Q: What would you add for production?
A: HTTPS, operational alerts, least-privilege access, image scanning, controlled delivery and workload-specific recovery planning. I would agree business targets before proposing more infrastructure.

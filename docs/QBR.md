# Customer review: scalable application foundation

Prepared for the assessment scenario by Krishna Aenikapati. Review date: 23 October 2026. Status: implementation package prepared; cloud validation pending. This is a pre-deployment review draft, not a claim of completed customer production work.

## Page 1: customer objectives and current position

The customer needs to onboard more users while maintaining responsive service, minimizing disruption and avoiding unused infrastructure. The proposed foundation is a stateless Node.js application on DigitalOcean Kubernetes with a public regional HTTP load balancer, two baseline application replicas and CPU-based horizontal scaling up to six pods.

Two worker nodes provide separate placement opportunities. Soft topology spreading favors distinct hosts without blocking emergency scheduling. Health probes remove unready pods from service and restart unhealthy containers. Rolling updates retain available replicas when sufficient capacity exists. A disruption budget preserves one available replica during supported voluntary evictions. These controls reduce specific failure risks but do not establish a contractual availability level or regional disaster recovery.

### Evidence available

Six automated local tests passed: homepage, health/readiness, instance identity, unauthorized load rejection, authorized CPU work, and invalid request handling. A short local HTTP smoke test is included in the evidence folder. Container build, live DOKS deployment, external load balancing, HPA scale-up/down and recovery measurements remain pending.

### Customer acceptance measures

Record the deployed image, cluster version and node plan. Capture the public endpoint, two ready replicas and placement on separate workers. Run the fixed-duration load test and record p95 response time, successful requests per second, failures and replica counts. Observe scale-down after load ends. Delete one pod while issuing requests and record replacement time and any interruption. Agree workload-specific latency and availability targets with the customer before assigning a pass/fail threshold.

### Cost position

Use the actual account quote for final analysis. Under example assumptions of $24 per worker per month and $12 for the load balancer, two workers cost $60/month before optional services, usage overages and taxes. Three fixed workers cost $84/month. Keeping a third worker for 40 of 730 modeled hours gives approximately $61.32/month. The $22.68 difference is modeled capacity savings relative to three fixed workers, not observed savings. Pod scaling alone does not reduce billed worker count.

## Page 2: recommendations, risks and ownership

### Recommendations

First, complete the cloud validation and review evidence with the customer. Choose resource requests and maximum replicas from measured throughput and latency. If scheduling pressure appears, enable bounded node autoscaling with a minimum of two and maximum of three workers. After the lab, remove the CPU test endpoint or keep it behind an authenticated testing boundary.

Before production, introduce HTTPS and a domain, monitoring and actionable alerts, image scanning and digest pinning, least-privilege access, and a documented rollout and rollback procedure. Assess database backup and resilience needs if a stateful service is added. Decide whether regional recovery is justified by the customer's recovery objectives and budget.

### Risks and mitigations

| Risk | Customer impact | Mitigation |
|---|---|---|
| Burst arrives before scaling completes | Temporary latency or errors | Maintain baseline capacity and test expected bursts |
| Metrics unavailable | HPA cannot make normal CPU scaling decisions | Alert on missing metrics and monitor HPA conditions |
| Resource limit too low | Throttling or memory restarts | Right-size against measurements and review trends |
| Region outage | Application unavailable | Agree recovery objectives and evaluate a second region |
| Unused resources remain | Continued charges | Assign cleanup ownership and review resource inventory |
| HTTP demonstration | Unencrypted requests and test token | Use synthetic data, short lab duration and HTTPS before production |

### Action plan

The assessment owner completes account access and deployment first. The engineering owner collects load, recovery and cost evidence immediately after deployment. The customer service owner reviews the results against agreed business targets. Before production approval, the security and operations owners complete HTTPS, monitoring and access controls. Each action needs a named owner and calendar date in the final customer version.

### Decision requested

Confirm the expected peak workload, target response time, acceptable recovery time, monthly cost envelope and whether the application must survive a region outage. These inputs determine the final capacity and resilience design.

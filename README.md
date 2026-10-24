# DigitalOcean TAM assessment

Prepared for Krishna Aenikapati. This repository contains a small Node.js web application, Docker packaging, Kubernetes manifests, deployment and test scripts, a customer setup guide, and a QBR draft.

## Current completion status

Application endpoint tests and a short local HTTP test were executed successfully in the authoring environment. Docker is not installed there, so the image build was not executed. No DigitalOcean resources were created. DOKS deployment, external load balancing, HPA behavior, node recovery and cloud performance remain unverified. GitHub publication requires a new dedicated repository. The local measurements are not cloud performance results.

## Project map

| Path | Purpose |
|---|---|
| app/server.mjs | Dependency-free Node.js HTTP application |
| app/index.html | Customer-facing demo page |
| Dockerfile | Non-root container image |
| k8s/ | Namespace, Deployment, Service, HPA and disruption budget |
| scripts/deploy.sh | Build image, push it and deploy into an existing DOKS cluster |
| scripts/collect-evidence.sh | Run HTTP tests and capture scaling observations |
| scripts/load_test.py | Bounded HTTP load generator with latency/error reporting |
| scripts/cost.py | Cost comparison using rates supplied by the operator |
| tests/app.test.mjs | Automated endpoint and authorization tests |
| docs/SETUP_GUIDE.md | Beginner-level deployment walkthrough |
| docs/QBR.md | Two-page review content with live results pending |
| docs/INTERVIEW.md | Presentation narrative and questions |
| docs/architecture.svg | Architecture illustration |
| evidence/ | Local verification and clearly labeled scenario estimates |

## Quick local start

Install Node.js 24 LTS, then run these commands from this directory:

```bash
node --test tests/app.test.mjs
node app/server.mjs
```

Open http://localhost:8080. Stop the server with Ctrl+C. The CPU test endpoint is disabled unless LOAD_TEST_TOKEN is set. There are no npm dependencies to install.

## Cloud deployment overview

Follow docs/SETUP_GUIDE.md for account setup, exact prerequisites and checks. These commands create billable infrastructure and must run only in the dedicated assessment account/project.

```bash
doctl auth init
docker login
export DOCKERHUB_USER=YOUR_DOCKERHUB_USERNAME
export TAM_CLUSTER_NAME=tam-demo-cluster
```

Create a public Docker Hub repository named tam-demo. Create a DOKS cluster with two AMD64 worker nodes, then run:

```bash
bash scripts/deploy.sh
kubectl get service tam-demo -n tam-demo -w
```

Ensure Metrics Server is installed. Verify `kubectl top nodes`. HPA cannot work without resource metrics.

```bash
export APP_URL=http://YOUR_EXTERNAL_IP
export TAM_EXPECTED_CONTEXT="$(kubectl config current-context)"
bash scripts/collect-evidence.sh
```

Before setting TAM_EXPECTED_CONTEXT, verify that the current context names your assignment cluster. Open a second terminal and watch `kubectl get hpa,pods -n tam-demo -w`.

## Architecture and design

The browser reaches a DigitalOcean regional HTTP Load Balancer. A Kubernetes Service selects application pods by label. The Deployment uses a soft hostname topology-spread constraint to distribute replicas while allowing emergency placement if one worker is unavailable. Verify actual placement with `kubectl get pods -o wide`.

HPA maintains 2-6 pods with a 60% CPU utilization target against a 100m CPU request. Each pod has a 500m CPU limit, 128Mi memory request and 256Mi memory limit. A five-minute scale-down stabilization window reduces oscillation. Replicas are intentionally absent from the Deployment manifest so subsequent applies do not overwrite HPA's replica decision. HPA will raise the initial count to at least two once its controller reconciles. Verify two ready replicas before testing.

Startup, readiness and liveness probes use dedicated health paths. A rolling update allows one surge pod and zero unavailable pods. It still needs spare capacity. The disruption budget retains at least one available pod during supported voluntary evictions. It does not prevent abrupt node failure or direct pod deletion. Minimum two replicas is a design choice, not an uptime guarantee.

Node autoscaling is optional: min 2, max 3. It reacts to unschedulable pods, not directly to high node CPU. Six small pods may fit on two workers, so HPA activity does not guarantee a third node.

## Security and production limits

The image runs without root, drops Linux capabilities and uses a read-only root filesystem. The server uses only Node built-ins. The base image tag is a maintenance dependency: scan it and record/pin the tested digest for stronger reproducibility.

The /work endpoint requires a generated Kubernetes Secret token and caps active work at 32 requests per pod. No token is stored in this repository or test output. HTTP is a lab-only choice: the load-test token travels without transport encryption in this demo. Run a brief isolated test, then delete the demo or enable HTTPS before any broader use. Do not send real customer data. A Kubernetes Secret is not a substitute for full secret management and RBAC.

This stateless demonstration has no database or business authentication. The web server is sufficient for this bounded lab, not a complete production platform. Production work includes HTTPS, authentication, network controls, image vulnerability checks, alerting, capacity planning, and a region-failure strategy appropriate to the business.

## Results and evidence

Local results are in evidence/local-validation.txt and evidence/local-smoke.json. Cloud measurements must be generated after deployment. Never relabel the local benchmark as DOKS throughput. Generated cloud evidence folders are gitignored by default so operators can review them before publication. Copy sanitized, selected results into docs/cloud-results after inspection.

The load test reports client round-trip latency, successful throughput, all-response throughput and error counts. It uses a new HTTP connection per request. Percentiles include failures, so examine status counts. Network distance and load-generator capacity affect results. Home-page results and /work results are different workloads and should not be compared as if they were the same endpoint.

## Costs

Use verified account rates. Example only:

```bash
python3 scripts/cost.py --node-monthly 24 --lb-monthly 12 --extra-node-hours 40
```

This produces a $60 baseline and an illustrative burst scenario. It does not prove realized savings. HPA alone does not reduce worker-node charges. The monthly-rate/hour conversion is an approximation, not invoice logic. Account for control-plane options, registry, storage, transfer and tax separately.

## Cleanup

Save evidence first and confirm the assessor no longer needs the URL. Verify the cluster context. Delete the service before deleting the cluster so its managed load balancer can be removed cleanly:

```bash
kubectl delete service tam-demo -n tam-demo
```

Wait and confirm the matching load balancer disappears from DigitalOcean Networking. Then:

```bash
kubectl delete namespace tam-demo
```

Delete only the dedicated assignment cluster in the DigitalOcean console, and check for leftover billable resources. Stopping pods alone does not stop worker charges.

## References

- https://docs.digitalocean.com/products/kubernetes/how-to/create-clusters/
- https://docs.digitalocean.com/products/kubernetes/how-to/connect-to-cluster/
- https://docs.digitalocean.com/products/kubernetes/how-to/configure-load-balancers/
- https://docs.digitalocean.com/products/kubernetes/how-to/set-up-autoscaling/
- https://docs.digitalocean.com/products/kubernetes/how-to/autoscale/
- https://www.digitalocean.com/pricing/load-balancers
- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/

Sources checked during preparation on 23 October 2026. The console quote and supported versions at deployment time control the actual configuration and cost.

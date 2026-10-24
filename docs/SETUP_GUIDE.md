# Beginner setup guide

## 1. What you will build

A web application runs in a Docker container. Kubernetes starts multiple copies called pods. Worker nodes are the servers hosting the pods. A public load balancer sends requests into the cluster. HPA watches CPU usage and changes pod count. Metrics Server supplies CPU observations. A registry stores your application image. kubectl is the command you use to manage Kubernetes, while doctl authenticates to DigitalOcean.

Use a laptop or desktop. The commands assume Bash on macOS, Linux, or Ubuntu in Windows WSL2. On Windows, install Docker Desktop with WSL integration and run all commands from the same Ubuntu terminal. You do not need to edit the application code to complete this walkthrough.

## 2. Install the tools

1. Install Docker Desktop from https://docs.docker.com/desktop/ and open it. Wait for the engine to start. On Linux, an official Docker Engine installation is also suitable.
2. Install Node.js 24 LTS from https://nodejs.org/. This runs the local app and tests.
3. Install kubectl from https://kubernetes.io/docs/tasks/tools/. Select the instructions for your operating system. Use a version compatible with the selected cluster.
4. Install doctl from https://docs.digitalocean.com/reference/doctl/how-to/install/.
5. Install Python 3 from https://www.python.org/downloads/. No Python packages are needed for the provided deployment/test scripts.
6. Install Git from https://git-scm.com/downloads and an editor such as VS Code from https://code.visualstudio.com/.
7. Open a new terminal after installation.
8. Run each command below. A version should appear. `docker info` should connect to the engine.

```bash
node --version
python3 --version
docker --version
docker info
kubectl version --client
doctl version
git --version
```

If a command is missing, finish that installation before proceeding. These tools run on your computer. The Kubernetes servers will run in DigitalOcean.

## 3. Unzip and open the project

Download TAM_Assessment_Package.zip. Extract it. Open the tam-doks-demo folder in your editor. Open a terminal inside that folder. Run `pwd` and `ls` to verify you see Dockerfile, package.json, app, k8s and scripts. All later commands assume this directory.

```bash
node --test tests/app.test.mjs
node app/server.mjs
```

Open http://localhost:8080 in your browser. Click Refresh response. You should see an instance name and response time. Local response time is not cloud performance. Return to the terminal and press Ctrl+C to stop the server.

## 4. Check Docker locally

```bash
docker build -t tam-demo:local .
docker run --rm -p 8080:8080 --name tam-demo tam-demo:local
```

Open http://localhost:8080 again. Open http://localhost:8080/healthz and expect status ok. Press Ctrl+C to stop the container. If port 8080 is occupied, stop the earlier server before retrying. The app intentionally has no database and no login screen.

## 5. Prepare DigitalOcean and Docker Hub

1. Sign into DigitalOcean and confirm the assessment credits with the recruiter or account billing page.
2. Create a project for this assessment, keeping it separate from customer systems.
3. In Docker Hub, create a public repository named tam-demo. The project contains demonstration code only.
4. Run `docker login` and complete its secure authentication process.
5. In DigitalOcean, open API and create/use a token with the permissions needed for the intended cluster operations. Keep it private and follow the account's access policy.
6. Run `doctl auth init` and supply the token privately at the prompt. Do not put it in code or screenshots.
7. Run `doctl account get` to confirm which account you are using. Do not publish account output in your evidence.

## 6. Create the cluster in the console

1. Open Kubernetes and select Create Kubernetes Cluster.
2. Choose one region near the expected customer population. For this demo, NYC1 is a reasonable example if available.
3. Choose a currently supported Kubernetes version.
4. Choose an AMD64 basic worker node type around 2 vCPU and 4 GiB RAM. Note the exact hourly/monthly price shown.
5. Set the worker count to two.
6. Name the cluster tam-demo-cluster.
7. Check the estimated recurring cost and available credits, then create the cluster.
8. Wait until both workers are Ready. Optional HA control-plane charges must be included if you select that option.
9. Keep the lab in one region and describe regional recovery as future work.

Alternative CLI creation, only after verifying size and region availability:

```bash
doctl kubernetes options regions
doctl kubernetes options sizes
```

The GUI route above is sufficient. Do not create a second cluster accidentally by repeating a creation command.

## 7. Deploy using the supplied script

Replace the Docker Hub username below with your own. Keep the cluster name aligned with the cluster you just created.

```bash
export DOCKERHUB_USER=YOUR_DOCKERHUB_USERNAME
export TAM_CLUSTER_NAME=tam-demo-cluster
bash scripts/deploy.sh
```

The script connects kubectl to the named cluster, builds and pushes an AMD64 image, creates the namespace and private load-test token, applies the Deployment, HPA, disruption budget and Service, and waits for rollout. It prints the target context before changes. Read that line to ensure you are targeting the assignment cluster.

The deployment script does not create a cluster. If the name is wrong, it stops when doctl fails. If Docker push fails, verify the repository and login. The Docker Hub repository must be public for this version of the manifests. Private repositories require an image pull secret.

```bash
kubectl get pods -n tam-demo -o wide
kubectl get service tam-demo -n tam-demo -w
```

Wait until there is an EXTERNAL-IP, then press Ctrl+C. Open http://EXTERNAL-IP. The Service creates the DigitalOcean load balancer. Do not create another load balancer manually. The explicit REGIONAL annotation selects the HTTP load balancer type.

## 8. Enable CPU metrics

Run `kubectl top nodes`. If CPU and memory values appear, metrics already work. Otherwise, open the cluster's Marketplace/1-Click Apps page, select Kubernetes Metrics Server, and install it. Wait a few minutes and retry.

```bash
kubectl top nodes
kubectl top pods -n tam-demo
kubectl get hpa -n tam-demo
```

A CPU target such as 5%/60% indicates current average usage and target. A persistent unknown value requires investigation. Check `kubectl describe hpa tam-demo -n tam-demo`. HPA uses CPU requests, so 60% of 100m means approximately 60m per pod. Wait for at least two ready pods before testing.

## 9. Capture live results

Get the external IP from the Service and set the URL. Confirm the current context is your assignment cluster before saving it as the expected context.

```bash
kubectl config current-context
export APP_URL=http://YOUR_EXTERNAL_IP
export TAM_EXPECTED_CONTEXT="$(kubectl config current-context)"
bash scripts/collect-evidence.sh
```

In a second terminal, watch:

```bash
kubectl get hpa,pods -n tam-demo -w
```

The script measures the home endpoint, then the CPU workload at low concurrency, then applies 20 concurrent requests for 180 seconds while capturing HPA, pod count and CPU snapshots. Outputs go to a timestamped evidence/cloud-* directory. The script never prints the token. Stop a test with Ctrl+C if it causes unexpected effects.

Record pod count before, peak pod count, time to first new ready replica, throughput, p95 latency, error counts and load-generator location. After load stops, watch for 5-10 minutes and record the time to return to two pods. Scale-down is not instantaneous. Do not claim node autoscaling if node count never changed.

## 10. Test recovery and updates

Run continuous requests from one terminal while replacing a single pod. Use the actual pod name from `kubectl get pods`.

```bash
for i in {1..60}; do
  curl --max-time 5 -sS -o /dev/null -w '%{http_code}\n' "$APP_URL/"
  sleep 1
done
```

From another terminal:

```bash
kubectl get pods -n tam-demo
kubectl delete pod ACTUAL_POD_NAME -n tam-demo
kubectl get pods -n tam-demo -w
```

Record errors and recovery time. This tests pod replacement, not a full node outage. A disruption budget does not protect against direct pod deletion. For an update demonstration, make a visible text change, rerun the deployment script, and observe rollout. If a new version fails, run `kubectl rollout undo deployment/tam-demo -n tam-demo`, then verify `kubectl rollout status`. Preserve evidence from both versions.

## 11. Optional node autoscaling

Open Kubernetes, select the cluster, then Resources. On the node pool menu choose Resize or Autoscale. Set Autoscale, minimum two nodes and maximum three. It adds capacity when pods cannot be scheduled and may remove unnecessary nodes when safe. Six small application pods can fit on the existing workers, so this test may not trigger a new server. Verify actual scheduling and node events before making any claim.

## 12. Cost analysis

Record the exact node plan and load balancer rates from the account. Use the cost script with those values. Example assumptions only:

```bash
python3 scripts/cost.py --node-monthly 24 --lb-monthly 12 --extra-node-hours 40
```

The example produces a two-worker baseline of $60/month and a three-worker fixed scenario of $84/month. Keeping the third worker for only 40 of an assumed 730 hours gives about $61.32/month, a modeled difference of $22.68. This is a scenario, not measured savings. Include all other charges. A fixed two-node cluster costs the same at two and six pods.

## 13. Publish and submit

Create a dedicated GitHub repository named tam-doks-demo. Use public visibility only if the assessment permits it. Initialize an empty repository, then run the following from the project directory after reviewing the files:

```bash
git init
git add .
git commit -m "Add DigitalOcean TAM assessment"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/tam-doks-demo.git
git push -u origin main
```

Use secure GitHub authentication. Do not commit tokens, kubeconfig or unreviewed logs. Add reviewed cloud results, update the QBR and cost figures, and regenerate the PDF if the results change. Submit the actual repository URL and final PDF to the assessor. Do not submit the initial package as if deployment had already occurred.

## 14. Troubleshooting

| Symptom | Action |
|---|---|
| Docker daemon unavailable | Open Docker Desktop, wait for engine readiness, rerun docker info |
| ImagePullBackOff | Verify public repository, correct tag and pull events in kubectl describe pod |
| Exec format error | Build the image for linux/amd64 to match the chosen workers |
| HPA target unknown | Install Metrics Server, wait, confirm CPU requests and inspect HPA conditions |
| Pods Pending | Describe the pod, inspect resources, quota and node capacity |
| EXTERNAL-IP pending | Inspect Service events and DigitalOcean quota/provisioning status |
| HTTP 403 on /work | Use collect-evidence.sh so it retrieves the authorized test token |
| HTTP 429 during testing | Per-pod work cap reached; inspect errors and reduce concurrency |
| No scale-up | Verify /work requests succeed, CPU rises and the test runs long enough |
| No scale-down yet | Allow the five-minute stabilization window and inspect HPA events |
| Missing second worker placement | Check pods -o wide and topology constraints; soft spreading allows fallback |

## 15. Cleanup

Save and review evidence, then confirm that the assessor no longer needs a live URL. Verify kubectl's context. Delete the Service, wait for the managed load balancer to disappear, then delete the namespace. Finally delete only the assignment cluster in the DigitalOcean console and inspect for leftover volumes or load balancers. Stop paying for the infrastructure, not just the pods.

```bash
kubectl delete service tam-demo -n tam-demo
kubectl delete namespace tam-demo
```

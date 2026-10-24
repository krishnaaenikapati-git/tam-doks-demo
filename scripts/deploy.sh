#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DOCKERHUB_USER:?Set DOCKERHUB_USER to your Docker Hub username}"
: "${TAM_CLUSTER_NAME:?Set TAM_CLUSTER_NAME to your dedicated assignment cluster name}"
for tool in docker doctl kubectl python3; do command -v "$tool" >/dev/null || { echo "Install $tool first"; exit 1; }; done
# Cluster creation is a separate, explicit step in the guide.
doctl kubernetes cluster kubeconfig save "$TAM_CLUSTER_NAME"
echo "Target context: $(kubectl config current-context)"
kubectl get nodes
TAM_TAG="$(date -u +%Y%m%d%H%M%S)"
TAM_IMAGE="${DOCKERHUB_USER}/tam-demo:${TAM_TAG}"
docker buildx build --platform linux/amd64 -t "$TAM_IMAGE" --push .
kubectl apply -f k8s/namespace.yaml
if ! kubectl get secret load-test -n tam-demo >/dev/null 2>&1; then
  python3 - <<'PYTOKEN' | kubectl create -f -
import json,secrets,base64
print(json.dumps({'apiVersion':'v1','kind':'Secret','metadata':{'name':'load-test','namespace':'tam-demo'},'type':'Opaque','data':{'token':base64.b64encode(secrets.token_urlsafe(32).encode()).decode()}}))
PYTOKEN
fi
TAM_RENDERED="$(mktemp)"
trap 'rm -f "$TAM_RENDERED"' EXIT
python3 - "$TAM_IMAGE" > "$TAM_RENDERED" <<'PYRENDER'
import pathlib,sys
print(pathlib.Path('k8s/deployment.yaml').read_text().replace('TAM_IMAGE_PLACEHOLDER',sys.argv[1]))
PYRENDER
kubectl apply -f "$TAM_RENDERED"
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/pdb.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/tam-demo -n tam-demo --timeout=300s
mkdir -p evidence
printf '%s\n' "$TAM_IMAGE" > evidence/deployed-image.txt
kubectl get pods,service,hpa -n tam-demo -o wide
echo 'Wait for an EXTERNAL-IP, then open http://EXTERNAL-IP. Check kubectl top nodes.'

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${APP_URL:?Set APP_URL to the load balancer URL}"
: "${TAM_EXPECTED_CONTEXT:?Set TAM_EXPECTED_CONTEXT to the assignment kubectl context}"
[[ "$(kubectl config current-context)" == "$TAM_EXPECTED_CONTEXT" ]] || { echo 'Wrong cluster context'; exit 1; }
OUT="evidence/cloud-$(date -u +%Y%m%d%H%M%S)"
mkdir -p "$OUT"
kubectl get nodes -o wide > "$OUT/nodes.txt"
kubectl get pods -n tam-demo -o wide > "$OUT/pods-before.txt"
kubectl get hpa -n tam-demo > "$OUT/hpa-before.txt"
kubectl get service -n tam-demo -o wide > "$OUT/service.txt"
kubectl top nodes > "$OUT/node-metrics.txt"
python3 scripts/load_test.py --url "$APP_URL/" --duration 30 --concurrency 2 --output "$OUT/home-baseline.json"
export LOAD_TEST_TOKEN="$(kubectl get secret load-test -n tam-demo -o jsonpath='{.data.token}' | python3 -c 'import base64,sys;print(base64.b64decode(sys.stdin.read()).decode())')"
python3 scripts/load_test.py --url "$APP_URL/work" --duration 30 --concurrency 2 --output "$OUT/work-baseline.json"
python3 scripts/load_test.py --url "$APP_URL/work" --duration 180 --concurrency 20 --output "$OUT/work-load.json" &
TAM_LOAD_PID=$!
trap 'kill "$TAM_LOAD_PID" 2>/dev/null || true; unset LOAD_TEST_TOKEN' EXIT
while kill -0 "$TAM_LOAD_PID" 2>/dev/null; do
 { date -u; kubectl get hpa,pods -n tam-demo; kubectl top pods -n tam-demo; } >> "$OUT/scaling-timeline.txt" 2>&1
 sleep 10
done
wait "$TAM_LOAD_PID"
unset LOAD_TEST_TOKEN
kubectl describe hpa tam-demo -n tam-demo > "$OUT/hpa-details.txt"
kubectl get events -n tam-demo --sort-by=.metadata.creationTimestamp > "$OUT/events.txt"
kubectl get pods -n tam-demo -o wide > "$OUT/pods-after.txt"
echo "Evidence saved to $OUT. Watch scale-down separately for 5-10 minutes."

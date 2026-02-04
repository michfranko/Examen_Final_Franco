#!/usr/bin/env bash
set -euo pipefail

OUTDIR="evidence"
mkdir -p "$OUTDIR"

kubectl get pvc -o wide > "$OUTDIR/pvc.txt"
kubectl get pods -o wide > "$OUTDIR/pods.txt"
kubectl get svc -o wide > "$OUTDIR/svc.txt"

kubectl logs -l app=producer --tail=200 > "$OUTDIR/producer_logs.txt" || true
kubectl logs -l app=redis-commander --tail=200 > "$OUTDIR/redis_commander_logs.txt" || true

REDIS_POD=$(kubectl get pods -l app=redis -o jsonpath='{.items[0].metadata.name}') || true
if [ -n "$REDIS_POD" ]; then
  REDIS_PASS=$(kubectl get secret redis-secret -o jsonpath='{.data.redis-password}' | base64 --decode)
  kubectl exec -i "$REDIS_POD" -- redis-cli -a "$REDIS_PASS" LRANGE sensors 0 -1 > "$OUTDIR/redis_sensors_before.txt" || true
else
  echo "Redis pod not found" > "$OUTDIR/redis_sensors_before.txt"
fi

echo "Evidence collected in $OUTDIR"

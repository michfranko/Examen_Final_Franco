# PowerShell script to collect evidence from a Kubernetes cluster
# Usage: Open PowerShell, navigate to repo root, run: .\k8s\scripts\collect_evidence.ps1

$outDir = "evidence"
if (-Not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# Save PVC status
kubectl get pvc -o wide | Out-File "$outDir\pvc.txt"

# Save pods
kubectl get pods -o wide | Out-File "$outDir\pods.txt"

# Save services
kubectl get svc -o wide | Out-File "$outDir\svc.txt"

# Save logs for producer and redis-commander
kubectl logs -l app=producer --tail=200 > "$outDir\producer_logs.txt"
kubectl logs -l app=redis-commander --tail=200 > "$outDir\redis_commander_logs.txt"

# Get Redis pod name
$redisPod = kubectl get pods -l app=redis -o jsonpath='{.items[0].metadata.name}'
if ($redisPod) {
    kubectl exec -it $redisPod -- redis-cli -a (kubectl get secret redis-secret -o jsonpath="{.data.redis-password}" | base64 --decode) LRANGE sensors 0 -1 | Out-File "$outDir\redis_sensors_before.txt"
} else {
    Write-Host "Redis pod not found."
}

Write-Host "Evidence collected in $outDir"

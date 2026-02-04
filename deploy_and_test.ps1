# Script PowerShell para desplegar y probar el sistema de monitoreo en Kubernetes (Minikube)
# Automatiza: construccion de imagenes, aplicacion de manifiestos, recoleccion de evidencias y prueba de resiliencia

$ErrorActionPreference = "Continue"
$logDir = "$(Get-Location)/evidence"

# Crear directorio para evidencias
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

Write-Host "=== SCRIPT DE DESPLIEGUE Y PRUEBA ===" -ForegroundColor Cyan
Write-Host "Destino: Minikube + Kubernetes" -ForegroundColor Yellow
Write-Host "Directorio de evidencias: $logDir" -ForegroundColor Yellow

# ============================================
# 0. VERIFICAR Y CONSTRUIR IMÁGENES DOCKER
# ============================================
Write-Host "`n[0/8] Verificando imagenes Docker..." -ForegroundColor Green

# Función para verificar si Docker está corriendo
function Test-DockerRunning {
    try {
        docker ps > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}

if (-not (Test-DockerRunning)) {
    Write-Host "[ERROR] Docker no esta corriendo." -ForegroundColor Red
    Write-Host "Asegurate de que Docker Desktop esta iniciado." -ForegroundColor Yellow
    exit 1
}

# Verificar si existe la imagen del productor
$producerImage = docker images -q examen-productor:1.0 2>&1
if (-not $producerImage -or $producerImage -match "No such image") {
    Write-Host "  Construyendo imagen: examen-productor:1.0..." -ForegroundColor Yellow
    docker build -t examen-productor:1.0 -f producer/Dockerfile ./producer 2>&1 | Tee-Object -FilePath "$logDir/00_docker_build.txt"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] al construir imagen del productor" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Imagen construida" -ForegroundColor Green
} else {
    Write-Host "[OK] Imagen examen-productor:1.0 ya existe" -ForegroundColor Green
}

# ============================================
# 1. VERIFICAR CONEXION A KUBERNETES
# ============================================
Write-Host "`n[1/8] Verificando conexion a Kubernetes..." -ForegroundColor Green
kubectl cluster-info 2>&1 | Tee-Object -FilePath "$logDir/01_cluster_info.txt" | Select-Object -First 10
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] No se puede conectar a Kubernetes." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Kubernetes accesible" -ForegroundColor Green

# ============================================
# 2. APLICAR MANIFIESTOS
# ============================================
Write-Host "`n[2/8] Aplicando manifiestos Kubernetes..." -ForegroundColor Green
$files = @(
    "k8s/secret.yaml",
    "k8s/redis-statefulset.yaml",
    "k8s/redis-headless-svc.yaml",
    "k8s/redis-cluster-svc.yaml",
    "k8s/producer-deployment.yaml",
    "k8s/redis-commander-deployment.yaml"
)

foreach ($file in $files) {
    Write-Host "  - Aplicando $file..." -ForegroundColor White
    kubectl apply -f $file 2>&1 | Tee-Object -FilePath "$logDir/02_apply_$($file -replace '/', '_').txt"
}

# ============================================
# 3. ESPERAR A QUE LOS PODS ESTEN LISTOS
# ============================================
Write-Host "`n[3/8] Esperando a que los pods esten listos..." -ForegroundColor Green
$maxWait = 120
$elapsed = 0
$podReady = $false

while ($elapsed -lt $maxWait) {
    $redisReady = kubectl get pod -l app=redis -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>&1
    $producerReady = kubectl get pod -l app=producer -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>&1
    $commanderReady = kubectl get pod -l app=redis-commander -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>&1

    if ($redisReady -eq "True" -and $producerReady -eq "True" -and $commanderReady -eq "True") {
        $podReady = $true
        break
    }

    Write-Host "  Esperando... (Redis: $redisReady, Producer: $producerReady, Commander: $commanderReady)" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    $elapsed += 10
}

if (-not $podReady) {
    Write-Host "  [ADVERTENCIA] Timeout esperando pods. Continuando de todas formas..." -ForegroundColor Yellow
}

Write-Host "[OK] Pods estado actual:" -ForegroundColor Green
kubectl get pods -o wide | Tee-Object -FilePath "$logDir/03_pods_initial.txt"

# ============================================
# 4. VERIFICAR PVC BOUND
# ============================================
Write-Host "`n[4/8] Verificando PersistentVolumeClaim (debe estar Bound)..." -ForegroundColor Green
kubectl get pvc | Tee-Object -FilePath "$logDir/04_pvc_bound.txt"
$pvcStatus = kubectl get pvc -o jsonpath='{.items[0].status.phase}'
if ($pvcStatus -eq "Bound") {
    Write-Host "[OK] PVC esta Bound" -ForegroundColor Green
} else {
    Write-Host "[ADVERTENCIA] PVC esta en estado: $pvcStatus" -ForegroundColor Yellow
}

# ============================================
# 5. RECOLECTAR LOGS DEL PRODUCTOR
# ============================================
Write-Host "`n[5/8] Recolectando logs del productor..." -ForegroundColor Green
Start-Sleep -Seconds 5
kubectl logs deployment/producer --tail=50 2>&1 | Tee-Object -FilePath "$logDir/05_producer_logs.txt"

# ============================================
# 6. VERIFICAR DATOS EN REDIS
# ============================================
Write-Host "`n[6/8] Verificando datos en Redis (port-forward temporal)..." -ForegroundColor Green
$portForwardProc = Start-Process kubectl -ArgumentList "port-forward svc/redis-cluster 6379:6379" -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 2

# Intentar conectar con redis-cli si esta disponible
$redisCli = Get-Command redis-cli -ErrorAction SilentlyContinue
if ($redisCli) {
    Write-Host "  Redis-CLI encontrado, consultando datos..." -ForegroundColor White
    redis-cli -h 127.0.0.1 -p 6379 -a "SuperS3cret123!" LRANGE sensors 0 -10 2>&1 | Tee-Object -FilePath "$logDir/06_redis_data.txt"
} else {
    Write-Host "  [ADVERTENCIA] redis-cli no disponible localmente. Saltando verificacion directa." -ForegroundColor Yellow
    Write-Host "  Puedes verificar en Redis Commander en http://localhost:8081" -ForegroundColor White
}

# Detener port-forward
Stop-Process -Id $portForwardProc.Id -ErrorAction SilentlyContinue

# ============================================
# 7. PRUEBA DE RESILIENCIA
# ============================================
Write-Host "`n[7/8] Iniciando prueba de resiliencia..." -ForegroundColor Cyan
Write-Host "  PASO 1: Eliminar el Pod de Redis..." -ForegroundColor White
$redisPodName = kubectl get pod -l app=redis -o jsonpath='{.items[0].metadata.name}'
Write-Host "  Pod a eliminar: $redisPodName" -ForegroundColor Yellow
kubectl delete pod $redisPodName 2>&1 | Tee-Object -FilePath "$logDir/07_pod_delete.txt"

Write-Host "  PASO 2: Esperar a que Kubernetes recree el Pod..." -ForegroundColor White
$maxWaitRecreate = 60
$recreateElapsed = 0
$newPodReady = $false

while ($recreateElapsed -lt $maxWaitRecreate) {
    $newRedisPod = kubectl get pod -l app=redis -o jsonpath='{.items[0].metadata.name}' 2>&1
    $status = kubectl get pod $newRedisPod -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>&1

    if ($status -eq "True" -and $newRedisPod -ne $redisPodName) {
        $newPodReady = $true
        Write-Host "  [OK] Nuevo Pod creado y listo: $newRedisPod" -ForegroundColor Green
        break
    }

    Write-Host "  Esperando recreacion... Estado: $status" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    $recreateElapsed += 5
}

if (-not $newPodReady) {
    Write-Host "  [ADVERTENCIA] El Pod aun no esta totalmente listo, pero continuamos." -ForegroundColor Yellow
}

Write-Host "  PASO 3: Verificar que PVC sigue Bound y datos persisten..." -ForegroundColor White
kubectl get pvc | Tee-Object -FilePath "$logDir/08_pvc_after_recovery.txt"

Start-Sleep -Seconds 3

$portForwardProc = Start-Process kubectl -ArgumentList "port-forward svc/redis-cluster 6379:6379" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2

if ($redisCli) {
    Write-Host "  Consultando datos tras recuperacion..." -ForegroundColor White
    redis-cli -h 127.0.0.1 -p 6379 -a "SuperS3cret123!" LRANGE sensors 0 -10 2>&1 | Tee-Object -FilePath "$logDir/09_redis_data_after_recovery.txt"
}

Stop-Process -Id $portForwardProc.Id -ErrorAction SilentlyContinue

# ============================================
# 8. RESUMEN FINAL
# ============================================
Write-Host "`n[8/8] Resumen Final" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[OK] DESPLIEGUE Y PRUEBAS COMPLETADOS" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nEvidencias guardadas en: $logDir" -ForegroundColor Yellow
Get-ChildItem $logDir | Format-Table Name, Length

Write-Host "`nACCIONES MANUALES REQUERIDAS:" -ForegroundColor Cyan
Write-Host "  1. Abre Redis Commander en tu navegador:" -ForegroundColor White
Write-Host "     http://localhost:8081" -ForegroundColor Cyan
Write-Host "     (Si no funciona, ejecuta: kubectl port-forward svc/redis-commander 8081:8081)" -ForegroundColor White

Write-Host "`n  2. Verifica que ves entradas JSON con formato:" -ForegroundColor White
Write-Host '     { "sensor_id": "rbt-01", "valor": XX.XX }' -ForegroundColor Cyan

Write-Host "`n  3. Usa las capturas de pantalla como evidencia en el informe LaTeX." -ForegroundColor White

Write-Host "`nESTADO DEL SISTEMA:" -ForegroundColor Cyan
kubectl get pods --all-namespaces -o wide | Tee-Object -FilePath "$logDir/10_final_pods_state.txt" | Select-Object -First 15
kubectl get svc | Tee-Object -FilePath "$logDir/11_final_services.txt"

Write-Host "`n[OK] Script completado. Revisa los archivos en $logDir para la documentacion." -ForegroundColor Green

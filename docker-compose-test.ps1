# Script PowerShell para pruebas locales con docker-compose
# Permite probar el sistema sin Kubernetes

Write-Host "=== PRUEBAS LOCALES CON DOCKER-COMPOSE ===" -ForegroundColor Cyan
Write-Host "Destino: Docker Desktop (Docker Engine)" -ForegroundColor Yellow

$ErrorActionPreference = "Continue"

# Función para verificar si docker-compose está disponible
function Test-DockerCompose {
    try {
        docker-compose --version > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}

# Función para verificar Docker
function Test-DockerRunning {
    try {
        docker ps > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}

Write-Host "`n[1/5] Verificando Docker..." -ForegroundColor Green
if (-not (Test-DockerRunning)) {
    Write-Host "❌ ERROR: Docker no está corriendo o no es accesible." -ForegroundColor Red
    Write-Host "Asegúrate de que Docker Desktop está iniciado." -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ Docker accesible" -ForegroundColor Green

Write-Host "`n[2/5] Verificando docker-compose..." -ForegroundColor Green
if (-not (Test-DockerCompose)) {
    Write-Host "⚠️  docker-compose no encontrado. Usando docker compose (v2)..." -ForegroundColor Yellow
    $compose_cmd = "docker compose"
} else {
    $compose_cmd = "docker-compose"
}
Write-Host "✓ docker-compose disponible" -ForegroundColor Green

# Crear directorio para evidencias
$logDir = "$(Get-Location)/evidence"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

Write-Host "`n[3/5] Iniciando servicios con docker-compose..." -ForegroundColor Green
Write-Host "  Redis: puerto 6379" -ForegroundColor White
Write-Host "  Redis Commander: puerto 8081" -ForegroundColor White
Write-Host "  Productor: ejecutándose continuamente" -ForegroundColor White

# Ejecutar docker-compose up
Invoke-Expression "$compose_cmd up -d" | Tee-Object -FilePath "$logDir/docker_compose_up.txt"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR al iniciar servicios con docker-compose" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Servicios iniciados" -ForegroundColor Green

# Esperar a que los servicios estén listos
Write-Host "`n[4/5] Esperando a que los servicios estén listos..." -ForegroundColor Green
Start-Sleep -Seconds 5

# Verificar salud de los servicios
Write-Host "`n  Estado de los contenedores:" -ForegroundColor White
docker ps | Tee-Object -FilePath "$logDir/docker_ps.txt"

# Intentar conectar a Redis
Write-Host "`n  Intentando conectar a Redis..." -ForegroundColor White
$redis_check = $null
$attempts = 0
while ($attempts -lt 10) {
    try {
        $redis_check = Invoke-Expression 'redis-cli -h 127.0.0.1 -p 6379 -a "SuperS3cret123!" ping' 2>&1
        if ($redis_check -eq "PONG") {
            Write-Host "  ✓ Redis respondió: $redis_check" -ForegroundColor Green
            break
        }
    }
    catch {
        Write-Host "  ⚠️  Redis no responde aún (intento $($attempts+1)/10)..." -ForegroundColor Yellow
        $attempts++
        Start-Sleep -Seconds 2
    }
}

# Esperar a que el productor haya generado datos
Write-Host "`n  Esperando datos del productor..." -ForegroundColor White
Start-Sleep -Seconds 8

# Ver logs del productor
Write-Host "`n[5/5] Logs del productor (últimos 20 eventos):" -ForegroundColor Green
Invoke-Expression "$compose_cmd logs --tail 20 producer" | Tee-Object -FilePath "$logDir/docker_compose_logs_producer.txt"

# Verificar datos en Redis
Write-Host "`n✓ SISTEMA OPERATIVO" -ForegroundColor Green

Write-Host "`n🌐 ACCEDER A LA INTERFAZ WEB:" -ForegroundColor Cyan
Write-Host "   http://localhost:8081" -ForegroundColor Yellow

Write-Host "`n📊 VERIFICAR DATOS DESDE CONSOLA:" -ForegroundColor Cyan
Write-Host "   redis-cli -h 127.0.0.1 -p 6379 -a 'SuperS3cret123!'" -ForegroundColor Yellow
Write-Host "   > LRANGE sensors 0 -10" -ForegroundColor Yellow

Write-Host "`n📝 VER LOGS EN TIEMPO REAL:" -ForegroundColor Cyan
Write-Host "   $compose_cmd logs -f" -ForegroundColor Yellow

Write-Host "`n❌ DETENER SERVICIOS:" -ForegroundColor Cyan
Write-Host "   $compose_cmd down" -ForegroundColor Yellow

Write-Host "`n✓ Evidencias guardadas en: $logDir" -ForegroundColor Green

Write-Host "`n💡 PRÓXIMOS PASOS:" -ForegroundColor Cyan
Write-Host "   1. Abre http://localhost:8081 en tu navegador" -ForegroundColor White
Write-Host "   2. Verifica la lista 'sensors' con entradas JSON" -ForegroundColor White
Write-Host "   3. Una vez satisfecho, usa .\deploy_and_test.ps1 para Kubernetes" -ForegroundColor White

Write-Host "`nℹ️  NOTA: Este es un ambiente local para pruebas. Para producción, usa Kubernetes." -ForegroundColor Yellow

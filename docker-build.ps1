# Script PowerShell para construir las imágenes Docker necesarias
# Diseñado para Docker Desktop / Minikube

Write-Host "=== CONSTRUCCION DE IMAGENES DOCKER ===" -ForegroundColor Cyan
$ErrorActionPreference = "Stop"

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

# Verificar Docker
Write-Host "`n[1/3] Verificando Docker..." -ForegroundColor Green
if (-not (Test-DockerRunning)) {
    Write-Host "[ERROR] Docker no esta corriendo o no es accesible." -ForegroundColor Red
    Write-Host "Asegurate de que Docker Desktop esta iniciado." -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Docker accesible" -ForegroundColor Green

# Obtener versión de Docker
$dockerVersion = docker version --format '{{.Server.Version}}'
Write-Host "  Version: $dockerVersion" -ForegroundColor Yellow

# Construir imagen del Productor
Write-Host "`n[2/3] Construyendo imagen del Productor..." -ForegroundColor Green
Write-Host "  Imagen: examen-productor:1.0" -ForegroundColor White

try {
    docker build -t examen-productor:1.0 -f producer/Dockerfile ./producer
    Write-Host "[OK] Imagen Productor construida exitosamente" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] al construir imagen Productor:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Verificar Redis Commander
Write-Host "`n[3/3] Verificando Redis Commander..." -ForegroundColor Green
Write-Host "  Usando: rediscommander/redis-commander:latest (desde Docker Hub)" -ForegroundColor White

Write-Host "`n[OK] IMAGENES LISTAS:" -ForegroundColor Green
docker images | Select-String "examen-productor"

Write-Host "`nPROXIMOS PASOS:" -ForegroundColor Cyan
Write-Host "  Opcion 1: Usar docker-compose para pruebas locales" -ForegroundColor White
Write-Host "    docker-compose up -d" -ForegroundColor Cyan

Write-Host "`n  Opcion 2: Usar Kubernetes" -ForegroundColor White
Write-Host "    .\deploy_and_test.ps1" -ForegroundColor Cyan

Write-Host "`n[OK] Script completado." -ForegroundColor Green

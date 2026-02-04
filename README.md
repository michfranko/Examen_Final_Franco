# Sistema de Monitoreo en Tiempo Real para Almacenes Automatizados

## Descripción

Sistema desacoplado en Kubernetes con tres componentes:
- **Redis** (StatefulSet): persistencia con autenticación y PVC
- **Productor** (Deployment): genera datos JSON de sensores cada 3 segundos
- **Redis Commander** (Deployment): interfaz web para visualizar datos en tiempo real

## Requisitos Previos

1. **Docker Desktop** con Kubernetes habilitado
   - Abre Docker Desktop
   - Ve a Settings > Kubernetes
   - Marca "Enable Kubernetes"
   - Espera a que inicie (5-10 minutos)

2. **kubectl** instalado y configurado (debería estar auto-configurado con Docker Desktop)

3. **redis-cli** (opcional, para verificaciones manuales)
   ```powershell
   choco install redis-64  # o instalar desde https://github.com/microsoftarchive/redis/releases
   ```

## Ejecución Rápida

### Opción 1: Usar el Script Automatizado (Recomendado)

```powershell
cd c:\Users\Lenovo\Desktop\Exam\Examen_Final_Franco
.\deploy_and_test.ps1
```

**Qué hace el script:**
1. ✓ Verifica conexión a Kubernetes
2. ✓ Aplica todos los manifiestos (secret, Redis, producer, Redis Commander)
3. ✓ Espera a que los pods estén listos
4. ✓ Recopila estado de PVC (debe estar `Bound`)
5. ✓ Guarda logs del productor
6. ✓ Verifica datos en Redis
7. ✓ **Prueba de resiliencia:** elimina el Pod de Redis, espera recreación y verifica persistencia de datos
8. ✓ Guarda evidencias en carpeta `evidence/`

**Salida esperada:** archivos de evidencia en `./evidence/`

### Opción 2: Despliegue Manual

```powershell
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/redis-statefulset.yaml
kubectl apply -f k8s/redis-headless-svc.yaml
kubectl apply -f k8s/redis-cluster-svc.yaml
kubectl apply -f k8s/producer-deployment.yaml
kubectl apply -f k8s/redis-commander-deployment.yaml

# Verificar estado
kubectl get pods -o wide
kubectl get pvc
kubectl get svc
```

## Acceder a la Interfaz Web

Una vez desplegado, abre en tu navegador:

```
http://localhost:30081
```

**Nota:** Si no funciona directamente, haz port-forward:
```powershell
kubectl port-forward svc/redis-commander 8081:8081
# Luego accede a: http://localhost:8081
```

En la interfaz verás:
- Lista `sensors` con entradas JSON
- Formato: `{ "sensor_id": "rbt-01", "valor": XX.XX, "timestamp": "2026-02-04T..." }`

## Verificar Datos en la CLI

```powershell
# Port-forward a Redis
kubectl port-forward svc/redis-cluster 6379:6379

# En otra terminal:
redis-cli -h 127.0.0.1 -p 6379 -a "SuperS3cret123!"
> LRANGE sensors 0 -10
```

## Prueba Manual de Resiliencia

```powershell
# 1. Verificar que hay datos visibles en Redis Commander (http://localhost:30081)

# 2. Eliminar el Pod de Redis
kubectl delete pod -l app=redis

# 3. Observar recreación en tiempo real
kubectl get pods -w

# 4. Verificar que PVC sigue Bound
kubectl get pvc

# 5. Acceder a Redis Commander nuevamente y confirmar que los datos persisten
```

## Estructura de Archivos

```
Examen_Final_Franco/
├── k8s/
│   ├── secret.yaml                      # Contraseña de Redis
│   ├── redis-statefulset.yaml          # Redis con PVC
│   ├── redis-headless-svc.yaml         # Headless service para StatefulSet
│   ├── redis-cluster-svc.yaml          # ClusterIP service para clientes
│   ├── producer-deployment.yaml        # Sensor simulado
│   ├── redis-commander-deployment.yaml # Interfaz web + NodePort
│   └── scripts/
│       ├── collect_evidence.ps1        # Script Windows
│       └── collect_evidence.sh         # Script Linux/Mac
├── generate_report.tex                  # Informe en LaTeX
├── deploy_and_test.ps1                  # Script de despliegue
├── README.md                            # Este archivo
├── requirements.txt                     # Dependencias (vacío para K8s)
└── evidence/                            # (Generado tras ejecutar deploy_and_test.ps1)
    ├── 00_cluster_info.txt
    ├── 01_apply_*.txt
    ├── 02_pods_initial.txt
    ├── 03_pvc_bound.txt
    ├── 04_producer_logs.txt
    ├── 05_redis_data.txt
    ├── 06_pod_delete.txt
    ├── 07_pvc_after_recovery.txt
    ├── 08_redis_data_after_recovery.txt
    ├── 09_final_pods_state.txt
    └── 10_final_services.txt
```

## Tecnologías Utilizadas

| Componente | Tecnología | Justificación |
|-----------|-----------|--------------|
| Persistencia | Redis (bitnami/redis:7) | Baja latencia, patrones de lista ideales para sensores, soporte de autenticación nativa |
| Productor | Python 3.12-slim | Scripting sencillo, cliente Redis disponible, tamaño de imagen reducido |
| Visualizador | Redis Commander | Interfaz web estable, conexión automática mediante variables de entorno |
| Orquestación | Kubernetes (Docker Desktop) | StatefulSet con PVC para persistencia, Secrets para seguridad, Services para networking |

## Troubleshooting

### Kubernetes no conecta
```powershell
# Verificar que Docker Desktop está corriendo y tiene Kubernetes habilitado
docker version
kubectl cluster-info
kubectl get nodes
```

### Los pods no inician
```powershell
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Redis Commander no es accesible
```powershell
# Verificar service
kubectl get svc redis-commander

# Port-forward manual
kubectl port-forward svc/redis-commander 8081:8081
# Accede a http://localhost:8081
```

### El productor no escribe en Redis
```powershell
# Ver logs
kubectl logs deployment/producer -f

# Verificar credenciales
kubectl get secret redis-secret -o jsonpath='{.data.redis-password}' | base64 -d
```

## Entregables para el Informe

Después de ejecutar `deploy_and_test.ps1`:

1. **Captura de pantalla** de Redis Commander mostrando lista `sensors` con JSON
2. **Salida de `kubectl get pvc`** mostrando STATUS=Bound
3. **Logs de consola** de la prueba de resiliencia (en `evidence/`)
4. **Manifiestos YAML** (carpeta `k8s/`)
5. **Este README** y **generate_report.tex**

## Comandos Útiles

```powershell
# Ver todos los recursos
kubectl get all

# Describir un pod
kubectl describe pod <pod-name>

# Ver logs en tiempo real
kubectl logs -f deployment/producer

# Ejecutar comando dentro de un pod
kubectl exec -it pod/<pod-name> -- bash

# Limpiar todo (cuidado!)
kubectl delete -f k8s/
```

## Autor

Informe de Examen Final - Sistema de Monitoreo en Kubernetes

Siguientes pasos para entregar PDF y repo:
- Ejecutar los pasos anteriores en su clúster, capturar pantallas/outputs (UI mostrando JSON, `kubectl get pvc` Bound, logs del recreado Pod), y compilar un PDF con esas evidencias.
- Subir todo a un repositorio Git y añadir el PDF.

Automatización de evidencias:
- `k8s/scripts/collect_evidence.sh` - Script bash que recolecta `kubectl get` y logs y guarda en `evidence/`.
- `k8s/scripts/collect_evidence.ps1` - Equivalente en PowerShell (Windows).
- `generate_report.py` - Lee los archivos en `evidence/` y genera `evidence_report.pdf` (usa `reportlab`).

Instrucciones rápidas:
```bash
pip install -r requirements.txt
# Ejecutar script (Linux/macOS)
bash k8s/scripts/collect_evidence.sh
# O en Windows PowerShell:
# .\k8s\scripts\collect_evidence.ps1
python generate_report.py
```

Evidencias esperadas:
- `evidence/pvc.txt` (debe mostrar PVC en estado `Bound`).
- `evidence/redis_sensors_before.txt` (lista `sensors` con JSONs).
- `evidence/producer_logs.txt` y `evidence/redis_commander_logs.txt`.


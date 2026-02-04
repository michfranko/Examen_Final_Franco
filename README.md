# Sistema de Monitoreo - Manifiestos Kubernetes

Resumen rápido:
- Motor de datos: Redis (bitnami/redis:7) como almacén NoSQL en memoria con persistencia vía PVC.
- Productor: contenedor `python:3.12-slim` que ejecuta un script que genera JSON cada 3s y hace `LPUSH` en la lista `sensors`.
- Visualizador: `redis-commander` conectado automáticamente a Redis; expuesto en NodePort `30081`.

Justificación técnica (selección de motor):
- Redis es ideal para datos volátiles y de alta velocidad por ser un almacén en memoria con latencias muy bajas.
- Soporta persistencia (RDB/AOF) y con un `StatefulSet` + `volumeClaimTemplates` los datos sobreviven a reinicios de Pod.
- Para este caso de uso (sensores con high-throughput y lectura frecuente) Redis ofrece la mejor latencia.

Archivos incluidos (carpeta `k8s/`):
- `secret.yaml` - Secret con `redis-password`.
- `redis-headless-svc.yaml` - Headless Service para StatefulSet.
- `redis-statefulset.yaml` - StatefulSet con `volumeClaimTemplates` (1Gi) y password configurado.
- `producer-deployment.yaml` - Deployment que instala `redis` client y ejecuta script que inserta JSON cada 3s.
- `redis-commander-deployment.yaml` - Deployment + NodePort Service (30081) para la UI.

Despliegue (asumiendo `kubectl` configurado contra su clúster):
```bash
# Aplicar secretos y servicios/statefulset
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/redis-headless-svc.yaml
kubectl apply -f k8s/redis-statefulset.yaml

# Esperar PVC bound y Pod listo
kubectl get pvc
kubectl get pods -l app=redis

# Desplegar productor y visualizador
kubectl apply -f k8s/producer-deployment.yaml
kubectl apply -f k8s/redis-commander-deployment.yaml

# Verificar servicios
kubectl get svc

# Abrir la UI (en el host): http://<NODE_IP>:30081
```

Prueba de resiliencia (pasos para evidenciar recuperación):
1. Asegúrese de que hay datos en la UI (`sensors` list).
2. Borre el Pod de Redis: `kubectl delete pod -l app=redis` (el StatefulSet recreará el Pod).
3. Espere a que el Pod vuelva a `Running` y verifique `kubectl get pvc` (debe estar `Bound`).
4. Abrir la UI de `redis-commander` y comprobar que los datos antiguos siguen presentes.

Notas y posibles ajustes:
- Si su clúster no tiene aprovisionamiento dinámico, deberá crear un `PersistentVolume` manualmente apuntando a `hostPath` o similar.
- La contraseña está en `k8s/secret.yaml` como ejemplo; en producción use un gestor de secretos.

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


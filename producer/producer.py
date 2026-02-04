#!/usr/bin/env python3
"""
Microservicio Productor - Sensor IoT simulado
Genera datos JSON cada 3 segundos y los almacena en Redis
"""

import os
import time
import random
import json
from datetime import datetime
import redis
from redis.exceptions import RedisError, ConnectionError

# Configuración desde variables de entorno
REDIS_HOST = os.environ.get('REDIS_HOST', 'localhost')
REDIS_PORT = int(os.environ.get('REDIS_PORT', '6379'))
REDIS_PASSWORD = os.environ.get('REDIS_PASSWORD', None)
SENSOR_ID = os.environ.get('SENSOR_ID', 'rbt-01')
PUSH_INTERVAL = int(os.environ.get('PUSH_INTERVAL', '3'))

print(f"[PRODUCTOR] Configuración:")
print(f"  Redis Host: {REDIS_HOST}")
print(f"  Redis Port: {REDIS_PORT}")
print(f"  Sensor ID: {SENSOR_ID}")
print(f"  Intervalo: {PUSH_INTERVAL}s")


def make_client():
    """Crear nueva conexión al cliente Redis"""
    return redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        password=REDIS_PASSWORD,
        decode_responses=True,
        socket_connect_timeout=5,
        socket_keepalive=True
    )


def wait_for_redis():
    """Esperar hasta que Redis esté disponible"""
    r = make_client()
    max_retries = 30
    attempt = 0

    while attempt < max_retries:
        try:
            r.ping()
            print(f"[PRODUCTOR] ✓ Conexión a Redis exitosa en intento {attempt + 1}")
            return r
        except (ConnectionError, RedisError) as e:
            attempt += 1
            wait_time = 3
            print(f"[PRODUCTOR] Redis no disponible (intento {attempt}/{max_retries}), reintentando en {wait_time}s...")
            print(f"[PRODUCTOR] Error: {e}")
            time.sleep(wait_time)
            r = make_client()

    raise Exception(f"No se pudo conectar a Redis después de {max_retries} intentos")


def generate_sensor_data():
    """Generar dato aleatorio del sensor en formato JSON"""
    valor = round(random.uniform(0, 100), 2)
    timestamp = datetime.utcnow().isoformat() + 'Z'

    return {
        "sensor_id": SENSOR_ID,
        "valor": valor,
        "timestamp": timestamp
    }


def main():
    """Bucle principal del productor"""
    print("[PRODUCTOR] Iniciando...")

    # Esperar a que Redis esté listo
    r = wait_for_redis()

    print(f"[PRODUCTOR] Comenzando a generar datos cada {PUSH_INTERVAL}s...")
    print("[PRODUCTOR] Presiona Ctrl+C para detener")

    iteration = 0
    while True:
        try:
            iteration += 1
            payload = generate_sensor_data()

            # Inmediatamente verifica la conexión y la recrea si falla
            try:
                r.lpush('sensors', json.dumps(payload))
                print(f"[PRODUCTOR] [{iteration}] ✓ Dato guardado: sensor_id={payload['sensor_id']}, valor={payload['valor']}")
            except (ConnectionError, RedisError) as e:
                print(f"[PRODUCTOR] [{iteration}] ✗ Error al escribir en Redis, reconectando...")
                r = make_client()

            time.sleep(PUSH_INTERVAL)

        except KeyboardInterrupt:
            print("[PRODUCTOR] Interrupción recibida, saliendo...")
            break
        except Exception as e:
            print(f"[PRODUCTOR] Error inesperado: {e}")
            time.sleep(PUSH_INTERVAL)


if __name__ == "__main__":
    main()

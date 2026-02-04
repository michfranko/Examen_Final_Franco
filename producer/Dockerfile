FROM python:3.12-slim

WORKDIR /app

# Instalar cliente Redis
RUN pip install --no-cache-dir redis==5.0.1

# Copiar script del productor
COPY producer.py .

# Variables de entorno por defecto
ENV REDIS_HOST=redis
ENV REDIS_PORT=6379
ENV REDIS_PASSWORD=
ENV SENSOR_ID=rbt-01
ENV PUSH_INTERVAL=3
ENV PYTHONUNBUFFERED=1

# Ejecutar el productor
CMD ["python3", "producer.py"]

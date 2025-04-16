# backup-docker/Dockerfile

# Usar una imagen base ligera como Debian Bullseye Slim
FROM debian:bullseye-slim

# Establecer variables de entorno para evitar diálogos interactivos
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias: curl, gnupg, lsb-release (para repos GCS), procps, gzip, clientes DB
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    lsb-release \
    procps \
    gzip \
    # Añadir repositorios e instalar gcloud SDK (incluye gsutil)
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && apt-get install -y google-cloud-sdk && \
    # Instalar cliente MySQL
    apt-get install -y default-mysql-client && \
    # Instalar cliente PostgreSQL
    apt-get install -y postgresql-client && \
    # Limpiar caché de apt
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Crear directorios para scripts, secretos y configuración opcional
RUN mkdir /app && \
    mkdir -p /etc/gcloud-secrets && \
    mkdir -p /etc/db-secrets

# Copiar el script de backup al contenedor
COPY backup_dbs.sh /app/backup_dbs.sh
RUN chmod +x /app/backup_dbs.sh

# Establecer el directorio de trabajo
WORKDIR /app

# El contenedor ejecutará este script por defecto cuando se inicie
CMD ["/app/backup_dbs.sh"]
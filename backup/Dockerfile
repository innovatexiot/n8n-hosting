# Usar una imagen base ligera con herramientas comunes. Debian es una buena opción.
FROM debian:bullseye-slim

# Evitar preguntas interactivas durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias: cron, clientes de BD, gzip, curl (para SDK), ca-certificates
RUN apt-get update && apt-get install -y --no-install-recommends \
    cron \
    mariadb-client \  # Usar cliente MariaDB
    postgresql-client \
    gzip \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Instalar Google Cloud SDK (incluye gsutil)
RUN curl https://sdk.cloud.google.com > /tmp/install.sh && \
    bash /tmp/install.sh --disable-prompts --install-dir=/usr/local && \
    rm /tmp/install.sh
# Añadir gcloud al PATH (formato recomendado)
ENV PATH="${PATH}:/usr/local/google-cloud-sdk/bin"

# Crear directorio para scripts y logs dentro del contenedor
RUN mkdir -p /app/scripts /app/temp_backups /app/logs

# Copiar el script de backup al contenedor
COPY backup_dbs.sh /app/scripts/backup_dbs.sh
RUN chmod +x /app/scripts/backup_dbs.sh

# Crear un archivo crontab
# Ejecutará el script cada día a las 3:00 AM (dentro del contenedor)
# Redirige la salida a stdout/stderr de Docker para verla con 'docker logs'
RUN echo "0 3 * * *   root    /app/scripts/backup_dbs.sh >> /proc/1/fd/1 2>> /proc/1/fd/2" > /etc/cron.d/backup-cron
# Dar permisos correctos al crontab
RUN chmod 0644 /etc/cron.d/backup-cron
# Aplicar el crontab (esto no es estrictamente necesario si cron lee /etc/cron.d/)
# RUN crontab /etc/cron.d/backup-cron

# Crear el archivo de log para cron y darle permisos (puede no ser necesario con CMD ["cron", "-f"])
# RUN touch /var/log/cron.log

# Establecer el directorio de trabajo
WORKDIR /app

# Comando para iniciar cron en primer plano (formato JSON recomendado)
CMD ["cron", "-f"]
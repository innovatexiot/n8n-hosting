#!/bin/bash

# Salir inmediatamente si un comando falla
set -e
# Tratar variables no definidas como un error
set -u
# Asegurar que los pipelines fallen si un comando falla
set -o pipefail

# Directorio de configuración montado donde estará .env
CONFIG_DIR="/config"
ENV_FILE="${CONFIG_DIR}/.env"

# Cargar variables de entorno desde .env si existe
if [[ -f "$ENV_FILE" ]]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "Error: Archivo .env no encontrado en $ENV_FILE"
    exit 1
fi

# Directorio temporal DENTRO del contenedor
BACKUP_TEMP_DIR="/app/temp_backups"
mkdir -p "$BACKUP_TEMP_DIR"

# --- Backup MySQL ---
echo "Iniciando backup de MySQL (Host: $MYSQL_HOST)..."
MYSQL_BACKUP_FILENAME="mysql_all_dbs_$(date +%Y%m%d_%H%M%S).sql.gz"
MYSQL_BACKUP_FULL_PATH="${BACKUP_TEMP_DIR}/${MYSQL_BACKUP_FILENAME}"

# Ejecutar mysqldump conectándose al HOST de MySQL (nombre del servicio/contenedor en la red Docker)
# Asegúrate de que MYSQL_HOST esté definido en tu .env
mysqldump --all-databases \
    -h "$MYSQL_HOST" \
    -P "$MYSQL_PORT" \
    -u "$MYSQL_USER" \
    -p"$MYSQL_PASSWORD" | gzip > "$MYSQL_BACKUP_FULL_PATH"

echo "Backup MySQL completado: $MYSQL_BACKUP_FILENAME"

# --- Backup PostgreSQL ---
echo "Iniciando backup de PostgreSQL (Host: $POSTGRES_HOST)..."
POSTGRES_BACKUP_FILENAME="postgres_all_dbs_$(date +%Y%m%d_%H%M%S).sql.gz"
POSTGRES_BACKUP_FULL_PATH="${BACKUP_TEMP_DIR}/${POSTGRES_BACKUP_FILENAME}"

# Establecer PGPASSWORD si se proporciona en .env
if [[ -n "${POSTGRES_PASSWORD:-}" ]]; then
  export PGPASSWORD=$POSTGRES_PASSWORD
fi

# Ejecutar pg_dumpall conectándose al HOST de PostgreSQL
# Asegúrate de que POSTGRES_HOST esté definido en tu .env
pg_dumpall \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" | gzip > "$POSTGRES_BACKUP_FULL_PATH"

# Limpiar PGPASSWORD
unset PGPASSWORD

echo "Backup PostgreSQL completado: $POSTGRES_BACKUP_FILENAME"

# --- Subir a Google Cloud Storage ---
# Usa la ruta completa a gsutil por si acaso no está en el PATH de cron
GSUTIL_PATH="/usr/local/google-cloud-sdk/bin/gsutil"
GCS_TARGET_MYSQL="gs://${GCS_BUCKET_NAME}/${GCS_BACKUP_PATH}/${MYSQL_BACKUP_FILENAME}"
GCS_TARGET_POSTGRES="gs://${GCS_BUCKET_NAME}/${GCS_BACKUP_PATH}/${POSTGRES_BACKUP_FILENAME}"

echo "Subiendo backup MySQL a $GCS_TARGET_MYSQL..."
$GSUTIL_PATH cp "$MYSQL_BACKUP_FULL_PATH" "$GCS_TARGET_MYSQL"
echo "Subida MySQL completada."

echo "Subiendo backup PostgreSQL a $GCS_TARGET_POSTGRES..."
$GSUTIL_PATH cp "$POSTGRES_BACKUP_FULL_PATH" "$GCS_TARGET_POSTGRES"
echo "Subida PostgreSQL completada."

# --- Limpieza Local ---
echo "Limpiando archivos locales dentro del contenedor..."
rm "$MYSQL_BACKUP_FULL_PATH"
rm "$POSTGRES_BACKUP_FULL_PATH"
echo "Limpieza completada."

echo "--- Proceso de Backup Finalizado Exitosamente ---"

exit 0
#!/bin/bash

# Salir inmediatamente si un comando falla
set -e
# Tratar variables no definidas como un error
set -u
# Asegurar que los pipelines fallen si un comando falla (importante para pipes como | gzip)
set -o pipefail

# Directorio donde se encuentra este script y el .env
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ENV_FILE="${SCRIPT_DIR}/.env"

# Cargar variables de entorno desde .env si existe
if [[ -f "$ENV_FILE" ]]; then
    # Usar 'export' en el .env o este método para cargarlas
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "Error: Archivo .env no encontrado en $ENV_FILE"
    exit 1
fi

# Crear directorio temporal si no existe
mkdir -p "$BACKUP_TEMP_DIR"

# --- Backup MySQL ---
echo "Iniciando backup de MySQL ($MYSQL_CONTAINER_NAME)..."
MYSQL_BACKUP_FILENAME="mysql_all_dbs_$(date +%Y%m%d_%H%M%S).sql.gz"
MYSQL_BACKUP_FULL_PATH="${BACKUP_TEMP_DIR}/${MYSQL_BACKUP_FILENAME}"

# Ejecutar mysqldump dentro del contenedor y comprimir al vuelo
docker exec "$MYSQL_CONTAINER_NAME" sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' | gzip > "$MYSQL_BACKUP_FULL_PATH"
# Nota: Usamos la variable de entorno MYSQL_ROOT_PASSWORD que la imagen oficial de MySQL suele usar.
# Si usas un usuario/pass diferente, ajusta:
# docker exec "$MYSQL_CONTAINER_NAME" sh -c 'exec mysqldump --all-databases -u"$MYSQL_USER" -p"$MYSQL_PASSWORD"' | gzip > "$MYSQL_BACKUP_FULL_PATH"


echo "Backup MySQL completado: $MYSQL_BACKUP_FILENAME"

# --- Backup PostgreSQL ---
echo "Iniciando backup de PostgreSQL ($POSTGRES_CONTAINER_NAME)..."
POSTGRES_BACKUP_FILENAME="postgres_all_dbs_$(date +%Y%m%d_%H%M%S).sql.gz"
POSTGRES_BACKUP_FULL_PATH="${BACKUP_TEMP_DIR}/${POSTGRES_BACKUP_FILENAME}"

# Ejecutar pg_dumpall dentro del contenedor (como usuario postgres) y comprimir
# Si tu contenedor necesita password para el usuario postgres, descomenta PGPASSWORD
# export PGPASSWORD=$POSTGRES_PASSWORD
docker exec -u "$POSTGRES_USER" "$POSTGRES_CONTAINER_NAME" pg_dumpall | gzip > "$POSTGRES_BACKUP_FULL_PATH"
# unset PGPASSWORD # Buena práctica limpiar la variable de entorno

echo "Backup PostgreSQL completado: $POSTGRES_BACKUP_FILENAME"

# --- Subir a Google Cloud Storage ---
GCS_TARGET_MYSQL="gs://${GCS_BUCKET_NAME}/${GCS_BACKUP_PATH}/${MYSQL_BACKUP_FILENAME}"
GCS_TARGET_POSTGRES="gs://${GCS_BUCKET_NAME}/${GCS_BACKUP_PATH}/${POSTGRES_BACKUP_FILENAME}"

echo "Subiendo backup MySQL a $GCS_TARGET_MYSQL..."
gsutil cp "$MYSQL_BACKUP_FULL_PATH" "$GCS_TARGET_MYSQL"
echo "Subida MySQL completada."

echo "Subiendo backup PostgreSQL a $GCS_TARGET_POSTGRES..."
gsutil cp "$POSTGRES_BACKUP_FULL_PATH" "$GCS_TARGET_POSTGRES"
echo "Subida PostgreSQL completada."

# --- Limpieza Local ---
echo "Limpiando archivos locales..."
rm "$MYSQL_BACKUP_FULL_PATH"
rm "$POSTGRES_BACKUP_FULL_PATH"
echo "Limpieza completada."

echo "--- Proceso de Backup Finalizado Exitosamente ---"

exit 0
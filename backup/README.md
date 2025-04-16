# Sistema de Backup Automatizado para Contenedores Docker (MySQL/PostgreSQL) en GCE con GCS

Este proyecto implementa un mecanismo automatizado para realizar copias de seguridad completas de bases de datos MySQL (`--all-databases`) y PostgreSQL (`pg_dumpall`) que se ejecutan dentro de contenedores Docker en una máquina virtual (VM) de Google Compute Engine (GCE). Las copias de seguridad se almacenan de forma segura en Google Cloud Storage (GCS).

## Descripción General

El sistema utiliza un script Bash (`backup_dbs.sh`) que se ejecuta periódicamente mediante `cron` en la VM de GCE. El script realiza las siguientes acciones:

1.  **Lee la configuración:** Obtiene nombres de contenedores, credenciales de base de datos y detalles de GCS desde un archivo `.env`.
2.  **Ejecuta Backups:** Utiliza `docker exec` para ejecutar `mysqldump --all-databases` en el contenedor MySQL y `pg_dumpall` en el contenedor PostgreSQL.
3.  **Comprime:** Comprime las salidas SQL al vuelo usando `gzip` para ahorrar espacio y ancho de banda.
4.  **Sube a GCS:** Utiliza `gsutil` para cargar los archivos de backup comprimidos al bucket de GCS especificado. Aprovecha la autenticación implícita de la cuenta de servicio de la VM de GCE.
5.  **Limpia:** Elimina los archivos de backup temporales de la VM local.

## Características

*   **Automatizado:** Utiliza `cron` para ejecuciones periódicas sin intervención manual.
*   **Soporte Multi-DB:** Realiza copias de seguridad de *todas* las bases de datos dentro de los contenedores MySQL y PostgreSQL especificados.
*   **Almacenamiento en GCS:** Guarda las copias de seguridad en un almacenamiento de objetos fiable y escalable.
*   **Autenticación Segura:** Utiliza la cuenta de servicio asociada a la VM de GCE para autenticarse con GCS (no requiere archivos de clave JSON si los permisos son correctos).
*   **Configurable:** Las credenciales y parámetros se gestionan fácilmente a través de un archivo `.env`.
*   **Eficiente:** Comprime los backups para optimizar el almacenamiento y la transferencia.

## Prerrequisitos

Antes de configurar este sistema, asegúrate de tener:

1.  **VM de Google Compute Engine:** Una VM activa donde se ejecutan tus contenedores Docker.
2.  **Docker y Docker Compose:** Instalados y funcionando en la VM.
3.  **Contenedores Activos:** Los contenedores MySQL (`halltec_db`) y PostgreSQL (`n8n-hosting-postgres-1`) deben estar en ejecución. Anota sus nombres o IDs exactos.
4.  **Google Cloud SDK:** Instalado en la VM, específicamente la herramienta `gsutil`. Verifica con `gsutil version`. (Normalmente preinstalado en imágenes de GCE).
5.  **Bucket de Google Cloud Storage:** Un bucket creado en GCS para almacenar los backups (ej: `mi-bucket-de-backups-proyecto`).
6.  **Permisos de Cuenta de Servicio de la VM:** La cuenta de servicio asociada a tu VM de GCE debe tener permisos para escribir objetos en el bucket de GCS de destino. El rol `roles/storage.objectAdmin` aplicado *específicamente a ese bucket* es una buena práctica (principio de privilegio mínimo).

## Configuración e Instalación

Sigue estos pasos en tu VM de GCE:

1.  **Clonar o Crear Archivos:**
    *   Copia el script `backup_dbs.sh` y un archivo `.env` (basado en la plantilla de abajo) a un directorio en tu VM. Se recomienda usar un directorio como `/opt/backup_scripts/`:
        ```bash
        sudo mkdir -p /opt/backup_scripts/temp_backups
        sudo chown $USER:$USER /opt/backup_scripts # O el usuario que ejecutará el script
        cd /opt/backup_scripts
        # Ahora crea los archivos backup_dbs.sh y .env aquí
        ```

2.  **Crear y Configurar `.env`:**
    *   Crea el archivo `/opt/backup_scripts/.env` con el siguiente contenido, reemplazando los valores de ejemplo con los tuyos:
        ```dotenv
        # /opt/backup_scripts/.env

        # --- Contenedor MySQL ---
        MYSQL_CONTAINER_NAME="halltec_db" # O el ID del contenedor
        MYSQL_USER="root" # Usuario para hacer el dump
        MYSQL_PASSWORD="tu_password_mysql_seguro" # Contraseña del usuario MYSQL_USER
        # Opcional: Si usas la variable de entorno del contenedor oficial de MySQL:
        # MYSQL_ROOT_PASSWORD="la_pass_de_root_del_contenedor_mysql"

        # --- Contenedor PostgreSQL ---
        POSTGRES_CONTAINER_NAME="n8n-hosting-postgres-1" # O el ID del contenedor
        POSTGRES_USER="postgres" # Usuario para hacer el dump (normalmente postgres)
        # Descomenta y establece si se requiere contraseña para pg_dumpall desde docker exec
        # POSTGRES_PASSWORD="tu_password_postgres_seguro"

        # --- Configuración de Backup ---
        GCS_BUCKET_NAME="tu-nombre-de-bucket-gcs" # SOLO el nombre del bucket
        BACKUP_TEMP_DIR="/opt/backup_scripts/temp_backups" # Directorio temporal local
        GCS_BACKUP_PATH="database_backups" # Ruta (prefijo) dentro del bucket GCS
        ```
    *   **¡Importante!** Protege este archivo, ya que contiene credenciales:
        ```bash
        chmod 600 /opt/backup_scripts/.env
        ```

3.  **Revisar `backup_dbs.sh`:**
    *   Asegúrate de que el script `backup_dbs.sh` (proporcionado en la respuesta anterior) esté en `/opt/backup_scripts/`.
    *   Verifica que los comandos `docker exec` dentro del script coincidan con tu método de autenticación para cada base de datos (uso de `MYSQL_PASSWORD` vs `MYSQL_ROOT_PASSWORD`, necesidad de `PGPASSWORD` para PostgreSQL).

4.  **Hacer Ejecutable el Script:**
    ```bash
    chmod +x /opt/backup_scripts/backup_dbs.sh
    ```

5.  **Probar Manualmente:**
    *   Ejecuta el script una vez para asegurarte de que todo funciona correctamente:
        ```bash
        /opt/backup_scripts/backup_dbs.sh
        ```
    *   Verifica la salida en la consola, la creación (y posterior eliminación) de archivos en `BACKUP_TEMP_DIR`, y la aparición de los archivos `.sql.gz` en tu bucket de GCS.

6.  **Automatizar con Cron:**
    *   Edita la tabla de cron. Es común usar `root` para estas tareas para evitar problemas de permisos con Docker, pero puedes usar otro usuario si tiene los permisos adecuados.
        ```bash
        sudo crontab -e
        ```
    *   Añade una línea para programar la ejecución. Ejemplo para ejecutar todos los días a las 03:00 AM:
        ```crontab
        # m h  dom mon dow   command
        0 3 * * * /opt/backup_scripts/backup_dbs.sh >> /var/log/backup_dbs.log 2>&1
        ```
    *   Esto ejecutará el script y redirigirá toda la salida (stdout y stderr) al archivo `/var/log/backup_dbs.log`, lo cual es útil para depurar. Asegúrate de que el archivo de log pueda ser escrito por el usuario de cron.

## Uso

*   **Backups Automáticos:** Una vez configurado `cron`, los backups se ejecutarán automáticamente según la programación definida.
*   **Backups Manuales:** Puedes ejecutar un backup en cualquier momento ejecutando `/opt/backup_scripts/backup_dbs.sh`.
*   **Monitorización:** Revisa periódicamente el archivo de log (`/var/log/backup_dbs.log`) para detectar posibles errores. También verifica que los backups aparezcan regularmente en tu bucket de GCS.

## Restauración de Backups

En caso de necesitar restaurar una base de datos desde un backup almacenado en GCS:

1.  **Identificar y Descargar:**
    *   Busca el archivo de backup deseado en tu bucket de GCS.
    *   Descárgalo a tu VM usando `gsutil`:
        ```bash
        # Ejemplo para MySQL
        gsutil cp gs://tu-nombre-de-bucket-gcs/database_backups/mysql_all_dbs_YYYYMMDD_HHMMSS.sql.gz .

        # Ejemplo para PostgreSQL
        gsutil cp gs://tu-nombre-de-bucket-gcs/database_backups/postgres_all_dbs_YYYYMMDD_HHMMSS.sql.gz .
        ```

2.  **Descomprimir:**
    *   Descomprime el archivo descargado:
        ```bash
        gunzip nombre_del_archivo_backup.sql.gz
        # Esto creará un archivo .sql
        ```

3.  **Restaurar (¡CON PRECAUCIÓN!):**

    *   **Para MySQL:**
        *   Asegúrate de que el contenedor MySQL de destino esté en ejecución.
        *   Obtén su nombre o ID (`MYSQL_CONTAINER_NAME`).
        *   Ejecuta el siguiente comando. **¡ADVERTENCIA:** Esto puede sobrescribir datos existentes en el contenedor!
            ```bash
            # Usando la contraseña de root del contenedor (ajusta si usas otro usuario/pass)
            docker exec -i $MYSQL_CONTAINER_NAME sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' < nombre_del_archivo_mysql.sql

            # O si usas usuario/pass del .env:
            # docker exec -i $MYSQL_CONTAINER_NAME sh -c 'exec mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD"' < nombre_del_archivo_mysql.sql
            ```

    *   **Para PostgreSQL:**
        *   Asegúrate de que el contenedor PostgreSQL de destino esté en ejecución.
        *   Obtén su nombre o ID (`POSTGRES_CONTAINER_NAME`).
        *   `pg_dumpall` genera un script que incluye comandos para crear roles y bases de datos. A menudo es más seguro restaurar en una instancia "limpia" o después de haber eliminado las bases de datos/roles existentes (¡con mucho cuidado!).
        *   Ejecuta como el usuario `postgres` (u otro superusuario). **¡ADVERTENCIA:** Esto puede fallar si los roles/bases de datos ya existen, o puede intentar sobrescribirlos!
            ```bash
            # Si se requiere contraseña, exporta PGPASSWORD antes
            # export PGPASSWORD=$POSTGRES_PASSWORD

            docker exec -i -u postgres $POSTGRES_CONTAINER_NAME psql -U postgres < nombre_del_archivo_postgres.sql

            # unset PGPASSWORD # Buena práctica
            ```

## Consideraciones de Seguridad

*   **Archivo `.env`:** Es crucial proteger el archivo `.env` estableciendo permisos restrictivos (`chmod 600`) para que solo el propietario pueda leerlo.
*   **Permisos GCS:** Aplica el principio de privilegio mínimo a la cuenta de servicio de la VM. Solo concede los permisos necesarios (`storage.objectAdmin` o `storage.objectCreator` y `storage.objectViewer`) y solo sobre el bucket específico de backups.
*   **Credenciales de BD:** Utiliza contraseñas fuertes para tus usuarios de base de datos. Considera crear usuarios específicos para backups con los permisos mínimos necesarios (aunque `mysqldump --all-databases` y `pg_dumpall` generalmente requieren privilegios elevados).

## Logging y Troubleshooting

*   La salida principal del script (cuando se ejecuta vía `cron`) se redirige a `/var/log/backup_dbs.log` (o el archivo que hayas especificado). Revisa este archivo para diagnosticar problemas.
*   Verifica los permisos de la cuenta de servicio de la VM en IAM si fallan las subidas a GCS.
*   Comprueba los logs de Docker de los contenedores de base de datos si los comandos `mysqldump` o `pg_dumpall` fallan.
*   Asegúrate de que `gsutil` esté correctamente instalado y accesible en el PATH del usuario que ejecuta `cron`.
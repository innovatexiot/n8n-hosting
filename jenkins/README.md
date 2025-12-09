# Jenkins con Docker Compose

Esta configuración despliega Jenkins con un controlador y un agente SSH, expuesto por HTTPS usando Nginx como reverse proxy.

## Estructura

```
jenkins/
├── docker-compose.yml    # Configuración de contenedores
├── .env                  # Variables de entorno
├── jenkins_agent         # Clave privada SSH (NO COMPARTIR)
├── jenkins_agent.pub     # Clave pública SSH
└── README.md            # Este archivo
```

## Componentes

### Servicios Docker

1. **jenkins-controller**: Controlador principal de Jenkins
   - Puerto: 8086 (mapeado desde 8080 interno)
   - Puerto agentes: 50000
   - Volumen persistente: `jenkins_data`
   - Acceso a Docker socket para ejecutar contenedores

2. **jenkins-agent**: Agente SSH para ejecutar jobs
   - Comunicación por SSH con el controlador
   - Java 11 preinstalado
   - Autenticación por clave SSH

### Configuración Nginx

- **Archivo**: `nginx/jenkins.conf`
- **Dominio**: vm-gcp.jenkins.innovatexiot.com
- **Puerto**: 443 (HTTPS)
- **Certificado**: Let's Encrypt

---

## Instalación

### 1. Iniciar los contenedores

Desde el directorio `jenkins/`:

```bash
docker-compose up -d
```

### 2. Obtener el password inicial

Jenkins genera un password inicial automáticamente. Para obtenerlo:

```bash
docker logs jenkins-controller
```

Busca un bloque como este:

```
*************************************************************
*************************************************************
*************************************************************

Jenkins initial setup is required. An admin user has been created and a password generated.
Please use the following password to proceed to installation:

a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

This may also be found at: /var/jenkins_home/secrets/initialAdminPassword

*************************************************************
*************************************************************
*************************************************************
```

### 3. Configurar Nginx en el servidor

Conéctate por SSH al servidor y ejecuta:

```bash
# Copiar configuración a sites-available
sudo cp /home/info/repos/n8n-hosting/nginx/jenkins.conf /etc/nginx/sites-available/jenkins.conf

# Crear enlace simbólico en sites-enabled
sudo ln -s /etc/nginx/sites-available/jenkins.conf /etc/nginx/sites-enabled/jenkins.conf

# Verificar configuración
sudo nginx -t

# Si todo está bien, recargar Nginx
sudo systemctl reload nginx
```

### 4. Generar certificado SSL

```bash
sudo certbot --nginx -d vm-gcp.jenkins.innovatexiot.com
```

Certbot actualizará automáticamente la configuración de Nginx con las rutas correctas de los certificados.

### 5. Configurar Jenkins (Primera vez)

1. Accede a `https://vm-gcp.jenkins.innovatexiot.com`
2. Ingresa el password inicial obtenido en el paso 2
3. Selecciona **Install suggested plugins**
4. Crea tu usuario administrador
5. Confirma la URL de Jenkins

---

## Configurar el Agente SSH

### 1. Agregar credencial SSH en Jenkins

1. Ve a **Manage Jenkins** → **Manage Credentials**
2. Click en **Jenkins** (bajo "Stores scoped to Jenkins")
3. Click en **Global credentials**
4. Click en **Add Credentials**
5. Configura:
   - **Kind**: SSH Username with private key
   - **Scope**: System
   - **ID**: jenkins-agent-key
   - **Description**: SSH key for Jenkins agent
   - **Username**: jenkins
   - **Private Key**: Enter directly
   
6. Copia el contenido de `jenkins/jenkins_agent` (la clave privada):

```bash
cat jenkins/jenkins_agent
```

7. Pega el contenido completo en el campo de texto
8. Click en **OK**

### 2. Configurar el nodo agente

1. Ve a **Manage Jenkins** → **Manage Nodes and Clouds**
2. Click en **New Node**
3. Configura:
   - **Node name**: jenkins-agent-1
   - **Type**: Permanent Agent
   - Click **OK**

4. En la configuración del nodo:
   - **Remote root directory**: `/home/jenkins/agent`
   - **Labels**: docker linux
   - **Usage**: Use this node as much as possible
   - **Launch method**: Launch agents via SSH
   - **Host**: jenkins-agent
   - **Credentials**: jenkins-agent-key (la que creaste antes)
   - **Host Key Verification Strategy**: Non verifying Verification Strategy
   - **Availability**: Keep this agent online as much as possible

5. Click en **Advanced** y configura:
   - **JavaPath**: `/usr/local/openjdk-11/bin/java`

6. Click en **Save**

### 3. Verificar conexión

1. Click en el nombre del agente recién creado
2. Click en **Log** en el menú izquierdo
3. Deberías ver: **Agent successfully connected and online**

---

## Comandos útiles

### Ver logs

```bash
# Logs del controlador
docker logs jenkins-controller

# Logs del agente
docker logs jenkins-agent

# Seguir logs en tiempo real
docker logs -f jenkins-controller
```

### Reiniciar servicios

```bash
# Reiniciar todo
docker-compose restart

# Reiniciar solo el controlador
docker-compose restart jenkins-controller

# Reiniciar solo el agente
docker-compose restart jenkins-agent
```

### Detener servicios

```bash
# Detener sin eliminar volúmenes
docker-compose down

# Detener y eliminar volúmenes (¡CUIDADO! Perderás todos los datos)
docker-compose down -v
```

### Backup

```bash
# Backup del volumen de datos
docker run --rm -v jenkins_data:/data -v $(pwd):/backup alpine tar czf /backup/jenkins-backup-$(date +%Y%m%d).tar.gz -C /data .

# Restaurar backup
docker run --rm -v jenkins_data:/data -v $(pwd):/backup alpine tar xzf /backup/jenkins-backup-YYYYMMDD.tar.gz -C /data
```

---

## Troubleshooting

### El agente no se conecta

1. Verifica que ambos contenedores estén en la misma red:
   ```bash
   docker network inspect shared_network
   ```

2. Verifica que el agente esté corriendo:
   ```bash
   docker ps | grep jenkins-agent
   ```

3. Revisa los logs del agente:
   ```bash
   docker logs jenkins-agent
   ```

### Error de permisos en Docker socket

Si Jenkins no puede ejecutar comandos Docker:

```bash
# En el servidor, dar permisos al socket
sudo chmod 666 /var/run/docker.sock
```

### Certificado SSL no válido

Si el certificado no se renueva automáticamente:

```bash
# Renovar manualmente
sudo certbot renew

# Verificar configuración
sudo certbot certificates
```

---

## Seguridad

### Claves SSH

- **Clave privada** (`jenkins_agent`): NUNCA compartir ni subir a repositorios públicos
- **Clave pública** (`jenkins_agent.pub`): Se puede compartir, está en el docker-compose.yml

### Recomendaciones

1. Cambia el password de administrador después del primer login
2. Habilita autenticación de dos factores si es posible
3. Limita el acceso por IP si es necesario (en Nginx)
4. Mantén Jenkins actualizado regularmente
5. Revisa los plugins instalados y sus permisos

---

## Actualización

Para actualizar Jenkins a la última versión LTS:

```bash
# Detener servicios
docker-compose down

# Actualizar imágenes
docker-compose pull

# Reiniciar servicios
docker-compose up -d
```

---

## Referencias

- [Documentación oficial de Jenkins](https://www.jenkins.io/doc/)
- [Jenkins Docker Hub](https://hub.docker.com/r/jenkins/jenkins)
- [Configuración de agentes SSH](https://www.jenkins.io/doc/book/using/using-agents/)

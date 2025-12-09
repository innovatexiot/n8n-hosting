# Carpeta `nginx`

Este repositorio agrupa las configuraciones de Nginx para los distintos sitios de Innovatex. A continuación encontrarás las instrucciones para añadir un nuevo sitio y habilitarlo en el servidor.

---

## Estructura del repositorio

```
/                    # raíz del proyecto
├─ nginx/            # configuraciones Nginx
│   ├─ README.md     # este documento
│   ├─ sitio1.conf   # configs de ejemplo
│   ├─ sitio2.conf
│   └─ ...
└─ ...               # otros módulos/proyectos
```

Cada `.conf` en `nginx/` representa un bloque `server` de Nginx para un dominio o puerto específico.

---

## 1. Crear el archivo de configuración

1. En tu máquina local, copia uno de los ejemplos:

   ```bash
   cp nginx/ejemplo.conf nginx/mi-nuevo-sitio.conf
   ```

2. Abre `nginx/mi-nuevo-sitio.conf` y ajusta:

   * `server_name` (p.ej. `midominio.com` o IP)
   * `listen` (443, 8443, u otro puerto SSL)
   * Rutas de `ssl_certificate` y `ssl_certificate_key` si aplica
   * `proxy_pass` hacia el puerto o backend correspondiente (p.ej. `http://127.0.0.1:1001`)

3. Haz commit y push de tu nuevo archivo:

   ```bash
   git add nginx/mi-nuevo-sitio.conf
   git commit -m "Agrega configuración Nginx para mi-nuevo-sitio"
   git push origin feature/mi-nuevo-sitio
   ```

---

## 2. Habilitar el sitio en el servidor

> **Nota:** asumimos que el repositorio está desplegado en `/home/info/repos/tu-proyecto`.

1. Conéctate por SSH al servidor.
2. Copia el `.conf` a `sites-available`:

   ```bash
   sudo cp /home/info/repos/tu-proyecto/nginx/mi-nuevo-sitio.conf \
     /etc/nginx/sites-available/mi-nuevo-sitio.conf
   ```
3. Crea el enlace simbólico en `sites-enabled`:

   ```bash
   sudo ln -s /etc/nginx/sites-available/mi-nuevo-sitio.conf \
     /etc/nginx/sites-enabled/mi-nuevo-sitio.conf
   ```
4. (Opcional) Si existía un enlace viejo, elimínalo primero:

   ```bash
   sudo rm /etc/nginx/sites-enabled/mi-nuevo-sitio.conf
   sudo ln -s /etc/nginx/sites-available/mi-nuevo-sitio.conf \
     /etc/nginx/sites-enabled/
   ```

---

## 3. Probar y recargar Nginx

1. Verifica la sintaxis:

   ```bash
   sudo nginx -t
   ```
2. Si todo es correcto, recarga el servicio:

   ```bash
   sudo systemctl reload nginx
   ```

---

## 4. Verificar la disponibilidad

* Abre en tu navegador `https://midominio.com` (o `https://IP:PUERTO_SSL`).
* Asegúrate de que el certificado sea válido o acepta el autosignado la primera vez.

---

## Servicios configurados

### Dokploy (`dokploy.conf`)
- **Dominio**: `https://dokploy.innovatexiot.com`
- **Backend**: `http://127.0.0.1:3000` (Dokploy corriendo en Docker)
- **Características**:
  - SSL completo con Let's Encrypt
  - Proxy reverso con headers de seguridad
  - Soporte para WebSockets
  - Configuración optimizada para aplicaciones en tiempo real
  - Headers específicos para URL externa (Origin, Referer)

**Configuración requerida:**
1. **Variables de entorno en Dokploy** (docker-compose.yml):
   ```yaml
   - DOKPLOY_URL=https://dokploy.innovatexiot.com
   - APP_URL=https://dokploy.innovatexiot.com
   - BASE_URL=https://dokploy.innovatexiot.com
   ```

2. **Archivo .env**: Copia `.env.example` a `.env` y configura las credenciales

3. **Configuración SSL**:
   ```bash
   # Ejecutar el script incluido para configurar SSL
   ./setup-dokploy-ssl.sh
   ```

**¿Por qué es importante configurar la URL externa?**
Dokploy necesita saber su URL externa para:
- Generar enlaces absolutos correctos
- Configurar redirecciones
- Mostrar la URL correcta en la interfaz
- Funcionar correctamente detrás de un proxy reverso

---

## Convenciones y buenas prácticas

* **Nombre de archivo**: debe coincidir con `server_name` para facilitar la gestión.
* **Indentación**: usa 4 espacios para directivas internas.
* **Certificados**:

  * Para dominios reales, utiliza Certbot: `sudo certbot --nginx -d midominio.com`.
  * Para IPs, genera un certificado autosignado con SAN de IP.
* **Seguridad**: revisa siempre `ssl_protocols`, `ssl_ciphers` y encabezados HSTS si aplica.

---

Con esto podrás agregar, habilitar y mantener múltiples sitios en un solo repositorio con orden y consistencia. ¡Éxitos!

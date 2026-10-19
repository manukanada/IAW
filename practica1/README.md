#Practica 1
#FASE 1: Diseño del servidor apache
#1. Diseño y Requisitos
El primer dominio se llamará catlynx porque lynx es el nombre de mi gato y
el segundo se llamará nodisknobuy porque hace referencia a la protesta de la
eliminación del formato físico por parte de PlayStation.
El MPM que he elegido para este proyecto es event porque, además de trabajar con procesos e 
hilos como worker, incluye la gestión de conexiones inactivas a hilos dedicados
esto lo hace más eficiente y recomendado en producción moderna, por eso también
es el que viene activado por defecto.

#2. Estructura del proyecto
La estructura del servidor-apache es:

servidor-apache/
├── apache/
│   ├── Dockerfile
│   └── sites/
│       ├── 000-default-local.conf
│       ├── catlynx.conf
│       └── nodisknobuy.conf
├── web/
│   ├── catlynx/
│   │   ├── index.html
│   │   └── documentacion.info
│   └── nodisknobuy/
│       ├── index.html
│       └── physical-release.info
├── docker-compose.yml
└── README.md


#3. Dockerfile
He utilizado Docker Compose para ejecutar Apache dentro de un contenedor.
Para eso antes creamos el dockerfile de apache.
Se ha utilizado Ubuntu 24.04 como imagen base y se ha instalado Apache2.

    FROM ubuntu:24.04

    RUN apt update && apt install -y apache2

    COPY sites/ /etc/apache2/sites-available/

    RUN a2dissite 000-default.conf && \
        a2ensite 000-default-local.conf && \
        a2ensite catlynx.conf && \
        a2ensite nodisknobuy.conf

    CMD ["apachectl", "-D", "FOREGROUND"]

La línea COPY, copia las configuraciones de los Virtual Host al contenedor,
a2dissite desactiva el sitio predeterminado original de Apache y
a2ensite habilita los tres Virtual Hosts del proyecto.
CMD iniciar apache en primer plano para que Docker pueda controlar el proceso.

#4. Creación del Docker-Compose

El archivo docker-compose.yml utiliza el puerto 8055 del equipo y lo conecta con el 
puerto 80 del contenedor:

    services:
      apache:
        build: ./apache
        container_name: servidor-apache
        ports:
          - "8055:80"
        volumes:
          - ./web/catlynx:/var/www/catlynx:ro
          - ./web/nodisknobuy:/var/www/nodisknobuy:ro
        restart: unless-stopped

Los directorios de las páginas web se montan como volúmenes de solo lectura:read-only.
Esto permite modificar los archivos de la página desde el equipo sin tener que reconstruir
la imagen de Docker.
La opción restart permite al contenedor reiniciarse si se detiene.

### 5.1. Virtual Host de Catlynx

El archivo utilizado para configurarlo es `apache/sites/catlynx.conf`.

Este Virtual Host utiliza `catlynx.local` como nombre principal y el directorio
`/var/www/catlynx` como raíz de la página web.

Incluye una regla para impedir el acceso al archivo confidencial o sensible, llamado
`documentacion.info`.
### 5.2. Virtual Host de NoDiskNoBuy

El archivo utilizado para configurarlo es `apache/sites/nodisknobuy.conf`.

Este Virtual Host utiliza `nodisknobuy.local` como nombre principal y el directorio 
`/var/www/nodisknobuy` como raíz de la página web.

Incluye una regla para impedir el acceso al archivo confidencial o sensible, en este caso,
`physical-release.info`.

## 6. Seguridad de las páginas web

### 6.1. Protección del archivo sensible

Por ejemplo, en NoDiskNoBuy se ha creado el archivo `physical-release.info`, que simula
información que no debe ser accesible públicamente.

Para impedir su acceso, se ha utilizado la siguiente configuración en el Virtual Host de 
NoDiskNoBuy:

```apache
<Files "physical-release.info">
    Require all denied
</Files>
```

La línea `Require all denied` deniega las peticiones HTTP dirigidas a ese archivo.

Cuando se intenta acceder a él, Apache devuelve el código HTTP `403 Forbidden`, que indica 
que el servidor ha recibido la petición, pero deniega el acceso al recurso solicitado.

### 6.2. Desactivación del listado de directorios

En los Virtual Hosts se utiliza la directiva:

```apache
Options -Indexes
```

Esta opción impide que Apache genere automáticamente un listado de archivos cuando se 
solicita un directorio que no dispone de un documento de índice válido.

Así se evita mostrar automáticamente la estructura y los nombres de los archivos de la 
página web.

## 7. Virtual Host predeterminado

Se ha creado el archivo `apache/sites/000-default-local.conf`.

Su objetivo es controlar las peticiones cuyo dominio no coincide con ninguna de los dos
virtual hosts creados. Se ha elegido devolver `403 Forbidden`.

Esto se hace para que cuando la petición cuyo dominio no coincida no se diriga
al primer Virtual Hosts que encuentre por defecto.

## 8. Pruebas de funcionamiento con curl

Para comprobar el funcionamiento del servidor, se realizan peticiones utilizando `curl` 
y especificando explícitamente la cabecera HTTP `Host`.

En la configuración inicial de esta fase, Apache está publicado en el puerto 8055 del equipo.

### 8.1. Comprobación de Catlynx

Comando utilizado:

```bash
curl -i -H "Host: catlynx.local" http://localhost:8055/
```

La opción `-H` permite especificar manualmente la cabecera `Host`.

Apache identifica el dominio `catlynx.local` y devuelve el contenido de la página de Catlynx.

### 8.2. Comprobación de NoDiskNoBuy

Comando utilizado:

```bash
curl -i -H "Host: nodisknobuy.local" http://localhost:8055/
```

Apache identifica el dominio `nodisknobuy.local` y devuelve el contenido de 
la página de NoDiskNoBuy.

### 8.3. Comprobación del archivo sensible

Comando utilizado:

```bash
curl -i -H "Host: nodisknobuy.local" http://localhost:8055/physical-release.info
```

El resultado esperado es:

```text
HTTP/1.1 403 Forbidden
```

Esto demuestra que Apache deniega el acceso al archivo protegido.

### 8.4. Comprobación del dominio predeterminado

Comando utilizado:

```bash
curl -i -H "Host: desconocido.local" http://localhost:8055/
```

El resultado esperado es:

```text
HTTP/1.1 403 Forbidden
```

Esto demuestra que las peticiones a dominios desconocidos reciben la respuesta definida en 
el Virtual Host predeterminado.

# Fase 2: HTTPS y seguridad con Nginx
## 1. Certificado HTTPS

He creado un certificado autofirmado utilizando OpenSSL.
Este certificado permite que Nginx utilice HTTPS para proteger
la comunicación entre el navegador y el servidor.

He utilizado una clave ECDSA con la curva prime256v1.

Crear una clave privada ECDSA utilizando la curva `prime256v1`:

```bash
openssl ecparam -genkey -name prime256v1 -noout -out nginx/certs/nimbusdocs.key
```

Crear el certificado autofirmado.
```bash
openssl req -new -x509 \
  -key nginx/certs/nimbusdocs.key \
  -out nginx/certs/nimbusdocs.crt \
  -days 365 \
  -subj "/CN=catlynx.local" \
  -addext "subjectAltName=DNS:catlynx.local,DNS:www.catlynx.local,DNS:nodisknobuy.local,DNS:www.nodisknobuy.local"
```

Consultar los datos del certificado:

```bash
openssl x509 -in nginx/certs/nimbusdocs.crt -text -noout
```

El certificado tiene como nombre común (CN) `catlynx.local`.
También incluye los nombres de los dominios de CatLynx y NoDiskNoBuy.

El certificado es autofirmado porque lo hemos creado nosotros,
en lugar de obtenerlo de una entidad certificadora reconocida.
Por eso, el navegador puede mostrar una advertencia de seguridad.

## 2. Redirección de HTTP a HTTPS
Hemos configurado Nginx para redirigir automáticamente las peticiones HTTP al mismo
dominio mediante HTTPS:

```nginx
server {
    listen 80;
    server_name catlynx.local www.catlynx.local
                nodisknobuy.local www.nodisknobuy.local;

    return 301 https://$host$request_uri;
}
```

Comprobar que CatLynx redirige las peticiones HTTP:

```bash
curl -I -H "Host: catlynx.local" http://localhost/
```

Comprobar que NoDiskNoBuy también redirige las peticiones HTTP:

```bash
curl -I -H "Host: nodisknobuy.local" http://localhost/
```

Hemos configurado Nginx para que las peticiones que llegan por
HTTP se redirijan automáticamente a HTTPS.

Utilizamos el código HTTP 301, que indica que la dirección se
ha trasladado permanentemente.

Esto ayuda a que los usuarios accedan a la versión segura de la web.

En nuestro proyecto, Nginx utiliza el puerto 80 para HTTP y el
puerto 8443 del ordenador para HTTPS.

### 3. Reenvío de peticiones a Apache

Nginx actúa como proxy inverso y reenvía las peticiones al servidor Apache mediante:

```nginx
location / {
    proxy_pass http://apache:80;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

La directiva `proxy_set_header Host $host;` conserva el dominio solicitado por el cliente.

Esto es necesario porque Apache utiliza VirtualHosts para distinguir entre CatLynx y NoDiskNoBuy. Si Nginx no transmite el dominio original, Apache puede recibir un nombre incorrecto y responder con la página del VirtualHost predeterminado en lugar de la web solicitada.

Para comprobarlo, primero hemos probado la configuración sin la directiva `proxy_set_header Host $host;` y hemos observado el resultado. Después la hemos añadido y hemos repetido la prueba para verificar que Apache responde con la web correspondiente al dominio solicitado.

Comprobación de CatLynx:

```bash
curl -k --resolve catlynx.local:8443:127.0.0.1 https://catlynx.local:8443/
```

Comprobación de NoDiskNoBuy:

```bash
curl -k --resolve nodisknobuy.local:8443:127.0.0.1 https://nodisknobuy.local:8443/
```

La opción `--resolve` permite probar los dominios desde el ordenador local. La opción `-k` permite realizar las pruebas con nuestro certificado autofirmado.

## 4. Versiones de TLS y cifrados

TLS es el protocolo que protege la información que se envía
entre el navegador y el servidor mediante HTTPS.

Hemos configurado Nginx para permitir únicamente TLS 1.2 y TLS 1.3.
Las versiones anteriores están deshabilitadas.

Hemos comprobado la configuración utilizando OpenSSL.
```bash
openssl s_client -connect localhost:8443 -servername catlynx.local -tls1_2
```

Comprobar la conexión utilizando TLS 1.3:

```bash
openssl s_client -connect localhost:8443 -servername catlynx.local -tls1_3
```
Los resultados del protocolo han sido:

- TLS 1.2: ECDHE-ECDSA-AES256-GCM-SHA384
- TLS 1.3: TLS_AES_256_GCM_SHA384

Ambas versiones han permitido establecer una conexión correctamente.


```nginx
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
```

Hemos elegido estos cifrados porque utilizan ECDHE para el intercambio de claves, ECDSA para la autenticación y AES-GCM para proporcionar confidencialidad e integridad.

TLS 1.3 utiliza un conjunto de cifrados diferente, por lo que la directiva `ssl_ciphers`
no controla sus cifrados. En nuestras pruebas se ha negociado `TLS_AES_256_GCM_SHA384`.

## 5. Nginx como proxy inverso

Nginx recibe las peticiones de los usuarios y las envía a Apache,
que es el servidor donde se encuentran las páginas web.

De esta manera, los usuarios acceden a Nginx y Apache queda detrás,
sin publicar directamente su puerto en el ordenador.

Hemos utilizado la siguiente configuración:

    proxy_pass http://apache:80;

También hemos añadido:

    proxy_set_header Host $host;

Esta segunda instrucción es importante porque conserva el dominio
que ha solicitado el usuario.

Al principio, sin esta instrucción, Apache devolvía un error 403.
Esto ocurría porque recibía una petición sin el dominio original
y seleccionaba el VirtualHost predeterminado.

Después de añadir la instrucción, Apache pudo identificar el
dominio correctamente y CatLynx respondió con el código 200 OK.

## 6. Cabeceras de seguridad

Hemos añadido tres cabeceras de seguridad en Nginx.

### Strict-Transport-Security

Indica al navegador que utilice HTTPS durante el tiempo indicado,
en este caso, un año.

### X-Content-Type-Options: nosniff

Evita que el navegador intente interpretar los archivos como
un tipo de contenido diferente del que indica el servidor.

### X-Frame-Options: DENY

Impide que nuestra página se muestre dentro de un iframe de otra
página, ayudando a prevenir ataques de clickjacking.

Hemos comprobado que las tres cabeceras aparecen en las respuestas
HTTPS de nuestro servidor.

## 7. Limitación de peticiones

Hemos configurado un límite de peticiones en Nginx para reducir
el impacto de clientes que realizan demasiadas solicitudes.

En `nginx.conf`, dentro del bloque `http`, hemos configurado:

```nginx
limit_req_zone $binary_remote_addr zone=nimbus_limit:10m rate=3r/s;
```

En el bloque `server` HTTPS de `default.conf`, hemos añadido:

```nginx
limit_req zone=nimbus_limit burst=6 nodelay;
```
La configuración utiliza estos valores:

- Tasa: 3 peticiones por segundo.
- Ráfaga: 6 peticiones adicionales.
- Memoria de la zona: 10 MB.
- nodelay: permite procesar inmediatamente las peticiones que
  caben dentro de la ráfaga.

La tasa limita el ritmo de las peticiones. La ráfaga permite
aceptar varias solicitudes seguidas sin rechazarlas inmediatamente.

Hemos realizado tres pruebas:

| Prueba | Peticiones | HTTP 200 | HTTP 503 |
|---|---:|---:|---:|
| Uso normal, aproximadamente 3 peticiones/s | 15 | 15 | 0 |
| Ráfaga de peticiones | 6 | 6 | 0 |
| Envío rápido de 30 peticiones | 30 | 7 | 23 |

En la primera prueba, todas las peticiones fueron aceptadas.

En la segunda prueba, también se aceptaron las seis peticiones
seguidas gracias a la ráfaga permitida.

En la última prueba, 23 peticiones fueron rechazadas porque se
superó el límite configurado.

El código 503 indica que el servidor no ha atendido esas peticiones.
Es el código que utiliza Nginx por defecto cuando se supera este límite.

Con estas pruebas hemos comprobado que la configuración permite
el uso normal de la web y rechaza muchas peticiones cuando se
envían demasiado rápido.

#FASE 3: Diagnóstico y soluciones

#PROBLEMA 1: Fallo en la protección de un archivo de Apache

#Síntoma observado:
El archivo physical-release.info devuelve 200 OK en lugar de 403 Forbidden.

#Hipótesis inicial:
La protección del archivo en el VirtualHost de Apache podría estar mal configurada.

#Comando de diagnóstico usado:
curl -k -I --resolve nodisknobuy.local:8443:127.0.0.1 https://nodisknobuy.local:8443/physical-release.info

#Causa real y solución:
Se cambió Require all denied por Require all granted, permitiendo el acceso al
archivo. Se restauró Require all denied,
se reconstruyó el contenedor con docker compose up -d --build apache y
se comprobó que el archivo volvía a devolver 403 Forbidden.


#PROBLEMA 2: Fallo en el límite de peticiones de Nginx

#Síntoma observado:
Nginx acepta peticiones rápidas sin aplicar el límite de solicitudes configurado.

#Hipótesis inicial:
La limitación de peticiones podría no estar aplicada al servidor HTTPS.

#Comando de diagnóstico usado:
Se enviaron 30 peticiones rápidas mediante un bucle for con curl, comprobando los
códigos HTTP devueltos.

#Causa real y solución:
Se comentó la directiva limit_req zone=nimbus_limit burst=6 nodelay;, por lo que Nginx
dejó de aplicar el límite. Se restauró la directiva, se comprobó la sintaxis 
con docker compose exec nginx nginx -t y se recargó la configuración con
docker compose exec nginx nginx -s reload.

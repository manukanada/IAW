#Practica 1
#FASE 1: Diseño del servidor apache
#1. Diseño y Requisitos
El primer dominio se llamará catlynx porque lynx es el nombre de mi gato y
el segundo se llamará nodisknobuy porque hace referencia a la protesta de la
eliminación del formato físico por parte de PlayStation.
El MPM más recomendado es event porque además de trabajar con procesos e 
hilos como worker, incluye la gestión de conexiones inactivas a hilos dedicados.

#2. Estructura del proyecto

La estructura del proyecto es:

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

#3. Configuración de Docker Compose

Se ha utilizado Docker Compose para ejecutar Apache dentro de un contenedor.

El archivo docker-compose.yml utiliza el puerto 8055 del equipo y lo conecta con el puerto 80 del contenedor:

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

Los directorios de las páginas web se montan como volúmenes de solo lectura. Esto permite modificar los archivos de la página desde el equipo sin tener que reconstruir la imagen de Docker.

#4. Dockerfile
Se ha utilizado Ubuntu 24.04 como imagen base y se ha instalado Apache2.

    FROM ubuntu:24.04

    RUN apt update && apt install -y apache2

    COPY sites/ /etc/apache2/sites-available/

    RUN a2dissite 000-default.conf && \
        a2ensite 000-default-local.conf && \
        a2ensite catlynx.conf && \
        a2ensite nodisknobuy.conf

    CMD ["apachectl", "-D", "FOREGROUND"]


# Fase 2: HTTPS y seguridad con Nginx
## 1. Certificado HTTPS

Hemos creado un certificado autofirmado utilizando OpenSSL.
Este certificado permite que Nginx utilice HTTPS para proteger
la comunicación entre el navegador y el servidor.

Hemos utilizado una clave ECDSA con la curva prime256v1.

El certificado tiene como nombre común (CN) `catlynx.local`.
También incluye los nombres de los dominios de CatLynx y NoDiskNoBuy.

El certificado es autofirmado porque lo hemos creado nosotros,
en lugar de obtenerlo de una autoridad certificadora reconocida.
Por eso, el navegador puede mostrar una advertencia de seguridad.

## 2. Redirección de HTTP a HTTPS

Hemos configurado Nginx para que las peticiones que llegan por
HTTP se redirijan automáticamente a HTTPS.

Utilizamos el código HTTP 301, que indica que la dirección se
ha trasladado permanentemente.

Esto ayuda a que los usuarios accedan a la versión segura de la web.

En nuestro proyecto, Nginx utiliza el puerto 80 para HTTP y el
puerto 8443 del ordenador para HTTPS.

## 3. Versiones de TLS y cifrados

TLS es el protocolo que protege la información que se envía
entre el navegador y el servidor mediante HTTPS.

Hemos configurado Nginx para permitir únicamente TLS 1.2 y TLS 1.3.
Las versiones anteriores están deshabilitadas.

Hemos comprobado la configuración utilizando OpenSSL.

Los resultados han sido:

- TLS 1.2: ECDHE-ECDSA-AES256-GCM-SHA384
- TLS 1.3: TLS_AES_256_GCM_SHA384

Ambas versiones han permitido establecer una conexión correctamente.

OpenSSL muestra el error de verificación 18 porque el certificado
es autofirmado. Esto significa que no confía automáticamente en
el certificado, pero no significa que la conexión TLS haya fallado.

## 4. Nginx como proxy inverso

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

## 5. Cabeceras de seguridad

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

## 6. Limitación de peticiones

Hemos configurado un límite de peticiones en Nginx para reducir
el impacto de clientes que realizan demasiadas solicitudes.

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

#Practica 1
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

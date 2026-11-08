# Batería UD4 (PHP-FPM) — PHP 8.3 FPM, IAW ASIR 2.º (la misma imagen que el laboratorio de clase)
# Imagen oficial + procps (para ver los workers con ps) + OPcache activado (viene compilado, no activo).
FROM php:8.3-fpm
RUN apt-get update && apt-get install -y --no-install-recommends procps nano \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-enable opcache

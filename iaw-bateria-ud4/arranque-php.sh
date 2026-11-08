#!/bin/sh
# Arranque del contenedor «php»: enlaza tu pool (no se monta el fichero suelto: un editor cambia el inodo al guardar).
set -e
ln -sf /lab/php/zz-bateria-pool.conf /usr/local/etc/php-fpm.d/zz-bateria-pool.conf
mkdir -p /var/log/lab && chmod 777 /var/log/lab
touch /var/log/lab/php-lento.log && chmod 644 /var/log/lab/php-lento.log
exec php-fpm

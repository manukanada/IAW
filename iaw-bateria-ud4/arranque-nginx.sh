#!/bin/sh
set -e
ln -sf /etc/nginx/sites-available/cafeteria.conf /etc/nginx/sites-enabled/cafeteria.conf
exec nginx -g 'daemon off;'

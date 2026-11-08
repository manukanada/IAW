#!/usr/bin/env bash
# Batería UD4 · La cafetería del instituto (Nginx + PHP-FPM). El mando a distancia: no hace falta escribir órdenes de Docker.
#   ./bateria.sh arrancar          levanta la cafetería (la primera vez tarda: descarga las imágenes)
#   ./bateria.sh comprobar [N]     comprueba todo, o solo el bloque N, con pistas
#   ./bateria.sh recargar          aplica tus cambios: nginx -t + recarga Nginx, y reinicia PHP
#   ./bateria.sh probar 'CÓDIGO'   ejecuta una línea de PHP (para las predicciones del bloque 2)
#   ./bateria.sh logs              las últimas líneas de los logs (Nginx y PHP)
#   ./bateria.sh parar             lo apaga todo
set -uo pipefail
cd "$(dirname "$0")"
V=$'\e[32m'; R=$'\e[31m'; N=$'\e[1m'; X=$'\e[0m'

command -v docker >/dev/null 2>&1 || { echo "${R}✘ No encuentro Docker.${X} Es el mismo de la práctica 1: instálalo (o arranca Docker Desktop) y vuelve a probar."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "${R}✘ Docker no responde.${X} ¿Está arrancado? (en Linux: sudo systemctl start docker)"; exit 1; }

case "${1:-ayuda}" in
  arrancar)
    docker compose up -d --build || exit 1
    echo
    echo "${V}✔ La cafetería está abierta:${X} https://localhost:8447  (el certificado es de prueba: acepta el aviso)"
    echo "  Ahora: ${N}./bateria.sh comprobar${X}  (al principio, solo los ejemplos 👀 en verde: 5 de 40)" ;;
  comprobar)
    bash comprobador/comprobar.sh "${2:-}" ;;
  recargar)
    docker compose exec -T nginx nginx -t && docker compose exec -T nginx nginx -s reload && echo "${V}✔ Nginx recargado${X}" || exit 1
    docker compose exec -T php php-fpm -t && docker compose restart php >/dev/null && echo "${V}✔ PHP reiniciado${X}" ;;
  probar)
    [ -n "${2:-}" ] || { echo "Uso: ./bateria.sh probar 'var_dump(\"5\" == 5);'"; exit 1; }
    docker compose exec -T php php -r "$2"; echo ;;
  logs)
    for f in logs/cafeteria_error.log logs/php-errores.log logs/php-lento.log; do
      [ -s "$f" ] && { echo "${N}── $f${X}"; tail -n 8 "$f"; }
    done
    echo "${N}── docker compose logs php${X}"; docker compose logs --tail 8 php ;;
  parar)
    docker compose down ;;
  *)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' ;;
esac

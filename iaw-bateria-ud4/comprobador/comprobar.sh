#!/usr/bin/env bash
# Comprobador de la batería UD4 (la cafetería del instituto). Se lanza con: ./bateria.sh comprobar [N]
# Todo se comprueba DESDE LOS CONTENEDORES: curl desde «cliente» (como un usuario) y ini_get / php-fpm -tt desde «php».
# No da la solución: dice qué caso falla, qué ha salido y, si es una trampa conocida, cuál es.
set -u   # sin pipefail: «… | grep -q» corta la tubería al encontrar y daría falsos fallos
cd "$(dirname "$0")/.."
SOLO=${1:-}
URL=https://cafeteria.iaw.local
AYUDA=$(cat comprobador/ayuda.php)

V=$'\e[32m'; R=$'\e[31m'; A=$'\e[33m'; G=$'\e[90m'; N=$'\e[1m'; X=$'\e[0m'

# ── Acceso a los contenedores ────────────────────────────────────────────────
web()     { docker compose exec -T cliente curl -sk --max-time 12 "$@" 2>/dev/null; }
codigo()  { web -o /dev/null -w '%{http_code}' "$@"; }
cabeceras() { web -o /dev/null -D - "$@" | tr -d '\r'; }
ini()     { docker compose exec -T php php -r "echo ini_get('$1');" 2>/dev/null; }
fpm()     { docker compose exec -T php php-fpm -tt 2>&1 | sed -n 's/.*NOTICE:[[:space:]]*//p' | tr -s ' \t' ' '; }
ayuda()   { docker compose exec -T php php -r "$AYUDA" -- "$@" 2>/dev/null; }
en_php()  { docker compose exec -T php sh -c "$1" 2>/dev/null; }

# ── 0 · Que esté arrancado, y aplicar tus cambios (igual que ./bateria.sh recargar) ──
if ! docker compose ps --status running -q cliente 2>/dev/null | grep -q .; then
    echo "${R}✘ La batería no está arrancada.${X} Primero: ${N}./bateria.sh arrancar${X}"; exit 1
fi
if ! salida=$(docker compose exec -T nginx nginx -t 2>&1); then
    echo "${R}✘ cafeteria.conf tiene un error y Nginx no lo acepta (nginx -t):${X}"
    grep -E 'emerg|error' <<<"$salida" | sed 's/^/    /'
    echo "  ${A}💡 La línea que falla viene al final del mensaje («in …cafeteria.conf:NN»). Suele ser un «;» o una «}» que falta.${X}"
    exit 1
fi
docker compose exec -T nginx nginx -s reload >/dev/null 2>&1
if ! salida=$(docker compose exec -T php php-fpm -t 2>&1); then
    echo "${R}✘ zz-bateria-pool.conf tiene un error y PHP-FPM no arrancaría (php-fpm -t):${X}"
    grep -E 'ERROR|error' <<<"$salida" | sed 's/^/    /'
    exit 1
fi
docker compose restart php >/dev/null 2>&1
for _ in 1 2 3 4 5 6 7 8 9 10; do en_php 'kill -0 1' && break; sleep 0.5; done
sleep 1
echo "${G}→ nginx -t ✔ · Nginx recargado · PHP reiniciado (lo mismo que ./bateria.sh recargar)${X}"

# ── Resultados ────────────────────────────────────────────────────────────────
ok=0; total=0; bok=0; btot=0; primero_dado=0
MSG=""; TRAMPA=""
declare -A EMPEZAR=(
  [1.3]="Un bloque «location ~ \\.php\$ { … }» dentro del server de 443, con las cinco líneas del apartado 2.1 de la UD4."
  [1.4]="Antes de pasarle nada a PHP, comprueba que el fichero existe: try_files."
  [2.1]="Un foreach (\$platos as \$p) que escriba un <li> con \$p['nombre'] y el precio."
  [2.2]="number_format(\$x, 2, ',', '.') y después « €»."
  [2.3]="array_column(\$platos, 'precio') te da solo los precios; array_sum los suma."
  [2.4]="array_filter(\$platos, fn(\$p) => …) y otro foreach igual que el de la carta."
  [3.1]="Mira \$_SERVER['REQUEST_METHOD'] arriba del todo, antes de leer nada del formulario."
  [3.2]="filter_var(\$_POST['cantidad'] ?? '', FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => 5]]) devuelve false si no vale."
  [3.3]="Un foreach por \$platos comparando \$p['nombre'] con lo que llega; si no aparece, \$elegido se queda en null."
  [3.4]="if (\$errores) { http_response_code(422); } else { \$hecho = true; }"
  [3.5]="Todo lo que escribió el usuario, al imprimirlo, pasa por e()."
  [3.6]="Junta 3.2, 3.3 y 3.4: con datos buenos tiene que salir el pedido y su total."
  [4.2]="Una línea: expose_php = …"
  [4.3]="Dos líneas: display_errors y display_startup_errors."
  [4.4]="Dos líneas: log_errors y error_log (la ruta del enunciado)."
  [4.5]="disable_functions = y la lista separada por comas, sin espacios."
  [4.6]="upload_max_filesize y post_max_size."
  [4.7]="session.cookie_httponly = 1"
  [5.2]="pm = dynamic y las cuatro líneas pm.max_children, pm.start_servers, pm.min_spare_servers y pm.max_spare_servers. La cuenta: (512 − 112) ÷ 40."
  [5.3]="pm.status_path en el pool, y en cafeteria.conf un «location = /estado-fpm» con allow para las redes privadas, deny all y fastcgi_pass."
  [5.4]="request_slowlog_timeout y slowlog en el pool."
  [5.5]="location = /info.php { deny all; }"
  [5.6]="location ^~ /inc/ { deny all; }"
  [6.1]="header('Content-Type: application/json; charset=utf-8'); antes de escribir nada."
  [6.2]="echo json_encode(['platos' => \$platos], JSON_UNESCAPED_UNICODE);"
  [6.3]="if ((\$_GET['veg'] ?? '') === '1') { … array_values(array_filter(…)) … }"
  [6.4]="Igual que el 3.1, pero solo GET, y el error también en JSON."
)

bloque() {  # bloque N "título"
    cierre_bloque
    ACTUAL=$1
    if [ -z "$SOLO" ] || [ "$SOLO" = "$1" ]; then echo; echo "${N}Bloque $1 · $2${X}"; fi
}
cierre_bloque() {
    if [ -n "${ACTUAL:-}" ] && { [ -z "$SOLO" ] || [ "$SOLO" = "$ACTUAL" ]; }; then
        echo "  ${G}— bloque $ACTUAL: $bok de $btot${X}"
    fi
    bok=0; btot=0
}
check() {  # check ID TIPO "nombre" funcion
    local id=$1 tipo=$2 nombre=$3; shift 3
    [ -n "$SOLO" ] && [ "$SOLO" != "$ACTUAL" ] && return 0
    total=$((total+1)); btot=$((btot+1)); MSG=""; TRAMPA=""
    if "$@"; then
        ok=$((ok+1)); bok=$((bok+1)); printf '  %s✔%s %-4s %s %s\n' "$V" "$X" "$id" "$tipo" "$nombre"
    else
        printf '  %s✘%s %-4s %s %s\n' "$R" "$X" "$id" "$tipo" "$nombre"
        [ -n "$MSG" ] && printf '         %s\n' "$MSG"
        [ -n "$TRAMPA" ] && printf '         %s⚠️  Error típico: %s%s\n' "$A" "$TRAMPA" "$X"
        if [ -n "${EMPEZAR[$id]:-}" ] && { [ -n "$SOLO" ] || [ "$primero_dado" = 0 ]; }; then
            printf '         %s💡 Para empezar: %s%s\n' "$A" "${EMPEZAR[$id]}" "$X"
            [ -z "$SOLO" ] && primero_dado=1
        fi
    fi
}
pred() {  # pred ID esperado "por qué"
    local id=$1 esperado=$2 porque=$3 resp norm
    resp=$(sed -n "s/^${id//./\\.}[[:space:]]*=[[:space:]]*//p" predicciones.txt 2>/dev/null | head -1)
    norm=$(tr '[:upper:]' '[:lower:]' <<<"$resp" | tr -d " '\"\r" | sed 's/vacio/vacío/; s/^(vacío)$/vacío/; s/^nada$/vacío/')
    if [ -z "$norm" ]; then MSG="Sin contestar: escribe tu respuesta en predicciones.txt, después de «$id =»."; return 1; fi
    if [ "$norm" = "$esperado" ]; then
        [ -n "$SOLO" ] && MSG_OK="$porque"
        return 0
    fi
    MSG="Has puesto «$resp»: no es eso."
    [ -n "$SOLO" ] && MSG="$MSG $porque"
    return 1
}
check_pred() {  # check_pred ID "pregunta" esperado "por qué"
    local id=$1 nombre=$2 esperado=$3 porque=$4
    MSG_OK=""
    check "$id" "🔮" "$nombre" pred "$id" "$esperado" "$porque"
    [ -n "$MSG_OK" ] && printf '         %s%s%s\n' "$G" "$MSG_OK" "$X"
    return 0
}

# ═════════════ Bloque 1 · Nginx le pasa los .php a PHP-FPM ═════════════
INDEX=$(web "$URL/")
se_ejecuta() { grep -q 'te atiende PHP' <<<"$INDEX" && ! grep -q '<?php' <<<"$INDEX"; }
b1_ok()      { docker compose exec -T nginx nginx -t >/dev/null 2>&1; }
b1_301()     { local r; r=$(web -o /dev/null -w '%{http_code} %{redirect_url}' http://cafeteria.iaw.local/x); MSG="Ha salido: $r"; [[ $r == "301 https://cafeteria.iaw.local/x" ]]; }
b1_txt()     { web "$URL/hola.txt" | grep -q 'estático'; }
b1_php() {
    se_ejecuta && return 0
    local c; c=$(codigo "$URL/index.php")
    MSG="index.php ha dado el código $c."
    if grep -q '<?php' <<<"$INDEX"; then TRAMPA="se DESCARGA el código: Nginx no sabe que los .php van a PHP-FPM (¿falta el location ~ \\.php\$?)."
    elif grep -q 'File not found' <<<"$INDEX"; then TRAMPA="«File not found.»: PHP no sabe qué fichero ejecutar. Revisa SCRIPT_FILENAME."
    elif [ "$c" = 502 ]; then TRAMPA="502: el camarero llega a la cocina y no abre nadie. ¿fastcgi_pass apunta a php:9000?"
    fi
    return 1
}
b1_404() {
    se_ejecuta || { MSG="Primero tiene que ir el 1.3."; return 1; }
    local c cuerpo; c=$(codigo "$URL/noexiste.php"); cuerpo=$(web "$URL/noexiste.php")
    MSG="noexiste.php ha dado $c."
    if grep -q 'File not found' <<<"$cuerpo"; then TRAMPA="el 404 lo da PHP («File not found.»), no Nginx: le estás pasando a PHP ficheros que no existen. Falta try_files."; return 1; fi
    [ "$c" = 404 ]
}
bloque 1 "Nginx le pasa los .php a PHP-FPM"
check 1.0 "👀" "cafeteria.conf es válido (nginx -t)" b1_ok
check 1.1 "👀" "HTTP redirige a HTTPS (301)" b1_301
check 1.2 "👀" "hola.txt lo sirve Nginx, sin PHP" b1_txt
check 1.3 "✍️" "index.php se EJECUTA (no se descarga el código)" b1_php
check 1.4 "✍️" "Un .php que no existe da 404 de Nginx (try_files)" b1_404
check_pred 1.a "Sin la regla, pides index.php" descarga "Sin location ~ \\.php\$, Nginx trata el .php como un fichero cualquiera (application/octet-stream) y te entrega el código entero."
check_pred 1.b "Con la regla, pides noexiste.php" 404 "try_files \$uri =404 mira si el fichero existe antes de molestar a PHP: si no está, 404."
check_pred 1.c "PHP-FPM está parado" 502 "502 Bad Gateway: el camarero llega a la cocina y no abre nadie."
check_pred 1.d "Una página tarda 2 minutos" 504 "504 Gateway Timeout: la cocina contesta, pero más tarde de lo que espera Nginx (fastcgi_read_timeout, 60 s)."

# ═════════════ Bloque 2 · PHP: la carta ═════════════
CARTA=$(web "$URL/carta.php")
b2_lista() {
    se_ejecuta || { MSG="Necesita el bloque 1 (que los .php se ejecuten)."; return 1; }
    local l n; l=$(ayuda lis carta <<<"$CARTA"); n=$(grep -c . <<<"$l")
    [ "$l" = SIN_LISTA ] && { MSG="No encuentro <ul id=\"carta\">: no le cambies el id."; return 1; }
    MSG="En la carta salen $n platos (tiene que haber 6)."
    [ "$n" = 6 ] && [ "$(grep -c ' — ' <<<"$l")" = 6 ]
}
b2_euros() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local primero; primero=$(ayuda lis carta <<<"$CARTA" | head -1)
    MSG="El primer plato sale así: «$primero»."
    grep -qE '3\.2([^0-9]|$)' <<<"$primero" && TRAMPA="sale 3.2: sin number_format, PHP escribe el número tal cual."
    [ "$primero" = "Bocadillo de jamón — 3,20 €" ]
}
b2_total() { se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }; local t; t=$(ayuda texto total <<<"$CARTA"); MSG="Ha salido: «$t»."; [ "$t" = "Total de la carta: 19,70 €" ]; }
b2_veg() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local l n; l=$(ayuda lis vegetarianos <<<"$CARTA"); n=$(grep -c . <<<"$l")
    [ "$l" = SIN_LISTA ] && { MSG="No encuentro <ul id=\"vegetarianos\">."; return 1; }
    MSG="Salen $n platos vegetarianos (tiene que haber 4)."
    grep -qiE 'jamón|lomo' <<<"$l" && { TRAMPA="se cuelan platos con carne: ¿miras \$p['vegetariano']?"; return 1; }
    [ "$n" = 4 ]
}
bloque 2 "PHP: la carta"
check 2.1 "✍️" "La carta lista los 6 platos («nombre — precio»)" b2_lista
check 2.2 "✍️" "euros(): 3.2 → «3,20 €»" b2_euros
check 2.3 "✍️" "El total de la carta: 19,70 €" b2_total
check 2.4 "✍️" "Los vegetarianos: 4, sin carne" b2_veg
check_pred 2.a "var_dump(\"5\" == 5);" true "== compara el valor convirtiendo tipos: el texto «5» pasa a ser el número 5."
check_pred 2.b "echo 7 + \"3\";" 10 "+ siempre suma números: «3» se convierte en 3. Para unir textos, PHP usa el punto (.)."
check_pred 2.c "var_dump(0 === \"0\");" false "=== compara el valor Y el tipo: 0 es un número y «0» es un texto."
check_pred 2.d "echo \$_GET['nombre'] ?? ''; (sin ?nombre= en la URL)" vacío "Sin ?nombre= en la URL, \$_GET['nombre'] no existe y ?? pone ''. Sin el ??, PHP daría un Warning."

# ═════════════ Bloque 3 · El formulario y el XSS ═════════════
pedir() { web -X POST --data-urlencode "nombre=$1" --data-urlencode "plato=$2" --data-urlencode "cantidad=$3" --data-urlencode "comentario=$4" -w '\nCODIGO=%{http_code}' "$URL/pedido.php"; }
b3_metodo() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local h; h=$(cabeceras -X DELETE "$URL/pedido.php")
    local c; c=$(head -1 <<<"$h" | awk '{print $2}')
    MSG="Con DELETE ha dado $c$(grep -i '^allow:' <<<"$h" | sed 's/^/ y /')."
    [ "$c" = 405 ] && grep -qiE '^allow:.*get.*post|^allow:.*post.*get' <<<"$h"
}
b3_cantidad() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local v r
    for v in 9 0 abc 2.5; do
        r=$(pedir Ana "Tortilla de patatas" "$v" "")
        if ! grep -q 'La cantidad tiene que ser un número entero del 1 al 5.' <<<"$r"; then
            MSG="Con cantidad = «$v» no sale el aviso de la cantidad."; return 1
        fi
    done
}
b3_plato() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    pedir Ana "Caviar" 1 "" | grep -q 'Ese plato no está en la carta.' || { MSG="Con el plato «Caviar» no sale el aviso del plato."; return 1; }
}
b3_422() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local r c; r=$(pedir Ana "Caviar" 9 ""); c=$(sed -n 's/^CODIGO=//p' <<<"$r")
    MSG="Con datos malos ha dado el código $c."
    grep -q 'id="pedido"' <<<"$r" && { TRAMPA="con errores sigue saliendo «Pedido recibido»: \$hecho solo es true si no hay errores."; return 1; }
    [ "$c" = 422 ]
}
b3_xss() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local r; r=$(pedir "<script>alert(1)</script>" "Tortilla de patatas" 1 "<b>hola</b>")
    if grep -q '<script>alert(1)' <<<"$r"; then MSG="El nombre <script>… sale tal cual en la página."; TRAMPA="XSS: lo que escribe el usuario se imprime sin e()."; return 1; fi
    if grep -q '<b>hola</b>' <<<"$r"; then MSG="El comentario <b>hola</b> sale en negrita."; TRAMPA="XSS en el comentario: también pasa por e()."; return 1; fi
    grep -q '&lt;script&gt;' <<<"$r" && grep -q '&lt;b&gt;hola' <<<"$r" || { MSG="No veo el nombre y el comentario escapados (&lt;…) en el pedido."; return 1; }
}
b3_valido() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local r p t c; r=$(pedir Ana "Tortilla de patatas" 2 "sin sal")
    p=$(ayuda texto pedido <<<"$r"); t=$(ayuda texto total <<<"$r"); c=$(sed -n 's/^CODIGO=//p' <<<"$r")
    MSG="Ana pide 2 de tortilla: código $c · «$p» · «$t»."
    [ "$c" = 200 ] && [ "$p" = "Pedido recibido, Ana: 2 × Tortilla de patatas." ] && [ "$t" = "Total: 5,60 €" ]
}
bloque 3 "El formulario y el XSS"
check 3.1 "✍️" "Con DELETE: 405 y «Allow: GET, POST»" b3_metodo
check 3.2 "✍️" "Cantidad 9, 0, «abc» o 2.5: aviso de la cantidad" b3_cantidad
check 3.3 "✍️" "Un plato que no está en la carta: aviso" b3_plato
check 3.4 "✍️" "Con errores: código 422 y sin «Pedido recibido»" b3_422
check 3.5 "✍️" "Sin XSS: el nombre y el comentario salen escapados" b3_xss
check 3.6 "✍️" "Un pedido bueno: 2 × Tortilla de patatas = 5,60 €" b3_valido

# ═════════════ Bloque 4 · php.ini endurecido ═════════════
apagado() { case "$1" in ""|0|Off|off) return 0 ;; *) return 1 ;; esac; }
b4_mem() { local v; v=$(ini memory_limit); MSG="memory_limit vale «$v»."; [ "$v" = 128M ]; }
b4_expose() {
    local v; v=$(ini expose_php); MSG="expose_php vale «$v» (1 = On)."
    apagado "$v" || return 1
    if se_ejecuta && cabeceras "$URL/" | grep -qi '^x-powered-by'; then MSG="Sigue saliendo la cabecera X-Powered-By."; return 1; fi
}
b4_display() {
    local d s; d=$(ini display_errors); s=$(ini display_startup_errors)
    MSG="display_errors vale «$d» y display_startup_errors «$s»."
    apagado "$d" && apagado "$s" || return 1
    if se_ejecuta && web "$URL/error.php" | grep -qiE 'warning|fatal|precios-del-proveedor'; then MSG="error.php sigue enseñando el error al usuario."; return 1; fi
}
b4_log() {
    local l f; l=$(ini log_errors); f=$(ini error_log)
    MSG="log_errors vale «$l» y error_log «$f»."
    [ "$l" = 1 ] && [ "$f" = /var/log/lab/php-errores.log ] || return 1
    en_php ': > /var/log/lab/php-errores.log; chmod 666 /var/log/lab/php-errores.log'
    if se_ejecuta; then web "$URL/error.php" >/dev/null; else en_php 'php /var/www/cafeteria/error.php >/dev/null 2>&1'; fi
    sleep 0.5
    en_php 'grep -q precios-del-proveedor /var/log/lab/php-errores.log' || { MSG="El error de error.php no ha llegado a logs/php-errores.log."; return 1; }
}
b4_funciones() {
    local v f falta=""; v=$(ini disable_functions)
    for f in exec shell_exec system passthru proc_open popen; do grep -qE "(^|,) *$f *(,|$)" <<<"$v" || falta="$falta $f"; done
    MSG="Faltan:${falta:- (ninguna)}."
    [ -z "$falta" ]
}
b4_subidas() { local u p; u=$(ini upload_max_filesize); p=$(ini post_max_size); MSG="upload_max_filesize «$u» · post_max_size «$p»."; [ "$u" = 2M ] && [ "$p" = 4M ]; }
b4_cookie() { local v; v=$(ini session.cookie_httponly); MSG="session.cookie_httponly vale «$v»."; [ "$v" = 1 ]; }
bloque 4 "php.ini endurecido"
check 4.1 "👀" "memory_limit = 128M" b4_mem
check 4.2 "✍️" "PHP no dice su versión (sin X-Powered-By)" b4_expose
check 4.3 "✍️" "Los errores no se enseñan al usuario" b4_display
check 4.4 "✍️" "…y se guardan en logs/php-errores.log" b4_log
check 4.5 "✍️" "Funciones peligrosas desactivadas" b4_funciones
check 4.6 "✍️" "Subidas de 2 MB y formularios de 4 MB" b4_subidas
check 4.7 "✍️" "Cookie de sesión con httponly" b4_cookie

# ═════════════ Bloque 5 · El pool y lo que no se ve ═════════════
FPM=$(fpm)
valor_fpm() { sed -n "s/^$1 = //p" <<<"$FPM" | tail -1; }
b5_req() { local v; v=$(valor_fpm pm.max_requests); MSG="pm.max_requests = «$v»."; [ "$v" = 500 ]; }
b5_pool() {
    local pm mc ss mi ma; pm=$(valor_fpm pm); mc=$(valor_fpm pm.max_children); ss=$(valor_fpm pm.start_servers)
    mi=$(valor_fpm pm.min_spare_servers); ma=$(valor_fpm pm.max_spare_servers)
    MSG="pm = $pm · max_children = $mc · start = $ss · min_spare = $mi · max_spare = $ma."
    [ "$mc" = 5 ] && TRAMPA="pm.max_children = 5 es el de fábrica: haz la cuenta con los datos del enunciado."
    [ "$pm" = dynamic ] && [ "$mc" = 10 ] && [ "$ss" = 3 ] && [ "$mi" = 2 ] && [ "$ma" = 4 ]
}
b5_estado() {
    local r; r=$(web "$URL/estado-fpm")
    MSG="/estado-fpm ha dado el código $(codigo "$URL/estado-fpm")."
    grep -q '^pool:' <<<"$r" && grep -q 'process manager:' <<<"$r" || return 1
    docker compose exec -T nginx nginx -T 2>/dev/null | awk '/location = \/estado-fpm/,/}/' | grep -q 'deny *all' \
        || { MSG="/estado-fpm responde, pero lo ve cualquiera."; TRAMPA="la página de estado abierta a todo Internet: faltan los allow de las redes privadas y deny all."; return 1; }
}
b5_slowlog() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local s; s=$(valor_fpm request_slowlog_timeout); MSG="request_slowlog_timeout = «$s»."
    [ "$s" = 3s ] || return 1
    en_php ': > /var/log/lab/php-lento.log'
    web "$URL/lento.php?s=4" >/dev/null; sleep 0.5
    en_php 'grep -q "lento.php" /var/log/lab/php-lento.log' || { MSG="Una petición de 4 s no ha dejado rastro en logs/php-lento.log (¿slowlog con esa ruta?)."; return 1; }
}
b5_cerrado() {  # b5_cerrado ruta
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local c; c=$(codigo "$URL$1"); MSG="$1 ha dado $c."
    [ "$c" = 403 ] || [ "$c" = 404 ]
}
bloque 5 "El pool y lo que no se ve"
check 5.1 "👀" "pm.max_requests = 500" b5_req
check 5.2 "✍️" "pm dinámico con pm.max_children calculado (y 3/2/4)" b5_pool
check 5.3 "✍️" "/estado-fpm responde, solo para redes privadas" b5_estado
check 5.4 "✍️" "slowlog: una petición de 4 s queda apuntada" b5_slowlog
check 5.5 "✍️" "info.php no se ve (403 o 404)" b5_cerrado /info.php
check 5.6 "✍️" "inc/platos.php no se ve (403 o 404)" b5_cerrado /inc/platos.php

# ═════════════ Bloque 6 · Integrador: la carta en JSON ═════════════
b6_tipo() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local t; t=$(cabeceras "$URL/menu.php" | sed -n 's/^[Cc]ontent-[Tt]ype: //p')
    MSG="Content-Type: «$t»."
    grep -q 'text/html' <<<"$t" && TRAMPA="sin header(): PHP dice que es HTML aunque escribas JSON."
    grep -q '^application/json' <<<"$t"
}
b6_json() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local cuerpo r; cuerpo=$(web "$URL/menu.php"); r=$(ayuda json <<<"$cuerpo")
    MSG="Ha salido: $r (esperaba LISTA 6 …)."
    [[ $r == "LISTA 6 4" ]] || return 1
    grep -q 'Café con leche' <<<"$cuerpo" || { MSG="Las tildes salen como \\u00e9."; TRAMPA="falta JSON_UNESCAPED_UNICODE."; return 1; }
}
b6_veg() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local r; r=$(web "$URL/menu.php?veg=1" | ayuda json)
    MSG="Con ?veg=1 ha salido: $r (esperaba LISTA 4 4)."
    [[ $r == OBJETO* ]] && TRAMPA="sin array_values: quedan las claves 1, 2, 4… y JSON lo convierte en un objeto, no en una lista."
    [[ $r == "LISTA 4 4" ]]
}
b6_metodo() {
    se_ejecuta || { MSG="Necesita el bloque 1."; return 1; }
    local h c cuerpo; h=$(cabeceras -X POST "$URL/menu.php"); c=$(head -1 <<<"$h" | awk '{print $2}'); cuerpo=$(web -X POST "$URL/menu.php")
    MSG="Con POST ha dado $c$(grep -i '^allow:' <<<"$h" | sed 's/^/ y /')."
    [ "$c" = 405 ] && grep -qi '^allow: *GET *$' <<<"$h" && grep -q '"error"' <<<"$cuerpo"
}
bloque 6 "Integrador: la carta en JSON"
check 6.1 "✍️" "menu.php dice que es JSON (Content-Type)" b6_tipo
check 6.2 "✍️" "{\"platos\": […]} con los 6 platos y las tildes bien" b6_json
check 6.3 "✍️" "?veg=1: solo los 4 vegetarianos, en una lista" b6_veg
check 6.4 "✍️" "Con POST: 405, «Allow: GET» y el error en JSON" b6_metodo
cierre_bloque

echo
if [ -n "$SOLO" ]; then
    echo "${N}Bloque $SOLO: $ok de $total${X}"
else
    echo "${N}Resultado: $ok de $total${X}  ${G}(los 👀 son ejemplos ya resueltos)${X}"
    [ "$ok" -lt "$total" ] && echo "${G}Para ver un bloque con más detalle: ./bateria.sh comprobar N · Pistas: «🆘 ¿Atascado?» en la página de la batería.${X}"
fi
[ "$ok" -eq "$total" ]

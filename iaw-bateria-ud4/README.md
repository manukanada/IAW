# Batería UD4 · La cafetería del instituto (Nginx + PHP-FPM)

Batería **opcional** de la UD4 de IAW: no se entrega y no cuenta para la nota. Las explicaciones y las pistas están en la
página de la batería, en la web de la asignatura («🏋️ Practicar»).

## Antes de empezar

Solo necesitas **Docker** (el de la práctica 1). En tu ordenador no se instala nada más. Todo se hace con `./bateria.sh`:

```bash
unzip kit-iaw-bateria-ud4.zip
cd iaw-bateria-ud4
./bateria.sh arrancar        # la primera vez tarda: descarga las imágenes
./bateria.sh comprobar       # al principio, solo los ejemplos 👀 en verde: 5 de 40
code .
```

| Orden | Para qué |
|---|---|
| `./bateria.sh arrancar` | Levanta la cafetería: https://localhost:8447 (certificado de prueba: acepta el aviso) |
| `./bateria.sh comprobar` | Comprueba todos los bloques |
| `./bateria.sh comprobar 3` | Solo el bloque 3, con un 💡 en cada ejercicio y el porqué de cada predicción |
| `./bateria.sh recargar` | Aplica tus cambios: `nginx -t` + recarga Nginx, y reinicia PHP (`comprobar` ya lo hace solo) |
| `./bateria.sh probar 'var_dump("5" == 5);'` | Ejecuta una línea de PHP (para las predicciones del bloque 2) |
| `./bateria.sh logs` | Las últimas líneas de los logs de Nginx y de PHP |
| `./bateria.sh parar` | Lo apaga todo |

## Qué tocas tú

| Bloque | Fichero |
|---|---|
| 1 · Nginx ↔ PHP-FPM | `nginx/sites-available/cafeteria.conf` y `predicciones.txt` |
| 2 · PHP: la carta | `www/cafeteria/carta.php` y `predicciones.txt` |
| 3 · El formulario y el XSS | `www/cafeteria/pedido.php` |
| 4 · `php.ini` endurecido | `php/zz-bateria.ini` |
| 5 · El pool y lo que no se ve | `php/zz-bateria-pool.conf` y `cafeteria.conf` |
| 6 · Integrador: la carta en JSON | `www/cafeteria/menu.php` |
| ✍️ | `respuestas.md` |

Cada hueco está marcado con ✍️ y lleva sus instrucciones dentro del fichero. Lo marcado con 👀 ya está resuelto: léelo.
No toques `comprobador/`, `compose.yaml` ni los `Dockerfile`.

**Puertos:** 8087 (HTTP) y 8447 (HTTPS). No chocan con el laboratorio de clase (8083/8445).

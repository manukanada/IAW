<?php
// Batería UD4 · bloque 3 · El formulario de pedidos. Apartado 5 de la UD4.
// Pruébalo en https://localhost:8447/pedido.php
declare(strict_types=1);
$titulo = 'Pedido · Cafetería';
$platos = require __DIR__ . '/inc/platos.php';

// 👀 Ya resuelto: e() escapa un texto antes de imprimirlo en HTML (contra el XSS). Úsala con TODO lo que escriba el usuario.
function e(string $texto): string {
    return htmlspecialchars($texto, ENT_QUOTES | ENT_HTML5, 'UTF-8');
}
function euros(float $x): string {
    return number_format($x, 2, ',', '.') . ' €';
}

// ✍️ 3.1 · Esta página solo admite GET (ver el formulario) y POST (enviarlo). Con cualquier otro método:
//    código 405, cabecera «Allow: GET, POST» y se acaba ahí. Pista: $_SERVER['REQUEST_METHOD'], http_response_code, header, exit.

$errores = [];
$hecho = false;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $nombre     = trim($_POST['nombre'] ?? '');
    $plato      = $_POST['plato'] ?? '';
    $comentario = trim($_POST['comentario'] ?? '');

    // ✍️ 3.2 · La cantidad tiene que ser un número ENTERO del 1 al 5. Si no lo es, añade a $errores:
    //    'La cantidad tiene que ser un número entero del 1 al 5.'   Pista: filter_var con FILTER_VALIDATE_INT y min_range/max_range.
    $cantidad = 1;

    // ✍️ 3.3 · El plato tiene que estar en la carta. Busca en $platos el que tenga ese nombre y guárdalo en $elegido.
    //    Si no está, añade a $errores: 'Ese plato no está en la carta.'
    $elegido = $platos[0];

    // ✍️ 3.4 · Si hay errores, contesta con el código 422 (datos no válidos). Si no, $hecho = true.
    $hecho = true;
}
require __DIR__ . '/inc/cabecera.php';
?>
<form method="post">
  <label>Tu nombre <input name="nombre"></label>
  <label>Plato
    <select name="plato">
<?php foreach ($platos as $p): ?>
      <option><?= e($p['nombre']) ?></option>
<?php endforeach; ?>
    </select>
  </label>
  <label>Cantidad <input name="cantidad" type="number" min="1" max="5" value="1"></label>
  <label>Comentario <input name="comentario"></label>
  <button>Pedir</button>
</form>

<?php foreach ($errores as $error): ?>
  <p class="aviso"><?= e($error) ?></p>
<?php endforeach; ?>
<?php if ($hecho): ?>
<?php // ✍️ 3.5 · Estas líneas imprimen lo que escribió el usuario TAL CUAL: arréglalas para que no haya XSS. ?>
  <p class="ok" id="pedido">Pedido recibido, <?= $nombre ?>: <?= $cantidad ?> × <?= $elegido['nombre'] ?>.</p>
  <p id="comentario">Comentario: <?= $comentario ?></p>
  <p id="total">Total: <?= euros($cantidad * $elegido['precio']) ?></p>
<?php endif; ?>
</body></html>

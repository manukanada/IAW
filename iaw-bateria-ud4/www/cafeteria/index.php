<?php
// Portada de la cafetería. Ya está hecha: sirve para comprobar que Nginx le pasa los .php a PHP (bloque 1).
declare(strict_types=1);
$titulo = 'Cafetería del instituto';
require __DIR__ . '/inc/cabecera.php';
?>
<p class="ok">Hoy es <?= date('d/m/Y') ?> y te atiende PHP <?= PHP_VERSION ?>.</p>
<ul>
  <li><a href="carta.php">La carta</a> (bloque 2)</li>
  <li><a href="pedido.php">Haz tu pedido</a> (bloque 3)</li>
  <li><a href="menu.php">La carta en JSON</a> (bloque 6)</li>
</ul>
</body></html>

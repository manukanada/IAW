<?php
// Una página lenta, para el slowlog (bloque 5).
declare(strict_types=1);
$segundos = min((int)($_GET['s'] ?? 4), 20);
sleep($segundos);
header('Content-Type: text/plain; charset=utf-8');
echo "Hecho en {$segundos} s\n";

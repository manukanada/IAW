<?php
// Batería UD4 · bloque 6 (integrador) · La carta en JSON, para la app del móvil de la cafetería.
// Pruébala en https://localhost:8447/menu.php y https://localhost:8447/menu.php?veg=1
declare(strict_types=1);
$platos = require __DIR__ . '/inc/platos.php';

// ✍️ 6.1 · Avisa al navegador de que lo que devuelves es JSON (en UTF-8).
header('Content-Type: application/json; charset=utf-8');
// ✍️ 6.4 · Solo se puede consultar: con cualquier método que no sea GET, código 405, cabecera «Allow: GET»
//    y el JSON {"error": "Solo se puede consultar (GET)"}.

// ✍️ 6.3 · Con ?veg=1, solo los platos vegetarianos (y que la lista siga numerada 0, 1, 2…: array_values).
    if (($_GET['veg'] ?? '') === '1') { 
	$platos = array_values(array_filter($platos));
}
// ✍️ 6.2 · Devuelve {"platos": [ … ]} en JSON, con las tildes tal cual (JSON_UNESCAPED_UNICODE).
echo json_encode(['platos' => $platos], JSON_UNESCAPED_UNICODE);

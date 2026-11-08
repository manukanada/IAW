<?php // Cabecera común (la incluyen las páginas con require). ?>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title><?= $titulo ?? 'Cafetería' ?></title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 42rem; margin: 2rem auto; padding: 0 1rem; color: #202124; }
    header { border-bottom: 4px solid #34a853; margin-bottom: 1.5rem; }
    .aviso { background: #fce8e6; padding: .5rem 1rem; border-radius: 6px; }
    .ok { background: #e6f4ea; padding: .5rem 1rem; border-radius: 6px; }
  </style>
</head>
<body>
<header><h1>☕ Cafetería del instituto</h1></header>

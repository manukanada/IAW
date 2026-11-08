// Ayudante del comprobador (se ejecuta con «php -r» dentro del contenedor php; sin la etiqueta de apertura).
//   lis ID      → el texto de cada <li> de la lista con ese id, uno por línea (o SIN_LISTA)
//   texto ID    → el texto del elemento con ese id (o SIN_ELEMENTO)
//   json        → «LISTA|OBJETO nº_platos nº_vegetarianos» (o NO_JSON / SIN_PLATOS)
$modo = $argv[1] ?? '';
$id = $argv[2] ?? '';
$entrada = stream_get_contents(STDIN);
$limpio = fn(string $t): string => trim(preg_replace('/\s+/u', ' ', $t));
if ($modo === 'lis' || $modo === 'texto') {
    libxml_use_internal_errors(true);
    $doc = new DOMDocument();
    $doc->loadHTML('<?xml encoding="utf-8"?>' . $entrada);
    $el = $doc->getElementById($id);
    if ($el === null) {
        echo $modo === 'lis' ? "SIN_LISTA\n" : "SIN_ELEMENTO\n";
        exit;
    }
    if ($modo === 'texto') {
        echo $limpio($el->textContent), "\n";
        exit;
    }
    foreach ($el->getElementsByTagName('li') as $li) {
        echo $limpio($li->textContent), "\n";
    }
} elseif ($modo === 'json') {
    $j = json_decode($entrada, true);
    if (!is_array($j)) { echo "NO_JSON\n"; exit; }
    $p = $j['platos'] ?? null;
    if (!is_array($p)) { echo "SIN_PLATOS\n"; exit; }
    $veg = count(array_filter($p, fn($x) => is_array($x) && ($x['vegetariano'] ?? null) === true));
    echo array_is_list($p) ? 'LISTA' : 'OBJETO', ' ', count($p), ' ', $veg, "\n";
}

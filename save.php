<?php
// Save endpoint for wballers player-edit.html.
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'error' => 'Method not allowed']);
    exit;
}

$body = file_get_contents('php://input');
if ($body === false || $body === '') {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'Empty body']);
    exit;
}

$data = json_decode($body);
if ($data === null) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'Invalid JSON']);
    exit;
}

$target = __DIR__ . '/players.json';
if (file_put_contents($target, json_encode($data, JSON_PRETTY_PRINT)) === false) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'error' => 'Failed to write players.json']);
    exit;
}

echo json_encode(['ok' => true, 'path' => $target]);

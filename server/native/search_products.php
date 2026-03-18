<?php
/**
 * Search proxy for Webasyst shop.product.search with lightweight file cache.
 *
 * Request (GET or POST JSON):
 * - q (required): search query
 * - limit (optional): 1..120, default 30
 * - offset (optional): >=0, default 0
 * - fields (optional): comma-separated API fields
 *
 * Response:
 * - Pass-through JSON from /api.php/shop.product.search
 * - Header X-Search-Cache: HIT | MISS | BYPASS
 */

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'POST'], true)) {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit;
}

function hb_int($value, $default, $min = null, $max = null) {
    if (!is_numeric($value)) {
        return $default;
    }
    $next = (int) $value;
    if ($min !== null && $next < $min) $next = $min;
    if ($max !== null && $next > $max) $next = $max;
    return $next;
}

function hb_json_error($statusCode, $message) {
    http_response_code($statusCode);
    echo json_encode(['status' => 'error', 'message' => $message], JSON_UNESCAPED_UNICODE);
    exit;
}

$input = $_GET;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $raw = file_get_contents('php://input');
    $decoded = json_decode($raw, true);
    if (is_array($decoded)) {
        $input = array_merge($input, $decoded);
    }
}

$query = isset($input['q']) ? trim((string) $input['q']) : '';
if ($query === '' && isset($input['hash'])) {
    $hash = trim((string) $input['hash']);
    $prefix = 'search/query=';
    if (strpos($hash, $prefix) === 0) {
        $query = trim(substr($hash, strlen($prefix)));
    }
}

if ($query === '' || mb_strlen($query, 'UTF-8') < 2) {
    hb_json_error(400, 'q is required (min 2 chars)');
}

$configPath = __DIR__ . '/../config/shop_api_config.php';
if (!is_file($configPath)) {
    hb_json_error(500, 'Missing config/shop_api_config.php');
}
$config = require $configPath;
if (!is_array($config)) {
    hb_json_error(500, 'Invalid config/shop_api_config.php');
}

$apiBaseUrl = rtrim((string) ($config['api_base_url'] ?? ''), '/');
$apiToken = trim((string) ($config['api_token'] ?? ''));
if ($apiBaseUrl === '' || $apiToken === '' || strpos($apiToken, 'ВАШ_ACCESS_TOKEN') !== false) {
    hb_json_error(500, 'Server search proxy is not configured');
}

$limit = hb_int($input['limit'] ?? null, 30, 1, 120);
$offset = hb_int($input['offset'] ?? null, 0, 0, 20000);
$rawFields = isset($input['fields']) ? trim((string) $input['fields']) : '';

if ($rawFields === '') {
    $rawFields = 'id,name,price,compare_price,image_url,url,status,count,category_id,category_ids';
}
$fields = preg_replace('/[^a-zA-Z0-9_,]/', '', $rawFields);
if ($fields === '') {
    $fields = 'id,name,price,compare_price,image_url,url,status,count,category_id,category_ids';
}

$normalizedQuery = preg_replace('/\s+/u', ' ', trim($query));
if (function_exists('mb_strtolower')) {
    $normalizedQuery = mb_strtolower($normalizedQuery, 'UTF-8');
} else {
    $normalizedQuery = strtolower($normalizedQuery);
}

// Cache only first page of search results.
$cacheTtlSec = 0;
if ($offset === 0) {
    $queryLen = function_exists('mb_strlen') ? mb_strlen($normalizedQuery, 'UTF-8') : strlen($normalizedQuery);
    $cacheTtlSec = $queryLen <= 3 ? 20 : 60;
}

$cacheDir = __DIR__ . '/../cache/search';
$cacheKeyPayload = [
    'q' => $normalizedQuery,
    'limit' => $limit,
    'offset' => $offset,
    'fields' => $fields,
];
$cacheKey = sha1(json_encode($cacheKeyPayload, JSON_UNESCAPED_UNICODE));
$cachePath = $cacheDir . '/' . $cacheKey . '.json';

if ($cacheTtlSec > 0 && is_file($cachePath)) {
    $rawCache = @file_get_contents($cachePath);
    $cached = is_string($rawCache) ? json_decode($rawCache, true) : null;
    if (is_array($cached)) {
        $cachedTs = hb_int($cached['ts'] ?? null, 0, 0);
        $cachedStatus = hb_int($cached['status'] ?? null, 0, 0);
        $cachedBody = isset($cached['body']) ? (string) $cached['body'] : '';
        if ($cachedTs > 0 && (time() - $cachedTs) <= $cacheTtlSec && $cachedStatus === 200 && $cachedBody !== '') {
            header('X-Search-Cache: HIT');
            http_response_code(200);
            echo $cachedBody;
            exit;
        }
    }
}

$params = [
    'access_token' => $apiToken,
    'limit' => $limit,
    'offset' => $offset,
    'hash' => 'search/query=' . $query,
    'status' => 1,
    'in_stock' => 1,
    'fields' => $fields,
];

$url = $apiBaseUrl . '/api.php/shop.product.search?' . http_build_query($params, '', '&', PHP_QUERY_RFC3986);
$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => [
        'Accept: application/json',
        'User-Agent: HB-App-Search-Proxy/1.0',
    ],
    CURLOPT_CONNECTTIMEOUT => 5,
    CURLOPT_TIMEOUT => 15,
]);

$responseBody = curl_exec($ch);
$statusCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

if ($responseBody === false) {
    hb_json_error(502, $curlError !== '' ? $curlError : 'Upstream request failed');
}

if ($cacheTtlSec > 0 && $statusCode === 200) {
    if (!is_dir($cacheDir)) {
        @mkdir($cacheDir, 0775, true);
    }
    if (is_dir($cacheDir) && is_writable($cacheDir)) {
        $payload = json_encode([
            'ts' => time(),
            'status' => 200,
            'body' => (string) $responseBody,
        ], JSON_UNESCAPED_UNICODE);
        if (is_string($payload)) {
            @file_put_contents($cachePath, $payload, LOCK_EX);
        }
    }
}

header('X-Search-Cache: ' . ($cacheTtlSec > 0 ? 'MISS' : 'BYPASS'));
http_response_code($statusCode > 0 ? $statusCode : 502);
echo (string) $responseBody;


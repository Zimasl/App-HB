<?php
/**
 * Статус платежа YooKassa + отметка заказа оплаченным через API.
 * POST (JSON): order_id, payment_id
 * Ответ: payment_status (pending|succeeded|canceled), status
 *
 * Настройка: YOOKASSA — в начале файла; для отметки «оплачен» — API_BASE_URL и API_TOKEN (как в create_order.php).
 */

header('Content-Type: application/json; charset=utf-8');

// ========== НАСТРОЙКА ==========
define('YOOKASSA_SHOP_ID',   'ВСТАВЬТЕ_SHOP_ID');
define('YOOKASSA_SECRET_KEY', 'ВСТАВЬТЕ_SECRET_KEY');
define('API_BASE_URL',        'https://hozyain-barin.ru');
define('API_TOKEN',           'ВСТАВЬТЕ_ТОТ_ЖЕ_ТОКЕН_ЧТО_В_CREATE_ORDER');
// ==============================

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['payment_status' => '', 'status' => 'error']);
    exit;
}

$raw = file_get_contents('php://input');
$input = json_decode($raw, true);
if (!is_array($input) || empty($input['payment_id'])) {
    echo json_encode(['payment_status' => 'pending', 'status' => 'pending']);
    exit;
}

$order_id   = isset($input['order_id']) ? $input['order_id'] : '';
$payment_id = preg_replace('/[^a-zA-Z0-9_-]/', '', (string) $input['payment_id']);
if ($payment_id === '') {
    echo json_encode(['payment_status' => 'pending', 'status' => 'pending']);
    exit;
}

$auth = base64_encode(YOOKASSA_SHOP_ID . ':' . YOOKASSA_SECRET_KEY);
$ch = curl_init('https://api.yookassa.ru/v3/payments/' . $payment_id);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER     => ['Authorization: Basic ' . $auth],
    CURLOPT_TIMEOUT        => 15,
]);
$response = curl_exec($ch);
$http_code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($response === false || $http_code >= 400) {
    echo json_encode(['payment_status' => 'pending', 'status' => 'pending']);
    exit;
}

$data = json_decode($response, true);
$payment_status = isset($data['status']) ? strtolower((string) $data['status']) : 'pending';

// Отметить заказ оплаченным через API Webasyst (shop.order.action action=pay)
if ($payment_status === 'succeeded' && $order_id !== '' && ctype_digit((string) $order_id) && API_TOKEN !== '' && API_TOKEN !== 'ВСТАВЬТЕ_ТОТ_ЖЕ_ТОКЕН_ЧТО_В_CREATE_ORDER') {
    $base = rtrim(API_BASE_URL, '/');
    $post = [
        'access_token' => API_TOKEN,
        'id'           => $order_id,
        'action'       => 'pay',
    ];
    $ctx = stream_context_create([
        'http' => [
            'method'  => 'POST',
            'header'  => 'Content-Type: application/x-www-form-urlencoded',
            'content' => http_build_query($post),
            'timeout' => 10,
        ],
    ]);
    @file_get_contents($base . '/api.php/shop.order.action', false, $ctx);
}

echo json_encode([
    'payment_status' => $payment_status,
    'status'         => $payment_status,
]);

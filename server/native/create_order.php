<?php
/**
 * Создание заказа через API Webasyst (shop.order.add).
 * Без загрузки фреймворка, без отдельного конфига.
 *
 * Настройка: в начале файла укажите API_BASE_URL и API_TOKEN.
 * В запросе приложение передаёт contact_id в теле POST.
 */

header('Content-Type: application/json; charset=utf-8');

// ========== НАСТРОЙКА — укажите свои данные ==========
define('API_BASE_URL', 'https://hozyain-barin.ru');
define('API_TOKEN',   'ВСТАВЬТЕ_СЮДА_ТОКЕН_ИЗ_НАСТРОЕК_WEBASYST');
// =====================================================

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['status' => 'error', 'error_description' => 'Method not allowed']);
    exit;
}

$raw = file_get_contents('php://input');
$input = json_decode($raw, true);
if (!is_array($input) || empty($input['items']) || !is_array($input['items'])) {
    echo json_encode(['status' => 'error', 'error_description' => 'Неверный запрос: ожидается JSON с полем items']);
    exit;
}

$contact_id = isset($input['contact_id']) ? trim((string) $input['contact_id']) : '';
if ($contact_id === '') {
    echo json_encode(['status' => 'error', 'error_description' => 'Необходима авторизация (contact_id). Войдите в приложение.']);
    exit;
}

$base  = rtrim(API_BASE_URL, '/');
$token = API_TOKEN;
if ($token === '' || $token === 'ВСТАВЬТЕ_СЮДА_ТОКЕН_ИЗ_НАСТРОЕК_WEBASYST') {
    echo json_encode(['status' => 'error', 'error_description' => 'В create_order.php не указан API_TOKEN. Откройте файл и вставьте токен из настроек Webasyst.']);
    exit;
}

// Получить sku_id по product_id через API
$get_sku = function ($product_id) use ($base, $token) {
    $url = $base . '/api.php/shop.product.getInfo?id=' . (int) $product_id . '&access_token=' . rawurlencode($token);
    $ctx = stream_context_create(['http' => ['timeout' => 10]]);
    $resp = @file_get_contents($url, false, $ctx);
    if ($resp === false) return null;
    $data = json_decode($resp, true);
    if (!is_array($data) || empty($data['skus']) || !is_array($data['skus'])) return null;
    $first = reset($data['skus']);
    return isset($first['id']) ? (int) $first['id'] : null;
};

$order_items = [];
foreach ($input['items'] as $row) {
    if (!is_array($row)) continue;
    $product_id = (int) (isset($row['id']) ? $row['id'] : (isset($row['product_id']) ? $row['product_id'] : 0));
    $quantity   = isset($row['quantity']) ? max(1, (int) $row['quantity']) : 1;
    if ($product_id <= 0) continue;
    $sku_id = $get_sku($product_id);
    if ($sku_id === null) {
        echo json_encode(['status' => 'error', 'error_description' => 'Товар или SKU не найден: ' . $product_id]);
        exit;
    }
    $order_items[] = ['sku_id' => $sku_id, 'quantity' => $quantity];
}

if (empty($order_items)) {
    echo json_encode(['status' => 'error', 'error_description' => 'Нет позиций для заказа']);
    exit;
}

$payment_method  = isset($input['payment_method']) ? (int) $input['payment_method'] : 0;
$delivery_method = isset($input['delivery_method']) ? (int) $input['delivery_method'] : 1;
$address         = isset($input['address']) ? trim((string) $input['address']) : '';
$pickup_stock_id = isset($input['pickup_stock_id']) ? (int) $input['pickup_stock_id'] : null;
$total           = isset($input['total']) ? (float) $input['total'] : 0.0;
$payment_status  = isset($input['payment_status']) ? strtolower(trim((string) $input['payment_status'])) : '';
$payment_id      = isset($input['payment_id']) ? trim((string) $input['payment_id']) : '';

$post = [
    'access_token' => $token,
    'contact_id'   => $contact_id,
];
$i = 0;
foreach ($order_items as $item) {
    $post['items[' . $i . '][sku_id]']   = $item['sku_id'];
    $post['items[' . $i . '][quantity]'] = $item['quantity'];
    $i++;
}
if ($payment_method === 0) $post['params[payment_id]'] = 1;
if ($delivery_method === 0 && $address !== '') $post['params[shipping_address]'] = $address;
if ($pickup_stock_id !== null) $post['params[stock_id]'] = $pickup_stock_id;
if ($payment_id !== '') $post['params[yookassa_payment_id]'] = $payment_id;

$url = $base . '/api.php/shop.order.add';
$ctx = stream_context_create([
    'http' => [
        'method'  => 'POST',
        'header'  => 'Content-Type: application/x-www-form-urlencoded',
        'content' => http_build_query($post),
        'timeout' => 20,
    ],
]);
$response = @file_get_contents($url, false, $ctx);

if ($response === false) {
    echo json_encode(['status' => 'error', 'error_description' => 'Ошибка запроса к API сайта']);
    exit;
}

$data = json_decode($response, true);
if (!is_array($data)) {
    echo json_encode(['status' => 'error', 'error_description' => 'Некорректный ответ API']);
    exit;
}

$order_id   = isset($data['id']) ? $data['id'] : (isset($data['order_id']) ? $data['order_id'] : null);
$total_api  = isset($data['total']) ? $data['total'] : $total;

if (empty($order_id)) {
    $msg = isset($data['error']) ? $data['error'] : (isset($data['message']) ? $data['message'] : 'Не удалось создать заказ');
    echo json_encode(['status' => 'error', 'error_description' => $msg]);
    exit;
}

// Если онлайн-оплата уже подтверждена в приложении, отмечаем заказ оплаченным.
if ($payment_method === 0 && $payment_status === 'succeeded') {
    $pay_post = [
        'access_token' => $token,
        'id'           => $order_id,
        'action'       => 'pay',
    ];
    $pay_ctx = stream_context_create([
        'http' => [
            'method'  => 'POST',
            'header'  => 'Content-Type: application/x-www-form-urlencoded',
            'content' => http_build_query($pay_post),
            'timeout' => 10,
        ],
    ]);
    @file_get_contents($base . '/api.php/shop.order.action', false, $pay_ctx);
}

echo json_encode([
    'status'       => 'ok',
    'order_id'     => (string) $order_id,
    'order_number' => (string) $order_id,
    'amount'       => is_numeric($total_api) ? number_format((float) $total_api, 2, '.', '') : (string) $total_api,
]);

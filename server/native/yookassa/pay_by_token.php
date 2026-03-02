<?php
/**
 * Оплата заказа по токену YooKassa.
 * POST (JSON): order_id, payment_token, payment_method_type?, amount
 * Ответ: status, payment_id, confirmation_url?
 *
 * Настройка: укажите YOOKASSA_SHOP_ID и YOOKASSA_SECRET_KEY в начале файла.
 */

header('Content-Type: application/json; charset=utf-8');

// ========== НАСТРОЙКА YOOKASSA ==========
define('YOOKASSA_SHOP_ID',  'ВСТАВЬТЕ_SHOP_ID_ИЗ_ЛИЧНОГО_КАБИНЕТА');
define('YOOKASSA_SECRET_KEY', 'ВСТАВЬТЕ_SECRET_KEY_ИЗ_ЛИЧНОГО_КАБИНЕТА');
// ========================================

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['status' => 'error', 'error_description' => 'Method not allowed']);
    exit;
}

$raw = file_get_contents('php://input');
$input = json_decode($raw, true);
if (!is_array($input) || empty($input['order_id']) || empty($input['payment_token'])) {
    echo json_encode(['status' => 'error', 'error_description' => 'Не указаны order_id или payment_token']);
    exit;
}

$amount = isset($input['amount']) ? trim((string) $input['amount']) : '';
if ($amount === '' || (float) $amount <= 0) {
    echo json_encode(['status' => 'error', 'error_description' => 'Не указана сумма (amount)']);
    exit;
}

$shop_id   = trim((string) YOOKASSA_SHOP_ID);
$secret_key = trim((string) YOOKASSA_SECRET_KEY);
if ($shop_id === '' || $secret_key === '' ||
    $shop_id === 'ВСТАВЬТЕ_SHOP_ID_ИЗ_ЛИЧНОГО_КАБИНЕТА' ||
    $secret_key === 'ВСТАВЬТЕ_SECRET_KEY_ИЗ_ЛИЧНОГО_КАБИНЕТА') {
    echo json_encode([
        'status' => 'error',
        'error_description' => 'В pay_by_token.php не указаны YOOKASSA_SHOP_ID или YOOKASSA_SECRET_KEY',
    ]);
    exit;
}

$order_id = $input['order_id'];
$payment_token = $input['payment_token'];
$return_url = 'https://' . ($_SERVER['HTTP_HOST'] ?? 'hozyain-barin.ru') . '/';

$body = [
    'amount' => [
        'value'    => number_format((float) $amount, 2, '.', ''),
        'currency' => 'RUB',
    ],
    'payment_token' => $payment_token,
    'confirmation' => [
        'type'       => 'redirect',
        'return_url' => $return_url,
    ],
    'capture'     => true,
    'description' => 'Заказ №' . $order_id,
];

$idempotence_key = md5($order_id . '|' . $payment_token . '|' . time());
$auth = base64_encode($shop_id . ':' . $secret_key);

$ch = curl_init('https://api.yookassa.ru/v3/payments');
curl_setopt_array($ch, [
    CURLOPT_POST           => true,
    CURLOPT_POSTFIELDS     => json_encode($body),
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER     => [
        'Content-Type: application/json',
        'Idempotence-Key: ' . $idempotence_key,
        'Authorization: Basic ' . $auth,
    ],
    CURLOPT_TIMEOUT        => 30,
]);
$response = curl_exec($ch);
$http_code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curl_error = curl_error($ch);
curl_close($ch);

if ($response === false) {
    echo json_encode(['status' => 'error', 'error_description' => 'Ошибка YooKassa: ' . $curl_error]);
    exit;
}

$data = json_decode($response, true);
if (!is_array($data)) {
    echo json_encode(['status' => 'error', 'error_description' => 'Некорректный ответ YooKassa']);
    exit;
}

if ($http_code >= 400) {
    $msg = isset($data['description']) ? $data['description'] : (isset($data['message']) ? $data['message'] : 'Ошибка YooKassa');
    echo json_encode(['status' => 'error', 'error_description' => $msg]);
    exit;
}

$payment_id = isset($data['id']) ? $data['id'] : '';
$status = isset($data['status']) ? $data['status'] : 'pending';
$confirmation_url = isset($data['confirmation']['confirmation_url']) ? $data['confirmation']['confirmation_url'] : null;

echo json_encode([
    'status'           => $status,
    'payment_id'       => $payment_id,
    'confirmation_url' => $confirmation_url,
]);

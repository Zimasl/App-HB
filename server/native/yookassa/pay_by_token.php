<?php
/**
 * Оплата заказа по токену YooKassa.
 * POST (JSON): order_id, payment_token, payment_method_type?, amount,
 * customer_phone?, customer_email?, receipt_items?
 * Ответ: status, payment_id, confirmation_url?
 *
 * Настройка: создайте config/yookassa_config.php или
 * native/yookassa/config/yookassa_config.php с shop_id/secret_key.
 */

header('Content-Type: application/json; charset=utf-8');

function hb_load_yookassa_config()
{
    $candidates = [
        dirname(__DIR__, 2) . '/config/yookassa_config.php',
        __DIR__ . '/config/yookassa_config.php',
    ];

    foreach ($candidates as $path) {
        if (!is_file($path)) {
            continue;
        }

        $config = require $path;
        if (is_array($config)) {
            return $config;
        }
    }

    return [];
}

function hb_normalize_phone($value)
{
    $digits = preg_replace('/\D+/', '', (string) $value);
    if ($digits === '') {
        return '';
    }

    if (strlen($digits) === 10) {
        $digits = '7' . $digits;
    } elseif (strlen($digits) === 11 && $digits[0] === '8') {
        $digits = '7' . substr($digits, 1);
    } elseif (strlen($digits) > 11) {
        $digits = '7' . substr($digits, -10);
    }

    if (strlen($digits) !== 11) {
        return '';
    }

    return '+' . $digits;
}

function hb_receipt_description($value)
{
    $text = trim((string) $value);
    if ($text === '') {
        $text = 'Товар';
    }

    if (function_exists('mb_substr')) {
        return mb_substr($text, 0, 128);
    }

    return substr($text, 0, 128);
}

function hb_log_yookassa_debug($stage, array $payload = [])
{
    $log_path = __DIR__ . '/yookassa_response.log';
    $entry = date('Y-m-d H:i:s') . ' ' . $stage;

    if (!empty($payload)) {
        $json = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($json !== false) {
            $entry .= "\n" . $json;
        }
    }

    $entry .= "\n\n";
    @file_put_contents($log_path, $entry, FILE_APPEND);
}

$yookassa_config = hb_load_yookassa_config();
$shop_id = trim((string) ($yookassa_config['shop_id'] ?? ''));
$secret_key = trim((string) ($yookassa_config['secret_key'] ?? ''));
$return_url = trim((string) ($yookassa_config['return_url'] ?? ''));
$tax_system_code = (int) ($yookassa_config['tax_system_code'] ?? 0);
$vat_code = (int) ($yookassa_config['vat_code'] ?? 1);
$payment_mode = trim((string) ($yookassa_config['payment_mode'] ?? 'full_payment'));
$payment_subject = trim((string) ($yookassa_config['payment_subject'] ?? 'commodity'));

if ($tax_system_code < 1 || $tax_system_code > 6) {
    $tax_system_code = 0;
}
if ($vat_code < 1 || $vat_code > 12) {
    $vat_code = 1;
}
if ($payment_mode === '') {
    $payment_mode = 'full_payment';
}
if ($payment_subject === '') {
    $payment_subject = 'commodity';
}

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

if ($shop_id === '' || $secret_key === '') {
    echo json_encode([
        'status' => 'error',
        'error_description' => 'Не найден yookassa_config.php или в нем не заполнены shop_id/secret_key',
    ]);
    exit;
}

$order_id = $input['order_id'];
$payment_token = $input['payment_token'];
$customer_phone = hb_normalize_phone($input['customer_phone'] ?? '');
$customer_email = trim((string) ($input['customer_email'] ?? ''));
$raw_receipt_items = isset($input['receipt_items']) && is_array($input['receipt_items'])
    ? $input['receipt_items']
    : [];
if ($return_url === '') {
    $return_url = 'https://' . ($_SERVER['HTTP_HOST'] ?? 'hozyain-barin.ru') . '/';
}

$receipt_customer = [];
if ($customer_phone !== '') {
    $receipt_customer['phone'] = $customer_phone;
}
if ($customer_email !== '') {
    $receipt_customer['email'] = $customer_email;
}
if (empty($receipt_customer)) {
    echo json_encode([
        'status' => 'error',
        'error_description' => 'Для онлайн-оплаты нужен телефон или email покупателя для чека YooKassa',
    ]);
    exit;
}

$receipt_items = [];
foreach ($raw_receipt_items as $receipt_row) {
    if (!is_array($receipt_row)) {
        continue;
    }

    $description = hb_receipt_description($receipt_row['description'] ?? '');
    $quantity = (float) ($receipt_row['quantity'] ?? 0);
    $item_amount = (float) ($receipt_row['amount'] ?? 0);
    if ($quantity <= 0 || $item_amount <= 0) {
        continue;
    }

    $receipt_items[] = [
        'description' => $description,
        'quantity' => number_format($quantity, 2, '.', ''),
        'amount' => [
            'value' => number_format($item_amount, 2, '.', ''),
            'currency' => 'RUB',
        ],
        'vat_code' => $vat_code,
        'payment_mode' => $payment_mode,
        'payment_subject' => $payment_subject,
    ];
}

if (empty($receipt_items)) {
    $receipt_items[] = [
        'description' => hb_receipt_description('Заказ №' . $order_id),
        'quantity' => '1.00',
        'amount' => [
            'value' => number_format((float) $amount, 2, '.', ''),
            'currency' => 'RUB',
        ],
        'vat_code' => $vat_code,
        'payment_mode' => $payment_mode,
        'payment_subject' => $payment_subject,
    ];
}

$receipt = [
    'customer' => $receipt_customer,
    'items' => $receipt_items,
];
if ($tax_system_code > 0) {
    $receipt['tax_system_code'] = $tax_system_code;
}

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
    'receipt' => $receipt,
];

$request_payload_for_log = $body;
$request_payload_for_log['payment_token'] = '[masked]';
$request_json = json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
if ($request_json === false) {
    hb_log_yookassa_debug('create_payment_request_encode_error', [
        'json_error' => json_last_error_msg(),
        'request' => $request_payload_for_log,
    ]);
    echo json_encode([
        'status' => 'error',
        'error_description' => 'Не удалось подготовить запрос в YooKassa',
    ]);
    exit;
}

$idempotence_key = md5($order_id . '|' . $payment_token . '|' . time());
$auth = base64_encode($shop_id . ':' . $secret_key);

hb_log_yookassa_debug('create_payment_request', [
    'request' => $request_payload_for_log,
]);

$ch = curl_init('https://api.yookassa.ru/v3/payments');
curl_setopt_array($ch, [
    CURLOPT_POST           => true,
    CURLOPT_POSTFIELDS     => $request_json,
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
    hb_log_yookassa_debug('create_payment_transport_error', [
        'request' => $request_payload_for_log,
        'curl_error' => $curl_error,
    ]);
    echo json_encode(['status' => 'error', 'error_description' => 'Ошибка YooKassa: ' . $curl_error]);
    exit;
}

$data = json_decode($response, true);
hb_log_yookassa_debug('create_payment_response', [
    'http_code' => $http_code,
    'request' => $request_payload_for_log,
    'response' => is_array($data) ? $data : $response,
]);
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

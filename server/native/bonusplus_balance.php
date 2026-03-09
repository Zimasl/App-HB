<?php
/**
 * Получение бонусного баланса клиента из BonusPlus.
 * POST (JSON): phone (предпочтительно), contact_id (необязательный)
 * Ответ: status=ok, bonus_balance, customer
 */

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

$localConfig = __DIR__ . '/../config/bonusplus_config.php';
if (is_file($localConfig)) {
    require_once $localConfig;
}

if (!defined('BONUSPLUS_API_BASE')) {
    define('BONUSPLUS_API_BASE', 'https://bonusplus.pro/api');
}
if (!defined('BONUSPLUS_API_KEY')) {
    define('BONUSPLUS_API_KEY', 'CF8291C0-8DC3-4FB2-A5F9-2E501E2107A7');
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit;
}

$raw = file_get_contents('php://input');
$input = json_decode($raw, true);
if (!is_array($input)) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid JSON']);
    exit;
}

$phone_raw = isset($input['phone']) ? (string) $input['phone'] : '';
$phone_digits = preg_replace('/\D+/', '', $phone_raw);
if ($phone_digits === '' || strlen($phone_digits) < 10) {
    echo json_encode(['status' => 'error', 'message' => 'Phone is required']);
    exit;
}

if (BONUSPLUS_API_KEY === '') {
    echo json_encode(['status' => 'error', 'message' => 'BonusPlus API key is not configured']);
    exit;
}

$pick = function ($source, $keys, $default = null) {
    if (!is_array($source)) return $default;
    foreach ($keys as $key) {
        if (array_key_exists($key, $source) && $source[$key] !== null && $source[$key] !== '') {
            return $source[$key];
        }
    }
    return $default;
};

$makeCandidates = function ($rawDigits) {
    $d = preg_replace('/\D+/', '', (string) $rawDigits);
    $list = [];
    if ($d !== '') {
        $list[] = $d;
    }
    if (strlen($d) === 10) {
        $list[] = '7' . $d;
        $list[] = '8' . $d;
        $list[] = '+7' . $d;
    } elseif (strlen($d) === 11) {
        $tail = substr($d, 1);
        if ($tail !== false && strlen($tail) === 10) {
            $list[] = $tail;
            $list[] = '+7' . $tail;
            $list[] = '7' . $tail;
            $list[] = '8' . $tail;
        }
    }
    $uniq = [];
    foreach ($list as $value) {
        if ($value !== '' && !in_array($value, $uniq, true)) {
            $uniq[] = $value;
        }
    }
    return $uniq;
};

$auth_header = 'ApiKey ' . base64_encode(BONUSPLUS_API_KEY);
$candidates = $makeCandidates($phone_digits);
$data = null;
$http_code = 0;
$last_error = '';
foreach ($candidates as $candidate) {
    $url = rtrim(BONUSPLUS_API_BASE, '/') . '/customer?phone=' . rawurlencode($candidate);
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER     => [
            'Authorization: ' . $auth_header,
            'Accept: application/json',
        ],
        CURLOPT_TIMEOUT        => 20,
    ]);
    $response = curl_exec($ch);
    $http_code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curl_error = curl_error($ch);
    curl_close($ch);

    if ($response === false) {
        $last_error = $curl_error;
        continue;
    }

    $decoded = json_decode($response, true);
    if (!is_array($decoded)) {
        $last_error = 'BonusPlus returned invalid JSON';
        continue;
    }
    if ($http_code >= 400) {
        $last_error = isset($decoded['msg']) ? (string)$decoded['msg'] : (isset($decoded['devMsg']) ? (string)$decoded['devMsg'] : 'BonusPlus API error');
        continue;
    }

    $candidateCustomer = isset($decoded['data']) && is_array($decoded['data']) ? $decoded['data'] : $decoded;
    $candidateBalance = $pick($candidateCustomer, [
        'bonusBalance',
        'bonus_balance',
        'balance',
        'bonus',
        'currentBonusBalance',
    ], null);
    if ($candidateBalance !== null || !empty($candidateCustomer)) {
        $data = $decoded;
        break;
    }
}

if (!is_array($data)) {
    $message = $last_error !== '' ? $last_error : 'BonusPlus API error';
    echo json_encode(['status' => 'error', 'message' => $message]);
    exit;
}

$customer = isset($data['data']) && is_array($data['data']) ? $data['data'] : $data;
$person = isset($customer['person']) && is_array($customer['person']) ? $customer['person'] : [];
$person_name_parts = [];
foreach (['ln', 'fn', 'mn'] as $key) {
    $value = isset($person[$key]) ? trim((string) $person[$key]) : '';
    if ($value !== '') {
        $person_name_parts[] = $value;
    }
}
$person_name = trim(implode(' ', $person_name_parts));
$balance_raw = $pick($customer, [
    'availableBonuses',
    'notActiveBonuses',
    'totalBonusCredit',
    'totalBonusDebit',
    'bonusBalance',
    'bonus_balance',
    'balance',
    'bonus',
    'currentBonusBalance',
], 0);
$balance = is_numeric($balance_raw) ? (float) $balance_raw : (float) str_replace(',', '.', (string) $balance_raw);

echo json_encode([
    'status'        => 'ok',
    'bonus_balance' => $balance,
    'customer'      => [
        'id'    => $pick($customer, ['id', 'customerId', 'uid'], ''),
        'name'  => $pick($customer, ['name', 'fullName', 'fio'], $person_name),
        'phone' => $pick($customer, ['phone', 'phoneNumber'], $phone_raw),
    ],
]);


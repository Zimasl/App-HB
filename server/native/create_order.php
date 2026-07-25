<?php
/**
 * Создание заказа через внутренний framework Webasyst (shopOrder).
 *
 * Скрипт создаёт заказ сразу с корректной ценой позиции и скидкой из приложения,
 * чтобы итоговая сумма и экспорт в МойСклад не расходились с checkout в мобильном приложении.
 */

ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/yookassa/yookassa_status.log');
header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/lib/order_pricing.php';

function hb_log_create_order($stage, array $payload = [])
{
    $entry = date('Y-m-d H:i:s') . ' ' . $stage;
    if (!array_key_exists('source', $payload)) {
        $payload = ['source' => 'create_order.php'] + $payload;
    }
    if (!empty($payload)) {
        $json = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($json !== false) {
            $entry .= "\n" . $json;
        }
    }
    $entry .= "\n\n";
    @file_put_contents(__DIR__ . '/yookassa/yookassa_status.log', $entry, FILE_APPEND);
}

function hb_respond(array $payload, int $status_code = 200)
{
    http_response_code($status_code);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function hb_get_input()
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        hb_respond(['status' => 'error', 'error_description' => 'Method not allowed'], 405);
    }

    if (!empty($_POST)) {
        return $_POST;
    }

    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        return [];
    }

    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function hb_bootstrap_webasyst()
{
    $path = dirname(__FILE__) . '/../wa-config/SystemConfig.class.php';
    if (!file_exists($path)) {
        throw new RuntimeException('System config not found');
    }

    require_once $path;

    $config = new SystemConfig();
    waSystem::getInstance(null, $config);
    wa('shop');
}

function hb_build_shipping_address($address)
{
    $street = trim((string) $address);
    if ($street === '') {
        return null;
    }

    return [
        'country' => 'rus',
        'street' => $street,
    ];
}

function hb_can_assign_item_stock($sku_id, $stock_id)
{
    $sku_id = (int) $sku_id;
    $stock_id = (int) $stock_id;
    if ($sku_id <= 0 || $stock_id <= 0) {
        return false;
    }

    $product_stocks_model = new shopProductStocksModel();
    $stock_row = $product_stocks_model->getByField([
        'sku_id' => $sku_id,
        'stock_id' => $stock_id,
    ]);

    return !empty($stock_row);
}

function hb_load_yookassa_config()
{
    $candidates = [
        dirname(__DIR__) . '/config/yookassa_config.php',
        __DIR__ . '/yookassa/config/yookassa_config.php',
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

/**
 * Confirm a YooKassa payment is succeeded and covers expected_amount.
 */
function hb_verify_yookassa_payment($payment_id, $expected_amount)
{
    $payment_id = preg_replace('/[^a-zA-Z0-9_-]/', '', (string) $payment_id);
    if ($payment_id === '') {
        return ['ok' => false, 'reason' => 'empty_payment_id'];
    }

    $config = hb_load_yookassa_config();
    $shop_id = trim((string) ($config['shop_id'] ?? ''));
    $secret_key = trim((string) ($config['secret_key'] ?? ''));
    if ($shop_id === '' || $secret_key === '') {
        return ['ok' => false, 'reason' => 'missing_yookassa_config'];
    }

    $auth = base64_encode($shop_id . ':' . $secret_key);
    $ch = curl_init('https://api.yookassa.ru/v3/payments/' . $payment_id);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => ['Authorization: Basic ' . $auth],
        CURLOPT_TIMEOUT => 15,
    ]);
    $response = curl_exec($ch);
    $http_code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($response === false || $http_code >= 400) {
        return ['ok' => false, 'reason' => 'yookassa_lookup_failed', 'http_code' => $http_code];
    }

    $data = json_decode($response, true);
    if (!is_array($data)) {
        return ['ok' => false, 'reason' => 'invalid_yookassa_response'];
    }

    $status = strtolower(trim((string) ($data['status'] ?? '')));
    if ($status !== 'succeeded') {
        return ['ok' => false, 'reason' => 'payment_not_succeeded', 'payment_status' => $status];
    }

    $paid_amount = hb_parse_money($data['amount']['value'] ?? 0);
    $expected = round(hb_parse_money($expected_amount), 2);
    if (abs($paid_amount - $expected) > 0.011) {
        return [
            'ok' => false,
            'reason' => 'amount_mismatch',
            'paid_amount' => $paid_amount,
            'expected_amount' => $expected,
        ];
    }

    return ['ok' => true, 'paid_amount' => $paid_amount];
}

try {
    $input = hb_get_input();
    if (!is_array($input) || empty($input['items']) || !is_array($input['items'])) {
        hb_respond(['status' => 'error', 'error_description' => 'Неверный запрос: ожидается JSON с полем items'], 400);
    }

    $contact_id = isset($input['contact_id']) ? trim((string) $input['contact_id']) : '';
    if ($contact_id === '') {
        hb_respond(['status' => 'error', 'error_description' => 'Необходима авторизация (contact_id). Войдите в приложение.'], 401);
    }

    $payment_method = isset($input['payment_method']) ? (int) $input['payment_method'] : 0;
    $delivery_method = isset($input['delivery_method']) ? (int) $input['delivery_method'] : 1;
    $address = isset($input['address']) ? trim((string) $input['address']) : '';
    $pickup_stock_id = isset($input['pickup_stock_id']) ? (int) $input['pickup_stock_id'] : 0;
    $pickup_point_id = isset($input['pickup_point_id']) ? trim((string) $input['pickup_point_id']) : '';
    $total = max(0.0, hb_parse_money($input['total'] ?? 0));
    $payment_status = isset($input['payment_status']) ? strtolower(trim((string) $input['payment_status'])) : '';
    $payment_id = isset($input['payment_id']) ? trim((string) $input['payment_id']) : '';
    $use_bonus = !empty($input['use_bonus']) || !empty($input['bonus_amount']);
    $requested_bonus_amount = max(0.0, hb_parse_money($input['bonus_amount'] ?? 0));
    // Refuse unverified bonus write-offs. Trusting client bonus_amount would let
    // anyone zero the payable total without a BonusPlus balance check.
    if ($use_bonus || $requested_bonus_amount > 0) {
        hb_respond([
            'status' => 'error',
            'error_description' => 'Списание бонусов временно недоступно при оформлении. Уберите списание бонусов и повторите заказ.',
        ], 400);
    }
    $bonus_amount = 0.0;

    hb_bootstrap_webasyst();

    $sku_model = new shopProductSkusModel();
    $order_items = [];
    $base_subtotal = 0.0;
    $catalog_selling_subtotal = 0.0;
    $ignore_stock_validate = ($pickup_stock_id <= 0);
    $invalid_item_stock = [];

    foreach ($input['items'] as $row) {
        if (!is_array($row)) {
            continue;
        }

        $product_id = (int) (isset($row['id']) ? $row['id'] : (isset($row['product_id']) ? $row['product_id'] : 0));
        $quantity = isset($row['quantity']) ? max(1, (int) $row['quantity']) : 1;
        if ($product_id <= 0) {
            continue;
        }

        $sku_rows = $sku_model->getByField('product_id', $product_id, true);
        if (empty($sku_rows) || !is_array($sku_rows)) {
            hb_respond(['status' => 'error', 'error_description' => 'Товар или SKU не найден: ' . $product_id], 400);
        }

        $sku_row = reset($sku_rows);
        $sku_id = isset($sku_row['id']) ? (int) $sku_row['id'] : 0;
        if ($sku_id <= 0) {
            hb_respond(['status' => 'error', 'error_description' => 'Товар или SKU не найден: ' . $product_id], 400);
        }

        // Catalog SKU prices are authoritative. Client-supplied prices must not
        // undercut shop price (regression from trusting checkout payload).
        $resolved_prices = hb_resolve_sku_prices(is_array($sku_row) ? $sku_row : []);
        if ($resolved_prices === null) {
            hb_respond([
                'status' => 'error',
                'error_description' => 'У товара не задана цена в каталоге: ' . $product_id,
            ], 400);
        }
        $base_price = $resolved_prices['list'];
        $selling_price = $resolved_prices['selling'];

        $order_item = [
            'type' => 'product',
            'product_id' => $product_id,
            'sku_id' => $sku_id,
            'price' => round($base_price, 4),
            'quantity' => round((float) $quantity, 3),
            'currency' => 'RUB',
            'total_discount' => 0.0,
        ];
        if ($pickup_stock_id > 0 && hb_can_assign_item_stock($sku_id, $pickup_stock_id)) {
            $order_item['stock_id'] = $pickup_stock_id;
        } elseif ($pickup_stock_id > 0) {
            $ignore_stock_validate = true;
            $invalid_item_stock[] = [
                'product_id' => $product_id,
                'sku_id' => $sku_id,
                'stock_id' => $pickup_stock_id,
            ];
        }

        $order_items[] = $order_item;
        $base_subtotal += $base_price * $quantity;
        $catalog_selling_subtotal += $selling_price * $quantity;
    }

    if (empty($order_items)) {
        hb_respond(['status' => 'error', 'error_description' => 'Нет позиций для заказа'], 400);
    }

    if ($ignore_stock_validate) {
        foreach ($order_items as &$order_item) {
            unset($order_item['stock_id']);
        }
        unset($order_item);
    }

    $catalog_selling_subtotal = round($catalog_selling_subtotal, 4);
    $target_total_after_discount = hb_clamp_payable_total(
        $total,
        $catalog_selling_subtotal,
        $bonus_amount
    );
    $required_discount_total = 0.0;
    if ($base_subtotal > $target_total_after_discount) {
        $required_discount_total = round($base_subtotal - $target_total_after_discount, 4);
    }

    $order_items = hb_allocate_discounts($order_items, $required_discount_total);
    $allocated_discount_total = 0.0;
    foreach ($order_items as $item) {
        $allocated_discount_total += hb_parse_money($item['total_discount'] ?? 0);
    }
    $allocated_discount_total = round($allocated_discount_total, 4);

    // Verify online payment against YooKassa before creating/marking the order.
    if ($payment_method === 0 && $payment_status === 'succeeded') {
        $verification = hb_verify_yookassa_payment($payment_id, $target_total_after_discount);
        if (empty($verification['ok'])) {
            hb_log_create_order('payment_verify_rejected', [
                'payment_id' => $payment_id,
                'verification' => $verification,
                'expected_amount' => $target_total_after_discount,
            ]);
            hb_respond([
                'status' => 'error',
                'error_description' => 'Не удалось подтвердить оплату YooKassa',
                'payment_verified' => false,
            ], 402);
        }
    }

    $storefront = trim((string) ($_SERVER['HTTP_HOST'] ?? 'hozyain-barin.ru'));
    if ($storefront === '') {
        $storefront = 'hozyain-barin.ru';
    }

    $params = [
        'storefront' => $storefront,
        'sales_channel' => 'storefront:' . $storefront,
    ];
    if ($payment_method === 0) {
        $params['payment_id'] = 1;
    }
    if ($pickup_stock_id > 0) {
        $params['stock_id'] = $pickup_stock_id;
        $params['pickup_stock_id'] = $pickup_stock_id;
    }
    if ($pickup_point_id !== '') {
        $params['pickup_point_id'] = $pickup_point_id;
    }
    if ($payment_id !== '') {
        $params['yookassa_payment_id'] = $payment_id;
    }
    if ($payment_status !== '') {
        $params['yookassa_payment_status'] = $payment_status;
    }
    if ($use_bonus) {
        $params['bonusplus_use_bonus'] = 1;
    }
    if ($bonus_amount > 0) {
        $params['bonusplus_bonus_amount'] = number_format($bonus_amount, 2, '.', '');
    }

    $order_data = [
        'contact_id' => (int) $contact_id,
        'currency' => 'RUB',
        'shipping' => 0.0,
        'discount' => $allocated_discount_total,
        'items' => $order_items,
        'params' => $params,
    ];

    $shipping_address = ($delivery_method === 0) ? hb_build_shipping_address($address) : null;
    if ($shipping_address) {
        $order_data['shipping_address'] = $shipping_address;
    }

    $order_options = [
        'environment' => 'frontend',
    ];
    if ($ignore_stock_validate) {
        $order_options['ignore_stock_validate'] = true;
    }

    $order = new shopOrder($order_data, $order_options);
    $saved_order = $order->save();

    $saved_order_id = method_exists($saved_order, 'getId') ? (int) $saved_order->getId() : (int) ($saved_order['id'] ?? 0);
    $saved_total = hb_parse_money($saved_order['total'] ?? $target_total_after_discount);

    $payment_marked = false;
    if ($payment_method === 0 && $payment_status === 'succeeded') {
        try {
            $saved_order->runAction('pay', [
                'text' => $payment_id !== ''
                    ? ('Оплата YooKassa подтверждена, payment_id=' . $payment_id)
                    : 'Оплата YooKassa подтверждена',
            ]);
            $payment_marked = true;
        } catch (Throwable $e) {
            hb_log_create_order('payment_mark_exception', [
                'order_id' => $saved_order_id,
                'payment_id' => $payment_id,
                'message' => $e->getMessage(),
            ]);
        }
    }

    hb_respond([
        'status' => 'ok',
        'order_id' => (string) $saved_order_id,
        'order_number' => (string) $saved_order_id,
        'amount' => number_format($saved_total, 2, '.', ''),
        'bonus_discount_applied' => $bonus_amount > 0,
        'discount_synced' => $allocated_discount_total > 0 ? (abs($saved_total - $target_total_after_discount) < 0.011) : true,
        'payment_marked' => $payment_marked,
    ]);
} catch (Throwable $e) {
    $errors = null;
    if (isset($order) && is_object($order) && method_exists($order, 'errors')) {
        try {
            $errors = $order->errors();
        } catch (Throwable $ignored) {
            $errors = null;
        }
    }

    hb_log_create_order('create_order_exception', [
        'message' => $e->getMessage(),
        'errors' => $errors,
    ]);

    hb_respond([
        'status' => 'error',
        'error_description' => $e->getMessage(),
    ], 500);
}

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

function hb_parse_money($value)
{
    if (is_int($value) || is_float($value)) {
        return (float) $value;
    }

    $text = trim((string) $value);
    if ($text === '') {
        return 0.0;
    }

    $normalized = preg_replace('/[^\d,\.\-]/u', '', $text);
    $normalized = str_replace(',', '.', (string) $normalized);
    return is_numeric($normalized) ? (float) $normalized : 0.0;
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

function hb_allocate_discounts(array $items, float $discount_total)
{
    if ($discount_total <= 0 || empty($items)) {
        foreach ($items as &$item) {
            $item['total_discount'] = 0.0;
        }
        unset($item);
        return $items;
    }

    $discount_cents = (int) round($discount_total * 100);
    $weights = [];
    $total_weight = 0;
    foreach ($items as $index => $item) {
        $weight = (int) round(hb_parse_money($item['price']) * hb_parse_money($item['quantity']) * 100);
        if ($weight <= 0) {
            $weight = 1;
        }
        $weights[$index] = $weight;
        $total_weight += $weight;
    }

    if ($total_weight <= 0) {
        $total_weight = count($items);
    }

    $allocated = array_fill(0, count($items), 0);
    $remainders = [];
    $distributed = 0;

    foreach ($items as $index => $item) {
        $raw_share = $weights[$index] * $discount_cents / $total_weight;
        $share = (int) floor($raw_share);
        $line_total_cents = (int) round(hb_parse_money($item['price']) * hb_parse_money($item['quantity']) * 100);
        if ($share > $line_total_cents) {
            $share = $line_total_cents;
        }
        $allocated[$index] = $share;
        $distributed += $share;
        $remainders[] = [
            'index' => $index,
            'remainder' => $raw_share - floor($raw_share),
            'max_cents' => $line_total_cents,
        ];
    }

    usort($remainders, function ($a, $b) {
        $a_remainder = isset($a['remainder']) ? (float) $a['remainder'] : 0.0;
        $b_remainder = isset($b['remainder']) ? (float) $b['remainder'] : 0.0;
        if ($a_remainder === $b_remainder) {
            return 0;
        }
        return ($a_remainder < $b_remainder) ? 1 : -1;
    });

    $remaining = $discount_cents - $distributed;
    while ($remaining > 0) {
        $progress = false;
        foreach ($remainders as $remainder) {
            $index = isset($remainder['index']) ? (int) $remainder['index'] : -1;
            if ($index < 0 || !isset($allocated[$index])) {
                continue;
            }
            $max_cents = isset($remainder['max_cents']) ? (int) $remainder['max_cents'] : 0;
            if ($allocated[$index] >= $max_cents) {
                continue;
            }
            $allocated[$index]++;
            $remaining--;
            $progress = true;
            if ($remaining <= 0) {
                break;
            }
        }
        if (!$progress) {
            break;
        }
    }

    foreach ($items as $index => &$item) {
        $item['total_discount'] = round(($allocated[$index] ?? 0) / 100, 4);
    }
    unset($item);

    return $items;
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
    $bonus_amount = max(0.0, hb_parse_money($input['bonus_amount'] ?? 0));
    if ($bonus_amount > $total) {
        $bonus_amount = $total;
    }

    hb_bootstrap_webasyst();

    $sku_model = new shopProductSkusModel();
    $order_items = [];
    $base_subtotal = 0.0;
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

        $client_price = hb_parse_money($row['price'] ?? 0);
        $compare_price = max(
            $client_price,
            hb_parse_money($row['compare_price'] ?? 0),
            hb_parse_money($row['old_price'] ?? 0),
            hb_parse_money($row['raw_compare_price'] ?? 0)
        );
        $base_price = $compare_price > 0 ? $compare_price : $client_price;

        $sku_rows = $sku_model->getByField('product_id', $product_id, true);
        if (empty($sku_rows) || !is_array($sku_rows)) {
            hb_respond(['status' => 'error', 'error_description' => 'Товар или SKU не найден: ' . $product_id], 400);
        }

        $sku_row = reset($sku_rows);
        $sku_id = isset($sku_row['id']) ? (int) $sku_row['id'] : 0;
        if ($sku_id <= 0) {
            hb_respond(['status' => 'error', 'error_description' => 'Товар или SKU не найден: ' . $product_id], 400);
        }

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

    $target_total_after_discount = max(0.0, round($total - $bonus_amount, 4));
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

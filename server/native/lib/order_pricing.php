<?php
/**
 * Pure helpers for create_order pricing.
 * Catalog SKU prices are authoritative; client totals cannot undercut them.
 */

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

/**
 * Resolve list/selling prices from a Webasyst SKU row.
 *
 * @return array{selling: float, list: float}|null
 */
function hb_resolve_sku_prices(array $sku_row)
{
    $selling = hb_parse_money($sku_row['price'] ?? 0);
    if ($selling <= 0) {
        return null;
    }

    $compare = hb_parse_money($sku_row['compare_price'] ?? 0);
    $list = $compare > $selling ? $compare : $selling;

    return [
        'selling' => round($selling, 4),
        'list' => round($list, 4),
    ];
}

/**
 * Clamp the payable target so client-supplied totals cannot undercut catalog.
 * Catalog selling − bonus is authoritative; client totals are ignored.
 *
 * @param mixed $client_total retained for call-site compatibility; not trusted
 */
function hb_clamp_payable_total($client_total, $catalog_selling_subtotal, $bonus_amount)
{
    $catalog_selling_subtotal = max(0.0, hb_parse_money($catalog_selling_subtotal));
    $bonus_amount = max(0.0, min(hb_parse_money($bonus_amount), $catalog_selling_subtotal));
    return round($catalog_selling_subtotal - $bonus_amount, 4);
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

/**
 * Stable YooKassa Idempotence-Key (no wall-clock time).
 */
function hb_yookassa_idempotence_key($order_id, $payment_token, $amount)
{
    $normalized_amount = number_format(hb_parse_money($amount), 2, '.', '');
    return md5((string) $order_id . '|' . (string) $payment_token . '|' . $normalized_amount);
}

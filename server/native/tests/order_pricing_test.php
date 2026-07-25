<?php
/**
 * Regression tests for create_order catalog price authority and idempotence keys.
 * Run: php server/native/tests/order_pricing_test.php
 */

require_once dirname(__DIR__) . '/lib/order_pricing.php';

function assert_true($cond, $message)
{
    if (!$cond) {
        fwrite(STDERR, "FAIL: $message\n");
        exit(1);
    }
    echo "OK: $message\n";
}

function assert_float_eq($actual, $expected, $message, $eps = 0.001)
{
    assert_true(abs((float) $actual - (float) $expected) <= $eps, $message . " (got {$actual}, expected {$expected})");
}

// Catalog prices win over client undercutting.
$sku = ['price' => '1990.00', 'compare_price' => '2490.00'];
$resolved = hb_resolve_sku_prices($sku);
assert_true($resolved !== null, 'sku prices resolve');
assert_float_eq($resolved['selling'], 1990.0, 'selling from catalog price');
assert_float_eq($resolved['list'], 2490.0, 'list from compare_price');

assert_true(hb_resolve_sku_prices(['price' => 0]) === null, 'zero catalog price rejected');

// Client total of 1 RUB must not undercut catalog 1990 − bonus 0.
$payable = hb_clamp_payable_total(1.0, 1990.0, 0.0);
assert_float_eq($payable, 1990.0, 'client undercut is clamped to catalog');

// Bonus reduces payable, but not below zero / not past catalog.
$payable_bonus = hb_clamp_payable_total(1.0, 1990.0, 100.0);
assert_float_eq($payable_bonus, 1890.0, 'bonus applied on catalog floor');

$payable_over_bonus = hb_clamp_payable_total(1990.0, 1990.0, 5000.0);
assert_float_eq($payable_over_bonus, 0.0, 'bonus capped to catalog subtotal');

// Inflated client totals are also ignored (catalog remains source of truth).
$payable_more = hb_clamp_payable_total(2500.0, 1990.0, 0.0);
assert_float_eq($payable_more, 1990.0, 'client overpay ignored');

// Discount allocation still sums to requested discount.
$items = [
    ['price' => 1000.0, 'quantity' => 1],
    ['price' => 1000.0, 'quantity' => 1],
];
$allocated = hb_allocate_discounts($items, 500.0);
$sum = $allocated[0]['total_discount'] + $allocated[1]['total_discount'];
assert_float_eq($sum, 500.0, 'allocated discount matches request');

// Idempotence key is stable across time (no wall clock).
$key1 = hb_yookassa_idempotence_key('order-1', 'token-abc', '1990.00');
usleep(20000);
$key2 = hb_yookassa_idempotence_key('order-1', 'token-abc', '1990.00');
assert_true($key1 === $key2, 'idempotence key stable for same inputs');
assert_true(
    $key1 !== hb_yookassa_idempotence_key('order-1', 'token-abc', '1990.01'),
    'idempotence key changes when amount changes'
);

echo "\nAll order pricing tests passed.\n";

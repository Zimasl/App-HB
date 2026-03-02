# Исправление ошибки create_order.php: commitOrder()

## Ошибка

```
Call to undefined method shopOrderModel::commitOrder()
```

В Webasyst / Shop-Script **нет** метода `shopOrderModel::commitOrder()`. Ошибка возникает на сервере в `create_order.php` (или в подключаемом классе/плагине).

## Что сделать на сервере

1. **Найти вызов `commitOrder()`**  
   В каталоге с приложением (например `wa-apps/shop/` или плагин, или ваш скрипт `native/create_order.php`) найдите вызов вида:
   - `$model->commitOrder(...)`
   - `$this->commitOrder(...)`
   - или аналогичный.

2. **Удалить или заменить этот вызов:**
   - Если заказ уже создаётся через **API** (`shop.order.add`), дополнительно вызывать `commitOrder()` не нужно — **просто удалите** вызов.
   - Если нужна именно «фиксация» заказа, в API Webasyst используются:
     - **`shop.order.add`** — создание заказа;
     - **`shop.order.save`** — сохранение изменений заказа;
     - **`shop.order.action`** с `action=pay` — отметка оплаты.

   Метода `commitOrder()` в стандартном API нет, поэтому его вызов нужно убрать или заменить на работу через `shop.order.add` / `shop.order.save`.

3. **Проверить create_order.php**  
   Убедитесь, что в `native/create_order.php` (или в подключаемом из него коде):
   - нет вызова `commitOrder()`;
   - создание заказа идёт через `shop.order.add` с полями: `items` (sku_id, quantity, stock_id), `contact_id`, при необходимости `params[payment_id]`;
   - для самовывоза передаётся нужный `stock_id` из пункта выдачи.

После правки PHP ошибка «Не удалось оформить заказ: Call to undefined method shopOrderModel::commitOrder()» исчезнет. В приложении текст ошибки от сервера дополнительно нормализуется (например, «Callto» → «Call to»).

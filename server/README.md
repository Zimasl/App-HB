# Серверная часть (шаблоны для hozyain-barin.ru)

Шаблоны PHP для Webasyst/Shop-Script и YooKassa. Скопируйте файлы на сервер в соответствующие каталоги под корень сайта (например `public_html/native/` или рядом с `wa-config`).

## Структура

```
config/
  yookassa_config.sample.php  — образец конфига YooKassa (скопировать в yookassa_config.php)
native/
  create_order.php            — создание заказа (без commitOrder)
  yookassa/
    pay_by_token.php          — создание платежа по токену (YooKassa API v3)
    payment_status.php        — статус платежа + отметка заказа «оплачен»
```

## create_order.php

- **Назначение:** создаёт заказ через `shopOrderModel->add()`. Метод `commitOrder()` не вызывается.
- **Вход (POST JSON):** `items`, `total`, `payment_method`, `delivery_method`, `address?`, `pickup_stock_id?`, `pickup_point_id?`.
- **Авторизация:** `contact_id` из `$_SESSION['contact_id']` или из тела запроса.
- **Путь к Webasyst:** в начале скрипта задаётся `$wa_root`; при необходимости измените путь к `wa-config/wa.php`.

## YooKassa

1. Скопируйте `config/yookassa_config.sample.php` в `config/yookassa_config.php` (или в `native/yookassa/config/yookassa_config.php`). Заполните `shop_id` и `secret_key` из личного кабинета YooKassa, при необходимости `return_url`.
2. **pay_by_token.php** — получает сумму заказа из Shop-Script, создаёт платёж в YooKassa по токену (API v3), возвращает `payment_id` и `confirmation_url`.
3. **payment_status.php** — запрашивает статус платежа в YooKassa; при `succeeded` отмечает заказ оплаченным через workflow (действие `pay`).

Файл `yookassa_config.php` не публикуйте в репозитории (в `server/.gitignore` он уже добавлен).

---

## Что дальше (развёртывание)

1. **Скопировать на сервер**  
   Содержимое `server/` разместите так, чтобы скрипты были доступны по тем же URL, что ждёт приложение:
   - `create_order.php` → `https://hozyain-barin.ru/native/create_order.php`
   - `pay_by_token.php` → `.../native/yookassa/pay_by_token.php`
   - `payment_status.php` → `.../native/yookassa/payment_status.php`  
   Конфиг можно положить в `server/config/` рядом с корнем сайта или в `native/yookassa/config/`.

2. **Путь к Webasyst**  
   В `create_order.php` и в скриптах YooKassa в начале задаётся `$wa_root`. Если `wa-config/wa.php` у вас лежит в другом месте (например, на уровень выше `public_html`), измените проверку пути.

3. **Сессия и contact_id**  
   Убедитесь, что после авторизации в приложении (SMS/логин) в PHP сохраняется `$_SESSION['contact_id']` (например, в `auth_sms.php`), иначе создание заказа вернёт «Необходима авторизация».

4. **YooKassa**  
   Создайте `yookassa_config.php` из `yookassa_config.sample.php`, укажите `shop_id` и `secret_key` из личного кабинета YooKassa. Для тестов используйте тестовые ключи (`test_...`).

5. **Проверка**  
   После выкладки оформите тестовый заказ с оплатой «Онлайн» в приложении: заказ должен создаваться, открываться экран YooKassa, после успешной оплаты статус заказа в магазине должен смениться на «Оплачен».

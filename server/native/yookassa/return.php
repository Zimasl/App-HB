<?php
/**
 * Страница возврата после оплаты YooKassa (redirect).
 * Пользователь попадает сюда по return_url после оплаты в браузере.
 * Можно показать «Оплата принята» или редирект в приложение по схеме yookassapaymentsflutter://
 */
header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Оплата — Хозяин Барин</title>
    <style>
        body { font-family: -apple-system, sans-serif; padding: 2rem; text-align: center; }
        .msg { margin: 2rem 0; font-size: 1.1rem; }
        a { color: #0066cc; }
    </style>
</head>
<body>
    <p class="msg">Спасибо. Оплата принята в обработку.</p>
    <p>Вернитесь в приложение — статус заказа обновится автоматически.</p>
    <p><a href="yookassapaymentsflutter://">Открыть приложение</a></p>
</body>
</html>

<?php
/**
 * Настройки YooKassa. Скопируйте как yookassa_config.php и укажите свои данные.
 * Файл yookassa_config.php не должен попадать в публичный репозиторий.
 */
return [
    'shop_id'   => '123456',           // Идентификатор магазина из личного кабинета YooKassa
    'secret_key' => 'live_xxxxxxxxxx', // Секретный ключ (test_... или live_...)
    'return_url' => 'https://hozyain-barin.ru/native/yookassa/return.php', // Куда вернуть пользователя после оплаты (опционально)
];

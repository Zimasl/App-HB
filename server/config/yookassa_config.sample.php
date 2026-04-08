<?php
/**
 * Настройки YooKassa. Скопируйте как yookassa_config.php и укажите свои данные.
 * Файл yookassa_config.php не должен попадать в публичный репозиторий.
 */
return [
    'shop_id'   => '123456',           // Идентификатор магазина из личного кабинета YooKassa
    'secret_key' => 'live_xxxxxxxxxx', // Секретный ключ (test_... или live_...)
    'return_url' => 'https://hozyain-barin.ru/native/yookassa/return.php', // Куда вернуть пользователя после оплаты (опционально)
    'tax_system_code' => 2,            // Код системы налогообложения: 1=ОСН, 2=УСН доходы, 3=УСН доходы-расходы, 4=ЕНВД, 5=ЕСХН, 6=патент
    'vat_code' => 8,                   // Код ставки НДС для чеков YooKassa/FNS: 8=7%, 10=7/107, 11=22%, 4=20%, 3=10%, 2=0%, 1=без НДС
    'payment_mode' => 'full_payment',  // Режим расчета для чека
    'payment_subject' => 'commodity',  // Предмет расчета для товарных позиций
];

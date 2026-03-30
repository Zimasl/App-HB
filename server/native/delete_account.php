<?php
declare(strict_types=1);

// /native/delete_account.php

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
}

header('Content-Type: application/json; charset=utf-8');
ini_set('display_errors', '0');
error_reporting(0);

const DELETE_CODE_TTL = 300;

function respond(array $payload, int $statusCode = 200): void
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function get_input(): array
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        respond(['status' => 'error', 'message' => 'Method not allowed'], 405);
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

function normalize_phone(string $rawPhone): string
{
    $phone = preg_replace('/[^\d]/', '', $rawPhone) ?? '';
    if (strlen($phone) === 11 && $phone[0] === '8') {
        $phone[0] = '7';
    }
    return $phone;
}

function mask_phone(string $phone): string
{
    if (strlen($phone) !== 11) {
        return $phone;
    }

    return '+7 (' . substr($phone, 1, 3) . ') ***-**-' . substr($phone, -2);
}

function current_contact_id(): int
{
    $contactId = (int)($_SESSION['hb_contact_id'] ?? 0);
    if ($contactId <= 0) {
        $contactId = (int)($_SESSION['contact_id'] ?? 0);
    }
    return $contactId;
}

function get_contact_phone(waModel $model, int $contactId): string
{
    $value = $model
        ->query(
            "SELECT value
             FROM wa_contact_data
             WHERE contact_id = ? AND field = 'phone'
             ORDER BY sort ASC, id ASC
             LIMIT 1",
            $contactId
        )
        ->fetchField();

    return normalize_phone((string)$value);
}

function logout_user(): void
{
    try {
        $auth = wa()->getAuth();
        if (is_object($auth)) {
            if (method_exists($auth, 'logout')) {
                $auth->logout();
            } elseif (method_exists($auth, 'clearAuth')) {
                $auth->clearAuth();
            }
        }
    } catch (Throwable $e) {
    }

    unset($_SESSION['hb_contact_id'], $_SESSION['contact_id']);

    if (session_status() === PHP_SESSION_ACTIVE) {
        $_SESSION = [];

        if (ini_get('session.use_cookies')) {
            $params = session_get_cookie_params();
            setcookie(
                session_name(),
                '',
                time() - 42000,
                $params['path'] ?? '/',
                $params['domain'] ?? '',
                (bool)($params['secure'] ?? false),
                (bool)($params['httponly'] ?? true)
            );
        }

        session_destroy();
    }
}

try {
    $path = dirname(__FILE__) . '/../wa-config/SystemConfig.class.php';
    if (!file_exists($path)) {
        respond(['status' => 'error', 'message' => 'System config not found'], 500);
    }

    require_once $path;

    $config = new SystemConfig();
    waSystem::getInstance(null, $config);
    wa('shop');

    $model = new waModel();

    $model->exec("
        CREATE TABLE IF NOT EXISTS `wa_temp_delete_sms` (
            `contact_id` INT(11) NOT NULL,
            `phone` VARCHAR(20) NOT NULL,
            `code` VARCHAR(10) NOT NULL,
            `expires_at` INT(11) NOT NULL,
            PRIMARY KEY (`contact_id`)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8
    ");

    $input = get_input();
    $action = trim((string)($input['action'] ?? ''));

    if ($action === 'send_delete_code') {
        $contactId = current_contact_id();
        if ($contactId <= 0) {
            respond(['status' => 'error', 'message' => 'Пользователь не авторизован'], 401);
        }

        $postedContactId = (int)($input['contact_id'] ?? 0);
        if ($postedContactId > 0 && $postedContactId !== $contactId) {
            respond(['status' => 'error', 'message' => 'Некорректный contact_id'], 400);
        }

        $phone = get_contact_phone($model, $contactId);
        if ($phone === '') {
            respond(['status' => 'error', 'message' => 'У аккаунта не найден телефон'], 400);
        }

        $code = (string)rand(1000, 9999);
        $text = 'Код удаления аккаунта: ' . $code;

        $sms = new waSMS();
        $sent = $sms->send($phone, $text);

        if ($sent === false) {
            respond(['status' => 'error', 'message' => 'Не удалось отправить SMS'], 500);
        }

        $model->exec(
            "REPLACE INTO `wa_temp_delete_sms` (contact_id, phone, code, expires_at) VALUES (?, ?, ?, ?)",
            $contactId,
            $phone,
            $code,
            time() + DELETE_CODE_TTL
        );

        respond([
            'status' => 'ok',
            'message' => 'Код отправлен',
            'phone_masked' => mask_phone($phone),
            'ttl' => DELETE_CODE_TTL,
        ]);
    }

    if ($action === 'delete_account') {
        $contactId = current_contact_id();
        if ($contactId <= 0) {
            respond(['status' => 'error', 'message' => 'Пользователь не авторизован'], 401);
        }

        $postedContactId = (int)($input['contact_id'] ?? 0);
        if ($postedContactId > 0 && $postedContactId !== $contactId) {
            respond(['status' => 'error', 'message' => 'Некорректный contact_id'], 400);
        }

        $inputCode = trim((string)($input['code'] ?? ''));
        if ($inputCode === '') {
            respond(['status' => 'error', 'message' => 'Введите код'], 400);
        }

        $row = $model
            ->query(
                "SELECT phone, code, expires_at
                 FROM `wa_temp_delete_sms`
                 WHERE contact_id = ?",
                $contactId
            )
            ->fetchAssoc();

        if (!$row) {
            respond(['status' => 'error', 'message' => 'Сначала запросите код'], 400);
        }

        $storedPhone = normalize_phone((string)($row['phone'] ?? ''));
        if ((int)($row['expires_at'] ?? 0) < time()) {
            $model->exec("DELETE FROM `wa_temp_delete_sms` WHERE contact_id = ?", $contactId);
            respond(['status' => 'error', 'message' => 'Код истек'], 400);
        }

        if ((string)$row['code'] !== $inputCode) {
            respond(['status' => 'error', 'message' => 'Неверный код'], 400);
        }

        $exists = (int)$model
            ->query("SELECT id FROM `wa_contact` WHERE id = ?", $contactId)
            ->fetchField();

        if ($exists <= 0) {
            respond(['status' => 'error', 'message' => 'Контакт не найден'], 404);
        }

        try {
            $model->exec(
                "UPDATE `wa_contact`
                 SET `name` = ?, `firstname` = ?, `lastname` = ?
                 WHERE `id` = ?
                 LIMIT 1",
                'Deleted user',
                'Deleted',
                'User',
                $contactId
            );

            try {
                $model->exec("DELETE FROM `wa_contact_emails` WHERE `contact_id` = ?", $contactId);
            } catch (Throwable $ignored) {
            }

            $model->exec("DELETE FROM `wa_contact_data` WHERE `contact_id` = ?", $contactId);

            if ($storedPhone !== '') {
                try {
                    $model->exec("DELETE FROM `wa_temp_sms` WHERE `phone` = ?", $storedPhone);
                } catch (Throwable $ignored) {
                }
            }

            try {
                $model->exec("DELETE FROM `wa_temp_delete_sms` WHERE `contact_id` = ?", $contactId);
            } catch (Throwable $ignored) {
            }

            try {
                $contact = new waContact($contactId);
                $contact->save();
            } catch (Throwable $ignored) {
            }
        } catch (Throwable $e) {
            try {
                $model->exec("DELETE FROM `wa_temp_sms` WHERE `phone` = ?", $storedPhone);
            } catch (Throwable $ignored2) {
            }
            throw $e;
        }

        logout_user();

        respond([
            'status' => 'ok',
            'message' => 'Аккаунт удален',
        ]);
    }

    respond(['status' => 'error', 'message' => 'Unknown action'], 400);
} catch (Throwable $e) {
    respond([
        'status' => 'error',
        'message' => $e->getMessage(),
    ], 500);
}

class AppConfig {
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'prod',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hozyain-barin.ru',
  );

  static const String yookassaShopId = String.fromEnvironment(
    'YOOKASSA_SHOP_ID',
  );

  /// Публичный ключ YooKassa для мобильного SDK (Client Application Key).
  /// НЕ secretKey из настроек Shop‑Script.
  static const String yookassaClientKey = String.fromEnvironment(
    'YOOKASSA_CLIENT_KEY',
  );

  /// Public OneSignal app id for the current build.
  /// Defaults to the production app id and can be overridden via dart-define.
  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '0f2f4f43-c8b4-475c-be74-9ed6045bae52',
  );

  /// API key used for Yandex geocoder and suggest endpoints.
  static const String yandexSuggestApiKey = String.fromEnvironment(
    'YANDEX_SUGGEST_API_KEY',
  );

  static bool get isDev => flavor == 'dev';

  static void validatePayments() {
    if (yookassaShopId.isEmpty || yookassaClientKey.isEmpty) {
      throw StateError(
        'YooKassa keys are not set. Pass '
        '--dart-define=YOOKASSA_SHOP_ID and --dart-define=YOOKASSA_CLIENT_KEY',
      );
    }
  }
}

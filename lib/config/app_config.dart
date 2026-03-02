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
    defaultValue: '1287491',
  );

  /// Публичный ключ YooKassa для мобильного SDK (Client Application Key).
  /// НЕ secretKey из настроек Shop‑Script.
  static const String yookassaClientKey = String.fromEnvironment(
    'YOOKASSA_CLIENT_KEY',
    defaultValue: 'test_MTI4NzQ5MSLV2Ulh0CgjCQ0pYoRnave2d6RpiJnKjKE',
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

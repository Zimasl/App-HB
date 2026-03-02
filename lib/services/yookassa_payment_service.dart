import 'package:dio/dio.dart';
import 'package:yookassa_payments_flutter/yookassa_payments_flutter.dart';

import '../config/app_config.dart';

class YookassaPaymentException implements Exception {
  final String message;
  const YookassaPaymentException(this.message);
  @override
  String toString() => message;
}

class YookassaPaymentResult {
  final String orderId;
  final String? orderNumber;
  final String paymentId;
  final String status; // pending/succeeded/canceled

  const YookassaPaymentResult({
    required this.orderId,
    required this.orderNumber,
    required this.paymentId,
    required this.status,
  });
}

class YookassaPaymentService {
  final Dio dio;

  const YookassaPaymentService({required this.dio});

  Future<YookassaPaymentResult> payOrder({
    required String orderId,
    required String? orderNumber,
    required String amountRub,
    required String title,
    required String subtitle,
    String? userPhoneNumber,
    bool enableLogging = false,
  }) async {
    AppConfig.validatePayments();

    final tokenizationInput = TokenizationModuleInputData(
      clientApplicationKey: AppConfig.yookassaClientKey,
      title: title,
      subtitle: subtitle,
      amount: Amount(value: amountRub, currency: Currency.rub),
      shopId: AppConfig.yookassaShopId,
      savePaymentMethod: SavePaymentMethod.off,
      isLoggingEnabled: enableLogging,
      userPhoneNumber: userPhoneNumber,
      applicationScheme: 'yookassapaymentsflutter://',
    );

    final tokenizationResult = await YookassaPaymentsFlutter.tokenization(
      tokenizationInput,
    );

    if (tokenizationResult is CanceledTokenizationResult) {
      throw const YookassaPaymentException('Оплата отменена пользователем');
    }
    if (tokenizationResult is ErrorTokenizationResult) {
      throw YookassaPaymentException(
        'Ошибка YooKassa SDK: ${tokenizationResult.error}',
      );
    }
    if (tokenizationResult is! SuccessTokenizationResult) {
      throw const YookassaPaymentException('Неизвестный результат токенизации');
    }

    final paymentToken = tokenizationResult.token;
    final paymentMethodType = tokenizationResult.paymentMethodType?.name;

    final payResponse = await dio.post(
      '/native/yookassa/pay_by_token.php',
      data: {
        'order_id': orderId,
        'payment_token': paymentToken,
        'payment_method_type': paymentMethodType,
        'amount': amountRub,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    final payData = _asMap(payResponse.data);
    final payStatus = payData['status']?.toString() ?? '';
    final paymentId = payData['payment_id']?.toString() ?? '';
    final confirmationUrl = payData['confirmation_url']?.toString();

    if (payStatus.isEmpty || paymentId.isEmpty) {
      throw const YookassaPaymentException(
        'Сервер не вернул payment_id/status',
      );
    }

    if (confirmationUrl != null && confirmationUrl.trim().isNotEmpty) {
      await YookassaPaymentsFlutter.confirmation(
        confirmationUrl.trim(),
        tokenizationResult.paymentMethodType,
        AppConfig.yookassaClientKey,
        AppConfig.yookassaShopId,
      );
    }

    final finalStatus = await _pollStatus(
      orderId: orderId,
      paymentId: paymentId,
    );

    return YookassaPaymentResult(
      orderId: orderId,
      orderNumber: orderNumber,
      paymentId: paymentId,
      status: finalStatus,
    );
  }

  Future<String> _pollStatus({
    required String orderId,
    required String paymentId,
  }) async {
    const maxAttempts = 20;
    const delay = Duration(seconds: 2);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final resp = await dio.post(
        '/native/yookassa/payment_status.php',
        data: {'order_id': orderId, 'payment_id': paymentId},
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = _asMap(resp.data);
      final status =
          data['payment_status']?.toString().toLowerCase() ??
          data['status']?.toString().toLowerCase() ??
          '';
      if (status == 'succeeded' ||
          status == 'canceled' ||
          status == 'pending') {
        if (status != 'pending') return status;
      }
      await Future<void>.delayed(delay);
    }
    return 'pending';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const YookassaPaymentException('Некорректный ответ сервера');
  }
}

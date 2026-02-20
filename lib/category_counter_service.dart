import 'dart:convert';
import 'package:dio/dio.dart';

class CategoryCounterService {
  // Глобальное хранилище данных
  static Map<String, dynamic> _counts = {};
  static bool isLoading = false;
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0',
      },
      validateStatus: (_) => true,
    ),
  );

  // URL нашего нового эндпоинта
  static const String _url = 'https://hozyain-barin.ru/native/counts.php';

  /// Загрузка данных с сервера
  static Future<void> loadCounts() async {
    isLoading = true;
    try {
      final response = await _dio.getUri(
        Uri.parse(_url),
        options: Options(responseType: ResponseType.plain),
      );
      if ((response.statusCode ?? 0) == 200) {
        final raw = response.data?.toString() ?? '';
        _counts = json.decode(raw);
        // ignore: avoid_print
        print('Счётчики категорий успешно обновлены');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Ошибка при загрузке счётчиков: $e');
    } finally {
      isLoading = false;
    }
  }

  /// Получение количества товаров по ID категории
  static String getCount(dynamic categoryId) {
    final String key = categoryId.toString();
    if (_counts.containsKey(key)) {
      return _counts[key].toString();
    }
    return '0';
  }
}

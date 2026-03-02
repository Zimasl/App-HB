import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:yandex_mapkit_lite/yandex_mapkit_lite.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'category_counter_service.dart';

// Стиль текста для меню
const TextStyle _menuStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 16,
  color: Colors.black87,
  letterSpacing: 0,
);
const TextStyle _subMenuStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 15,
  color: Colors.black87,
  letterSpacing: 0,
);
const TextStyle _boldMenuStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 16,
  fontWeight: FontWeight.bold,
  color: Colors.black,
  letterSpacing: 0,
);
const TextStyle _boldSubMenuStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 15,
  fontWeight: FontWeight.bold,
  color: Colors.black,
  letterSpacing: 0,
);
const TextStyle _modalHeaderStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 20,
  fontWeight: FontWeight.normal,
  color: Colors.black,
  letterSpacing: 0,
);
const Color _starColor = Color(0xFFF4A21D);
const String _deliveryAddressPinAssetPath = 'assets/images/map_address.png';
const String _userPinAssetPath = 'assets/images/map_user_pin.png';
const String _shopPinAssetPath = 'assets/images/map_shop.png';
const String _shopManyPinAssetPath = 'assets/images/map_shop_many.png';
const double _mapPlacemarkOpacity = 0.86;
const MethodChannel _iosLocationPermissionChannel = MethodChannel(
  'hozyain/location_permission',
);
const TextStyle _cardPriceStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 17,
  fontWeight: FontWeight.bold,
  color: Colors.black,
  letterSpacing: 0,
);
const TextStyle _cardOldPriceStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 12,
  color: Color(0xFFBDBDBD),
  decoration: TextDecoration.lineThrough,
  letterSpacing: 0,
);
const TextStyle _cardNameStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 13,
  color: Colors.black87,
  height: 1.2,
  letterSpacing: 0.1,
);
const Set<String> _newCategoryIds = {"147"};
const String _shopApiToken = "f616081435730714b089ec1115bac63b";
const double _catalogBackSwipeEdgeWidth = 24;
const double _catalogBackSwipeMinDistance = 72;
const double _catalogBackSwipeMaxVerticalDrift = 96;
const double _catalogBackSwipeCompleteRatio = 0.28;
const Duration _catalogBackSwipeSettleDuration = Duration(milliseconds: 190);
const int _maxNativeCategoryHistoryDepth = 40;

/// Ключ для подсказок и геокодера. Варианты в кабинете:
/// — «JavaScript API и HTTP Геокодер» (рекомендуется для suggest-geo);
/// — «API Геосаджеста» для v1/suggest.
const String _yandexSuggestApiKey = '96ed130b-bc4c-4b17-a60f-a6a775f1af34';

Widget _buildBottomSheetHandle() {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

Dio? _authDio;

Route<T> _adaptivePageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  if (Platform.isIOS) {
    return CupertinoPageRoute<T>(builder: builder, settings: settings);
  }
  return MaterialPageRoute<T>(builder: builder, settings: settings);
}

class _SimpleHttpResponse {
  final int statusCode;
  final Uint8List bodyBytes;

  const _SimpleHttpResponse({
    required this.statusCode,
    required this.bodyBytes,
  });

  String get body => utf8.decode(bodyBytes, allowMalformed: true);

  factory _SimpleHttpResponse.fromString(String body, int statusCode) {
    return _SimpleHttpResponse(
      statusCode: statusCode,
      bodyBytes: Uint8List.fromList(utf8.encode(body)),
    );
  }
}

Uint8List _responseDataToBytes(dynamic data) {
  if (data is Uint8List) return data;
  if (data is List<int>) return Uint8List.fromList(data);
  if (data is String) return Uint8List.fromList(utf8.encode(data));
  if (data == null) return Uint8List(0);
  return Uint8List.fromList(utf8.encode(data.toString()));
}

String _responseDataToString(dynamic data) {
  if (data is String) return data;
  if (data is Uint8List) return utf8.decode(data, allowMalformed: true);
  if (data is List<int>) return utf8.decode(data, allowMalformed: true);
  if (data == null) return '';
  return data.toString();
}

Dio _getAuthDio() {
  if (_authDio != null) return _authDio!;
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://hozyain-barin.ru',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0',
      },
    ),
  );
  final jar = CookieJar();
  dio.interceptors.add(CookieManager(jar));
  _authDio = dio;
  return dio;
}

Future<_SimpleHttpResponse> _httpGet(
  Uri uri, {
  Map<String, String>? headers,
}) async {
  final dio = _getAuthDio();
  final response = await dio.getUri(
    uri,
    options: Options(
      responseType: ResponseType.bytes,
      headers: headers,
      validateStatus: (_) => true,
    ),
  );
  return _SimpleHttpResponse(
    statusCode: response.statusCode ?? 0,
    bodyBytes: _responseDataToBytes(response.data),
  );
}

Dio? _yandexDio;
Dio _getYandexDio() {
  if (_yandexDio != null) return _yandexDio!;
  _yandexDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        'Referer': 'https://yandex.ru/',
      },
    ),
  );
  return _yandexDio!;
}

Future<_SimpleHttpResponse> _httpGetYandex(Uri uri) async {
  final dio = _getYandexDio();
  final response = await dio.getUri(
    uri,
    options: Options(
      responseType: ResponseType.bytes,
      validateStatus: (_) => true,
    ),
  );
  return _SimpleHttpResponse(
    statusCode: response.statusCode ?? 0,
    bodyBytes: _responseDataToBytes(response.data),
  );
}

Map<String, dynamic>? _parseAuthResponse(dynamic data) {
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String) {
    try {
      final decoded = json.decode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

String? _authContactId;
String? _authUserName;
String? _authPhone;
String? _authPhotoUrl;
bool get _isAuthorized =>
    _authContactId != null &&
    _authContactId!.isNotEmpty &&
    _authUserName != null &&
    _authUserName!.trim().isNotEmpty;

String _formatPhoneMasked(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return "";
  var num = digits;
  if (num.length == 11 && (num.startsWith('7') || num.startsWith('8'))) {
    num = num.substring(1);
  } else if (num.length > 10) {
    num = num.substring(num.length - 10);
  }
  final formatter = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  formatter.formatEditUpdate(
    const TextEditingValue(),
    TextEditingValue(text: num),
  );
  return formatter.getMaskedText();
}

bool _isDefaultUserpic(String url) {
  final lower = url.toLowerCase();
  return lower.contains('/wa-content/img/userpic') ||
      lower.contains('userpic.svg');
}

Map<String, dynamic>? _storesHierarchyForModalCache;
Future<Map<String, dynamic>?>? _storesHierarchyForModalInFlight;

Future<Map<String, dynamic>?> _getStoresHierarchyForModal() async {
  if (_storesHierarchyForModalCache != null) {
    return _storesHierarchyForModalCache;
  }
  _storesHierarchyForModalInFlight ??= () async {
    try {
      final uri = Uri.parse(
        'https://hozyain-barin.ru/native/stores_hierarchy.json',
      );
      final response = await _httpGet(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0',
        },
      );
      if (response.statusCode != 200) return null;
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }();
  final r = await _storesHierarchyForModalInFlight!;
  _storesHierarchyForModalInFlight = null;
  if (r != null) _storesHierarchyForModalCache = r;
  return _storesHierarchyForModalCache;
}

Set<String> _extractExcludedStockIdsFromHierarchy(
  Map<String, dynamic>? hierarchy,
) {
  if (hierarchy == null) return {};
  final settings = hierarchy['settings'];
  final exclude = (settings is Map) ? settings['exclude_ids'] : null;
  if (exclude is! List) return {};
  return exclude.where((id) => id != null).map((id) => id.toString()).toSet();
}

Map<String, int> _filterStockMapByExclude(
  Map<String, int> stockMap,
  Set<String> excludeIds,
) {
  if (excludeIds.isEmpty) return stockMap;
  final filtered = <String, int>{};
  stockMap.forEach((id, count) {
    if (count <= 0) return;
    if (excludeIds.contains(id)) return;
    filtered[id] = count;
  });
  return filtered;
}

String _resolveStockNameById(List<dynamic> availableStocks, String stockId) {
  for (final stock in availableStocks) {
    if (stock is! Map) continue;
    final id = stock['id']?.toString() ?? "";
    if (id != stockId) continue;
    final name = stock['name']?.toString() ?? "";
    if (name.isNotEmpty) return name;
  }
  return stockId;
}

String _resolveStockCity(dynamic stock) {
  if (stock is! Map) return "";
  final city = stock['city']?.toString().trim() ?? "";
  if (city.isNotEmpty) return city;
  final name = stock['name']?.toString() ?? "";
  final match = RegExp(r'\(([^)]+)\)').firstMatch(name);
  return match?.group(1)?.trim() ?? "";
}

List<Map<String, dynamic>> _buildStockEntriesForModal(
  Map<String, int> stockMap,
  List<dynamic> availableStocks,
) {
  final entries = <Map<String, dynamic>>[];
  final usedIds = <String>{};
  for (final stock in availableStocks) {
    if (stock is! Map) continue;
    final sid = stock['id']?.toString() ?? "";
    if (sid.isEmpty) continue;
    final count = stockMap[sid] ?? 0;
    if (count <= 0) continue;
    final name = stock['name']?.toString() ?? sid;
    final city = _resolveStockCity(stock);
    entries.add({"city": city, "name": name, "count": count});
    usedIds.add(sid);
  }
  for (final entry in stockMap.entries) {
    if (usedIds.contains(entry.key)) continue;
    if (entry.value <= 0) continue;
    entries.add({"city": "", "name": entry.key, "count": entry.value});
  }
  return entries;
}

Map<String, List<Map<String, dynamic>>> _groupStockEntriesForModal(
  List<Map<String, dynamic>> entries,
) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final entry in entries) {
    final city = entry["city"]?.toString().trim() ?? "";
    final key = city.isNotEmpty ? city : "Магазины";
    grouped.putIfAbsent(key, () => []).add(entry);
  }
  return grouped;
}

List<Map<String, dynamic>> _buildHierarchyGroupsForModal(
  Map<String, int> stockMap,
  Map<String, dynamic> hierarchy,
  List<dynamic> availableStocks,
) {
  final cities = hierarchy['cities'];
  if (cities is! List) return [];
  final groups = <Map<String, dynamic>>[];
  for (final cityEntry in cities) {
    if (cityEntry is! Map) continue;
    final title = cityEntry['group_name']?.toString().trim() ?? "";
    if (title.isEmpty) continue;
    final stocks = cityEntry['stocks'];
    if (stocks is! List) continue;
    final items = <Map<String, dynamic>>[];
    for (final stock in stocks) {
      if (stock is! Map) continue;
      final id = stock['id']?.toString() ?? "";
      if (id.isEmpty) continue;
      final count = stockMap[id] ?? 0;
      if (count <= 0) continue;
      final name = stock['name']?.toString().trim();
      items.add({
        "name": (name == null || name.isEmpty)
            ? _resolveStockNameById(availableStocks, id)
            : name,
        "count": count,
      });
    }
    if (items.isNotEmpty) groups.add({"title": title, "items": items});
  }
  return groups;
}

List<Map<String, dynamic>> _buildFallbackGroupsForModal(
  Map<String, int> stockMap,
  List<dynamic> availableStocks,
) {
  final entries = _buildStockEntriesForModal(stockMap, availableStocks);
  final grouped = _groupStockEntriesForModal(entries);
  return grouped.entries
      .map((e) => {"title": e.key, "items": e.value})
      .toList();
}

int _sumGroupCountsForModal(List<Map<String, dynamic>> groups) {
  int total = 0;
  for (final group in groups) {
    final items = group["items"];
    if (items is! List) continue;
    for (final item in items) {
      if (item is! Map) continue;
      total += item["count"] as int? ?? 0;
    }
  }
  return total;
}

Widget _buildStockRowForModal({required String name, required int count}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        flex: 3,
        child: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _subMenuStyle.copyWith(fontSize: 14, color: Colors.black87),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const dotWidth = 2.0;
            const gap = 3.0;
            final dotCount = (constraints.maxWidth / (dotWidth + gap)).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                dotCount,
                (_) => Container(
                  width: dotWidth,
                  height: dotWidth,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 52,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            "$count шт.",
            textAlign: TextAlign.right,
            style: _subMenuStyle.copyWith(fontSize: 14, color: Colors.black54),
          ),
        ),
      ),
    ],
  );
}

List<String> _extractCategoryIdsForIsolate(Map<dynamic, dynamic> product) {
  final ids = <String>{};
  void addId(dynamic value) {
    if (value == null) return;
    final s = value.toString();
    if (s.isNotEmpty) ids.add(s);
  }

  addId(product['category_id']);
  addId(product['categoryId']);
  addId(product['category']);
  addId(product['cat_id']);

  final dynamic categories =
      product['category_ids'] ??
      product['categoryIds'] ??
      product['categories'] ??
      product['category_list'];

  if (categories is List) {
    for (final item in categories) {
      if (item is Map) {
        addId(item['id']);
        addId(item['category_id']);
      } else {
        addId(item);
      }
    }
  } else if (categories is Map) {
    for (final entry in categories.entries) {
      addId(entry.key);
      final value = entry.value;
      if (value is Map) {
        addId(value['id']);
        addId(value['category_id']);
      } else if (value is List) {
        for (final item in value) {
          if (item is Map) {
            addId(item['id']);
            addId(item['category_id']);
          } else {
            addId(item);
          }
        }
      } else {
        addId(value);
      }
    }
  }

  return ids.toList(growable: false);
}

Map<String, dynamic> _parseNativeCategoryPayload(String body) {
  final decoded = json.decode(body);
  final data = (decoded is Map && decoded.containsKey('data'))
      ? decoded['data']
      : decoded;
  List<dynamic> products = [];

  if (data is Map && data.containsKey('products')) {
    final rawProducts = data['products'];
    if (rawProducts is List) {
      products = rawProducts;
    } else if (rawProducts is Map) {
      products = rawProducts.values.toList();
    }
  } else if (data is List) {
    products = data;
  } else if (data is Map) {
    products = data.values.toList();
  }

  final List<Map<String, dynamic>> items = [];
  final sizeRegex = RegExp(r'\.\d+x\d+\.');

  for (final p in products) {
    if (p is! Map) continue;
    if (!_isVisibleProductForIsolate(p)) continue;

    final price = double.tryParse(p['price']?.toString() ?? "0") ?? 0;
    final comparePrice =
        double.tryParse(p['compare_price']?.toString() ?? "0") ?? 0;
    String mainImg = (p['image_url'] ?? "").toString();
    if (mainImg.isNotEmpty) {
      mainImg = mainImg.replaceAll(sizeRegex, '.0x400.');
    }
    final categoryIds = _extractCategoryIdsForIsolate(p);
    final String categoryId = p['category_id']?.toString() ?? "";

    String? discountText;
    String? benefitText;
    if (comparePrice > price && comparePrice > 0) {
      final int percent = (((comparePrice - price) / comparePrice) * 100)
          .round();
      if (percent > 0) {
        discountText = "- $percent%";
        final int benefit = (comparePrice - price).round();
        if (benefit > 0) {
          benefitText =
              "ВЫГОДА ${_formatPriceForIsolate(benefit.toDouble())} ₽";
        }
      }
    }

    items.add({
      "id": p['id'].toString(),
      "name": p['name']?.toString() ?? "",
      "price": "${_formatPriceForIsolate(price)} ₽",
      "raw_price": price,
      "raw_compare_price": comparePrice,
      "old_price": comparePrice > price
          ? "${_formatPriceForIsolate(comparePrice)} ₽"
          : "",
      if (discountText != null) "discount": discountText,
      if (benefitText != null) "benefit": benefitText,
      "images": [mainImg],
      "link": "/product/${p['url']}/",
      "category_ids": categoryIds,
      if (categoryId.isNotEmpty) "category_id": categoryId,
    });
  }

  return {"items": items, "fetchedCount": products.length};
}

double _parsePriceValueForIsolate(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final cleaned = value
        .replaceAll(RegExp(r'[^0-9.,]'), '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }
  return 0.0;
}

List<dynamic> _filterProductsByPrice(Map<String, dynamic> payload) {
  final products = (payload['products'] as List?) ?? const [];
  final minPrice = (payload['minPrice'] as num?)?.toDouble() ?? 0.0;
  final maxPrice = (payload['maxPrice'] as num?)?.toDouble() ?? double.infinity;
  final mode = payload['mode']?.toString() ?? 'raw';
  final List<dynamic> filtered = [];
  for (final item in products) {
    if (item is! Map) continue;
    dynamic raw = item['raw_price'];
    raw ??= item['price'];
    final double price = (mode == 'parse')
        ? _parsePriceValueForIsolate(raw)
        : ((raw is num)
              ? raw.toDouble()
              : double.tryParse(raw?.toString() ?? "0") ?? 0.0);
    if (price >= minPrice && price <= maxPrice) {
      filtered.add(item);
    }
  }
  return filtered;
}

List<dynamic> _sortProductsByCriteria(Map<String, dynamic> payload) {
  final List<dynamic> products = List<dynamic>.from(
    (payload['products'] as List?) ?? const [],
  );
  final String criteria = payload['criteria']?.toString() ?? "default";

  double rawPrice(dynamic item) {
    if (item is! Map) return 0.0;
    dynamic raw = item['raw_price'];
    raw ??= item['price'];
    return (raw is num)
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? "0") ?? 0.0;
  }

  double comparePrice(dynamic item) {
    if (item is! Map) return 0.0;
    dynamic raw = item['raw_compare_price'] ?? item['compare_price'];
    return (raw is num)
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? "0") ?? 0.0;
  }

  int idValue(dynamic item) {
    if (item is! Map) return 0;
    return int.tryParse(item['id']?.toString() ?? "") ?? 0;
  }

  int compare(dynamic a, dynamic b) {
    switch (criteria) {
      case "price_asc":
        return rawPrice(a).compareTo(rawPrice(b));
      case "price_desc":
        return rawPrice(b).compareTo(rawPrice(a));
      case "newest":
        return idValue(b).compareTo(idValue(a));
      case "discount":
        final discA = comparePrice(a) - rawPrice(a);
        final discB = comparePrice(b) - rawPrice(b);
        return discB.compareTo(discA);
      default:
        return 0;
    }
  }

  products.sort(compare);
  return products;
}

bool _isVisibleProductForIsolate(Map<dynamic, dynamic> product) {
  final status = product['status']?.toString();
  if (status == "0") return false;
  final countRaw = product['count'];
  if (countRaw != null) {
    final count = double.tryParse(countRaw.toString()) ?? 0;
    if (count <= 0) return false;
  }
  return true;
}

String _formatPriceForIsolate(double price) {
  return price.toInt().toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]} ',
  );
}

void _configureAndroidImagePicker() {
  if (!Platform.isAndroid) return;
  final instance = ImagePickerPlatform.instance;
  if (instance is ImagePickerAndroid) {
    instance.useAndroidPhotoPicker = false;
    return;
  }
  final android = ImagePickerAndroid()..useAndroidPhotoPicker = false;
  ImagePickerPlatform.instance = android;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    // Recommended for smoother Flutter/UI interaction with platform views.
    AndroidYandexMap.useAndroidViewSurface = false;
  }
  debugPrint = (String? message, {int? wrapWidth}) {};
  _configureAndroidImagePicker();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.white,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  OneSignal.initialize("0f2f4f43-c8b4-475c-be74-9ed6045bae52");
  OneSignal.Notifications.requestPermission(true);

  scheduleMicrotask(() {
    _ProductDetailPageState.prefetchGroupsCache();
  });

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('ru'), Locale('en')],
      home: HozyainBarinApp(),
    ),
  );
}

class HozyainBarinApp extends StatefulWidget {
  const HozyainBarinApp({super.key});

  @override
  State<HozyainBarinApp> createState() => _HozyainBarinAppState();
}

class _HozyainBarinAppState extends State<HozyainBarinApp>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ScrollController _nativeScrollController;
  late final ScrollController _discountScrollController;
  final List<_GalleryRequest> _pendingGalleryRequests = [];
  final Set<String> _queuedGalleryRequestKeys = {};
  final Set<String> _galleryRequestsInFlight = {};
  final Map<String, ValueNotifier<int>> _galleryVersionById = {};
  final Map<String, List<String>> _productFullGalleryById = {};
  bool _isUserScrolling = false;
  final ValueNotifier<bool> _scrollingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Set<String>> _scrollVisibleMainImageIds =
      ValueNotifier<Set<String>>(<String>{});
  Timer? _scrollVisibleImagesTimer;
  Timer? _scrollIdleTimer;
  Timer? _scrollStopNotifierTimer;
  bool _firstGalleryDelayPending = true;
  int? _lastScrollSampleMs;
  double _lastScrollSamplePos = 0.0;
  double _scrollVelocityPxPerSec = 0.0;
  int? _lastLoadMoreCheckMs;
  Timer? _galleryProcessingTimer;
  Timer? _galleryNotifyFlushTimer;
  final Set<String> _pendingGalleryNotifyIds = <String>{};
  bool _isProcessingGalleries = false;
  bool _isLoadingVisibleGalleries = false;
  int? _lastVisibleGalleryLoadMs;
  Timer? _visibleGalleryLoadTimer;
  int _lastVisibleStart = -1;
  int _lastVisibleEnd = -1;
  String? _lastVisibleCategoryKey;
  // Кэш для уже загруженных галерей
  final Map<String, List<String>> _galleryCache = {};
  final Map<String, int> _galleryNoImagesUntilMs = <String, int>{};
  final Map<String, int> _galleryNoImagesAttempts = <String, int>{};
  Timer? _visibleGalleryRetryTimer;
  bool _pendingVisibleGalleryReload = false;
  final Set<String> _newProductIds = <String>{};
  bool _isLoadingNewProductIds = false;
  final Set<String> _favoriteIds = <String>{};
  final Map<String, Map<String, dynamic>> _favoriteProductsById = {};
  final Map<String, ValueNotifier<int>> _favoriteVersionById = {};
  final ValueNotifier<int> _wishCountNotifier = ValueNotifier<int>(0);
  OverlayEntry? _favoriteOverlayEntry;
  Timer? _favoriteOverlayTimer;
  final Set<String> _compareIds = <String>{};
  final Map<String, Map<String, dynamic>> _compareProductsById = {};
  final Map<String, ValueNotifier<int>> _compareVersionById = {};
  final ValueNotifier<int> _compareCountNotifier = ValueNotifier<int>(0);
  final GlobalKey _compareHeaderKey = GlobalKey();
  late final ScrollController _compareTableScrollController;
  late final ScrollController _compareStickyScrollController;
  bool _isCompareStickyVisible = false;
  bool _showCartFloatingButton = false;
  final GlobalKey _cartItogoKey = GlobalKey();
  bool _isCompareScrollSyncing = false;
  final Set<String> _compareRemovingIds = <String>{};
  final Set<String> _compareCollapsedGroups = <String>{};
  final Map<String, GlobalKey> _compareGroupKeys = <String, GlobalKey>{};
  bool _compareOnlyDifferences = false;
  final Map<String, int> _compareLeftIndexByGroup = <String, int>{};
  final Map<String, int> _compareRightIndexByGroup = <String, int>{};
  String? _activeCompareGroupKey;
  OverlayEntry? _compareOverlayEntry;
  Timer? _compareOverlayTimer;
  OverlayEntry? _cartOverlayEntry;
  Timer? _cartOverlayTimer;
  final Map<String, int> _cartQuantityByProductId = {};
  final Map<String, Map<String, dynamic>> _cartProductsById = {};
  final ValueNotifier<int> _cartCountNotifier = ValueNotifier<int>(0);
  final Set<String> _cartSelectedIds = {};
  final ValueNotifier<bool> _cartSelectionNotifier = ValueNotifier<bool>(false);
  double _globalDiscountPercent = 0.0;
  final Set<String> _excludedDiscountCategories = <String>{};
  final Map<String, double> _specialCategoryDiscounts = {};
  final Map<String, double> _specialDiscountByProductId = {};
  bool _isLoadingSpecialDiscountIds = false;
  bool _preferHigherDiscount = true;
  bool _allowStackingDiscount = false;
  bool _hasDiscountConfig = false;
  bool _isMenuLoading = true;
  bool _isNativeCategoryPage = false;
  final List<({String key, String title, String? customCategoryId})>
  _nativeCategoryBackStack = [];
  int? _catalogBackSwipePointer;
  Offset? _catalogBackSwipeStart;
  bool _catalogBackSwipeScrollLocked = false;
  bool _catalogBackSwipeIsSettling = false;
  bool _catalogBackSwipeCompletesToHome = false;
  final ValueNotifier<double> _catalogBackSwipeOffsetNotifier =
      ValueNotifier<double>(0);
  late final AnimationController _catalogBackSwipeController;
  Animation<double>? _catalogBackSwipeAnimation;
  String _pageTitle = "";
  bool _nativePrefetchStarted = false;

  // Начальные данные для мгновенного отображения категорий
  List<dynamic> _apiCategories = [
    {"id": "16", "name": "Мужские сумки", "url": "muzhskie-sumki"},
    {"id": "30", "name": "Поясные сумки", "url": "poyasnye-sumki"},
    {"id": "13", "name": "Сумки через плечо", "url": "sumki-cherez-plecho"},
    {"id": "15", "name": "Сумки планшет", "url": "sumki-planshet"},
    {"id": "3", "name": "Деловые сумки", "url": "delovye-sumki"},
    {"id": "19", "name": "Женские сумки", "url": "zhenskie-sumki"},
    {"id": "4", "name": "Дорожные сумки", "url": "dorozhnye-sumki"},
    {"id": "14", "name": "Рюкзаки", "url": "ryukzaki"},
    {"id": "8", "name": "Ремни", "url": "remni"},
    {"id": "84", "name": "Кошельки", "url": "koshelki"},
    {"id": "101", "name": "Аксессуары", "url": "aksessuary"},
  ];
  List<dynamic> _allCategories = [];

  List<dynamic> _apiBanners = [];
  List<dynamic> _promoBanners = [];
  List<dynamic> _discountedProducts = [];
  final Map<String, List<dynamic>> _nativeLists = {
    "men": [],
    "belt": [],
    "shoulder": [],
    "tablet": [],
    "business": [],
    "women": [],
    "travel": [],
    "backpacks": [],
    "belts": [],
    "wallets": [],
    "accessories": [],
    "wishlist": [],
    "compare": [],
  };
  final Map<String, List<dynamic>> _originalNativeLists = {
    "men": [],
    "belt": [],
    "shoulder": [],
    "tablet": [],
    "business": [],
    "women": [],
    "travel": [],
    "backpacks": [],
    "belts": [],
    "wallets": [],
    "accessories": [],
    "wishlist": [],
    "compare": [],
  };
  String _currentSort = "default";
  int _sortSeq = 0;
  int _wishlistFilterSeq = 0;
  String _selectedDiscountType = "men"; // "men" или "women"
  String _menBagsCategoryId = "16";
  String _beltBagsCategoryId = "30";
  String _shoulderBagsCategoryId = "13";
  String _tabletBagsCategoryId = "15";
  String _businessBagsCategoryId = "3";
  String _womenBagsCategoryId = "19";
  String _travelBagsCategoryId = "4";
  String _backpacksCategoryId = "14";
  String _beltsCategoryId = "8";
  String _walletsCategoryId = "84";
  String _accessoriesCategoryId = "101";
  String _nativeCategory =
      "men"; // men | belt | shoulder | tablet | business | women | travel | backpacks | belts | wallets | accessories | discount_men | discount_women | wishlist | compare
  final Set<String> _animatedProductIds = <String>{};
  static const int _nativePageSize = 30;
  final Map<String, String> _nativeCustomCategoryIdByKey = {
    "discount_men": "156",
    "discount_women": "157",
  };
  static const int _maxGalleryCacheEntries = 600;
  static const int _maxGalleryNotifierEntries = 1200;
  final Map<String, int> _nativeOffsets = {
    "men": 0,
    "belt": 0,
    "shoulder": 0,
    "tablet": 0,
    "business": 0,
    "women": 0,
    "travel": 0,
    "backpacks": 0,
    "belts": 0,
    "wallets": 0,
    "accessories": 0,
    "discount_men": 0,
    "discount_women": 0,
    "wishlist": 0,
    "compare": 0,
  };
  final Map<String, bool> _nativeHasMore = {
    "men": true,
    "belt": true,
    "shoulder": true,
    "tablet": true,
    "business": true,
    "women": true,
    "travel": true,
    "backpacks": true,
    "belts": true,
    "wallets": true,
    "accessories": true,
    "discount_men": true,
    "discount_women": true,
    "wishlist": false,
    "compare": false,
  };
  final Map<String, bool> _nativeIsLoadingMore = {
    "men": false,
    "belt": false,
    "shoulder": false,
    "tablet": false,
    "business": false,
    "women": false,
    "travel": false,
    "backpacks": false,
    "belts": false,
    "wallets": false,
    "accessories": false,
    "discount_men": false,
    "discount_women": false,
    "wishlist": false,
    "compare": false,
  };
  final Set<String> _nativeInitialLoadingKeys = <String>{};
  final Map<String, bool> _nativeShowLoadingIndicator = {
    "men": false,
    "belt": false,
    "shoulder": false,
    "tablet": false,
    "business": false,
    "women": false,
    "travel": false,
    "backpacks": false,
    "belts": false,
    "wallets": false,
    "accessories": false,
    "discount_men": false,
    "discount_women": false,
    "wishlist": false,
    "compare": false,
  };
  final Map<String, Timer?> _nativeLoadingIndicatorTimers = {};
  final Map<String, List<MapEntry<String, String>>> _nativeFilterParams = {};

  // Фильтры
  List<dynamic> _availableFeatures = [];
  List<dynamic> _availableStocks = [];
  RangeValues _currentPriceRange = const RangeValues(0, 30000);
  Map<String, List<String>> _selectedFeatures =
      {}; // feature_id -> list of value_ids
  List<String> _selectedStocks = []; // stock_id
  bool _isFilterLoading = false;
  bool _isLocalSortLoading = false;
  bool _isLocalFilterLoading = false;
  final Map<String, String> _featureCodeById = {}; // feature_id -> feature_code
  final Map<String, Map<String, String>> _featureValueTextById =
      {}; // feature_id -> value_id -> text
  final Map<String, Map<String, dynamic>> _productFeaturesById =
      {}; // product_id -> features map
  final Map<String, Map<String, int>> _productStockById =
      {}; // product_id -> stock_id -> count
  final Map<String, String> _featureIdByCode = {}; // feature_code -> feature_id
  final Map<String, int> _featureIndexById =
      {}; // feature_id -> index in _availableFeatures
  Map<String, Set<String>> _availableFeatureValuesInCategory =
      {}; // feature_id -> normalized values
  bool _isFilterMetadataLoading = false;
  bool _isFilterMetadataLoaded = false;
  final Set<String> _featureValuesLoading = <String>{};
  final List<_FeatureInfoRequest> _featureInfoQueue = [];
  int _featureInfoInFlight = 0;
  static const int _featureInfoMaxConcurrent = 3;
  final Map<String, Completer<void>> _productDetailsCompleters = {};
  final List<String> _productDetailsQueue = [];
  final Set<String> _productDetailsInFlight = <String>{};
  static const int _productDetailsMaxConcurrent = 4;
  int _productFeaturesVersion = 0;
  String _compareRowsKey = "";
  List<Map<String, dynamic>> _compareRowsCache = [];

  // Данные для блока "О компании"
  String _aboutImageUrl =
      'https://hozyain-barin.ru/wa-data/public/site/native/about.webp';
  String _aboutTitle = 'Мужские и женские сумки от "Хозяин Барин"';
  List<dynamic> _aboutDescription = [];

  final String _apiToken = "f616081435730714b089ec1115bac63b";
  String? _expandedCategoryId;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _catalogBackSwipeController =
        AnimationController(
            vsync: this,
            duration: _catalogBackSwipeSettleDuration,
          )
          ..addListener(() {
            final animation = _catalogBackSwipeAnimation;
            if (animation == null) return;
            _catalogBackSwipeOffsetNotifier.value = animation.value;
          })
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed || !mounted) return;
            if (!_catalogBackSwipeIsSettling) return;
            final completesToHome = _catalogBackSwipeCompletesToHome;
            _catalogBackSwipeIsSettling = false;
            _catalogBackSwipeCompletesToHome = false;
            _catalogBackSwipeAnimation = null;
            if (completesToHome) {
              _goBackFromCategory();
            } else {
              _catalogBackSwipeOffsetNotifier.value = 0;
              _setCatalogBackSwipeScrollLocked(false);
            }
          });
    _configureAndroidImagePicker();
    _isMenuLoading = false; // Категории уже есть частично
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadAllData();
      _scheduleNativePrefetch();
      CategoryCounterService.loadCounts().then((_) {
        if (mounted) setState(() {});
      });
      Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        _fetchFilterMetadata();
      });
    });
    _initDeepLinks();
    _discountScrollController = ScrollController();
    _compareTableScrollController = ScrollController();
    _compareStickyScrollController = ScrollController();
    _compareTableScrollController.addListener(() {
      _syncCompareHorizontalScroll(
        _compareTableScrollController,
        _compareStickyScrollController,
      );
    });
    _compareStickyScrollController.addListener(() {
      _syncCompareHorizontalScroll(
        _compareStickyScrollController,
        _compareTableScrollController,
      );
    });
    _nativeScrollController = ScrollController()
      ..addListener(() {
        if (!_isNativeCategoryPage) return;
        if (!_nativeScrollController.hasClients) return;
        _isUserScrolling = true;
        const int velocitySampleMs = 50;
        const int loadMoreIntervalMs = 220;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final pos = _nativeScrollController.position.pixels;
        final lastMs = _lastScrollSampleMs;
        if (lastMs == null || nowMs - lastMs >= velocitySampleMs) {
          if (lastMs != null) {
            final dtMs = nowMs - lastMs;
            if (dtMs > 0) {
              final dp = (pos - _lastScrollSamplePos).abs();
              final v = (dp / dtMs) * 1000.0;
              _scrollVelocityPxPerSec =
                  (_scrollVelocityPxPerSec * 0.7) + (v * 0.3);
              if (_scrollVelocityPxPerSec > 8000) {
                _scrollVelocityPxPerSec = 8000;
              }
            }
          }
          _lastScrollSampleMs = nowMs;
          _lastScrollSamplePos = pos;
        }
        _scrollStopNotifierTimer?.cancel();
        _setScrollingNotifier(true);
        _scrollIdleTimer?.cancel();
        _scrollIdleTimer = Timer(const Duration(milliseconds: 180), () {
          _isUserScrolling = false;
          _scrollVelocityPxPerSec = 0.0;
          _lastScrollSampleMs = null;
          _scrollStopNotifierTimer?.cancel();
          final int stopDelayMs = _firstGalleryDelayPending ? 60 : 0;
          if (stopDelayMs == 0) {
            _setScrollingNotifier(false);
          } else {
            _scrollStopNotifierTimer = Timer(
              Duration(milliseconds: stopDelayMs),
              () {
                _firstGalleryDelayPending = false;
                _setScrollingNotifier(false);
              },
            );
          }
          if (_scrollVisibleImagesTimer?.isActive == true) {
            _scrollVisibleImagesTimer?.cancel();
          }
          // Обновляем видимый набор после остановки, чтобы включить галереи
          _scrollVisibleImagesTimer = Timer(
            const Duration(milliseconds: 50),
            () {
              _scrollVisibleImagesTimer = null;
              _updateScrollVisibleMainImages();
            },
          );
          final currentList = _getActiveNativeList();
          if (currentList.isNotEmpty) {
            _loadGalleriesForVisibleProducts(_nativeCategory, currentList);
          }
          _startGalleryProcessing();
          _scheduleGalleryNotifyFlush();
          // Если пользователь остановился в зоне плейсхолдеров — догружаем сразу
          _loadMoreActiveNativeIfNeeded();
        });

        if (_lastLoadMoreCheckMs == null ||
            nowMs - _lastLoadMoreCheckMs! >= loadMoreIntervalMs) {
          _lastLoadMoreCheckMs = nowMs;
          _loadMoreActiveNativeIfNeeded();
        }
        _updateCompareStickyVisibility();
        _updateCartFloatingButtonVisibility();
      });
    _cartCountNotifier.addListener(_scheduleCartFloatingButtonUpdate);
    _cartSelectionNotifier.addListener(_scheduleCartFloatingButtonUpdate);
  }

  @override
  void dispose() {
    _catalogBackSwipeController.dispose();
    _catalogBackSwipeOffsetNotifier.dispose();
    _nativeScrollController.dispose();
    _discountScrollController.dispose();
    _compareTableScrollController.dispose();
    _compareStickyScrollController.dispose();
    _scrollIdleTimer?.cancel();
    _scrollStopNotifierTimer?.cancel();
    _galleryProcessingTimer?.cancel();
    _galleryNotifyFlushTimer?.cancel();
    _visibleGalleryRetryTimer?.cancel();
    _visibleGalleryLoadTimer?.cancel();
    for (final timer in _nativeLoadingIndicatorTimers.values) {
      timer?.cancel();
    }
    _nativeLoadingIndicatorTimers.clear();
    _pendingGalleryNotifyIds.clear();
    for (final notifier in _galleryVersionById.values) {
      notifier.dispose();
    }
    _galleryVersionById.clear();
    _scrollingNotifier.dispose();
    _scrollVisibleImagesTimer?.cancel();
    _scrollVisibleMainImageIds.dispose();
    _linkSubscription?.cancel();
    _favoriteOverlayTimer?.cancel();
    _favoriteOverlayEntry?.remove();
    for (final notifier in _favoriteVersionById.values) {
      notifier.dispose();
    }
    _favoriteVersionById.clear();
    _compareOverlayTimer?.cancel();
    _compareOverlayEntry?.remove();
    _cartOverlayTimer?.cancel();
    _cartOverlayEntry?.remove();
    for (final notifier in _compareVersionById.values) {
      notifier.dispose();
    }
    _compareVersionById.clear();
    _compareCountNotifier.dispose();
    _wishCountNotifier.dispose();
    _cartCountNotifier.dispose();
    _cartSelectionNotifier.dispose();
    _productDetailsQueue.clear();
    _productDetailsInFlight.clear();
    for (final entry in _productDetailsCompleters.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete();
      }
    }
    _productDetailsCompleters.clear();
    super.dispose();
  }

  void _loadAllData() {
    _fetchCategories();
    _fetchNewCategoryProductIds();
    _fetchBanners();
    _fetchPromoBanners();
    _fetchDiscountConfig();
    _fetchAboutData();
    _fetchDiscountedProducts();
    _fetchMenBags();
  }

  void _scheduleNativePrefetch() {
    if (_nativePrefetchStarted) return;
    _nativePrefetchStarted = true;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _prefetchNativeCategories();
    });
  }

  Future<void> _prefetchNativeCategories() async {
    final entries = <MapEntry<String, Future<void> Function()>>[
      MapEntry("belt", () => _fetchBeltBags(reset: false)),
      MapEntry("shoulder", () => _fetchShoulderBags(reset: false)),
      MapEntry("tablet", () => _fetchTabletBags(reset: false)),
      MapEntry("business", () => _fetchBusinessBags(reset: false)),
      MapEntry("women", () => _fetchWomenBags(reset: false)),
      MapEntry("travel", () => _fetchTravelBags(reset: false)),
      MapEntry("backpacks", () => _fetchBackpacks(reset: false)),
      MapEntry("belts", () => _fetchBelts(reset: false)),
      MapEntry("wallets", () => _fetchWallets(reset: false)),
      MapEntry("accessories", () => _fetchAccessories(reset: false)),
    ];
    for (final entry in entries) {
      if (!mounted) return;
      final key = entry.key;
      if (_nativeInitialLoadingKeys.contains(key)) continue;
      if (_nativeIsLoadingMore[key] == true) continue;
      if (_getNativeListByKey(key).isNotEmpty) continue;
      await entry.value();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _fetchFilterMetadata({StateSetter? modalSetter}) async {
    if (_isFilterMetadataLoaded || _isFilterMetadataLoading) return;
    _isFilterMetadataLoading = true;
    if (mounted) setState(() {});
    if (modalSetter != null) {
      try {
        modalSetter(() {});
      } catch (_) {}
    }
    bool success = false;
    try {
      // 1. Характеристики
      final featRes = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.feature.getList?access_token=$_apiToken',
        ),
      );
      if (featRes.statusCode == 200) {
        final decoded = json.decode(featRes.body);
        var rawData = (decoded is Map && decoded.containsKey('data'))
            ? decoded['data']
            : decoded;

        List<dynamic> allFeats = [];
        if (rawData is List) {
          allFeats = rawData;
        } else if (rawData is Map) {
          allFeats = rawData.values.toList();
        }

        // Полный список характеристик для соответствия веб-версии
        _availableFeatures = allFeats
            .where((f) {
              if (f is! Map) return false;
              String name = f['name']?.toString().toLowerCase() ?? "";
              return name.contains("материал") ||
                  name.contains("размер") ||
                  name.contains("конструкц") ||
                  name.contains("цвет") ||
                  name.contains("тип") ||
                  name.contains("отдел") ||
                  name.contains("дополн") ||
                  name.contains("характер") ||
                  name.contains("форм") ||
                  name.contains("ноутбук") ||
                  name.contains("акцент");
            })
            .map((f) {
              final map = Map<String, dynamic>.from(f);
              map['values'] ??= <String, dynamic>{};
              return map;
            })
            .toList();

        _featureCodeById.clear();
        _featureIdByCode.clear();
        _featureValueTextById.clear();
        _featureIndexById.clear();
        _featureValuesLoading.clear();
        _featureInfoQueue.clear();
        _featureInfoInFlight = 0;
        for (int i = 0; i < _availableFeatures.length; i++) {
          final feat = _availableFeatures[i];
          final id = feat['id']?.toString();
          final code = feat['code']?.toString();
          if (id != null && id.isNotEmpty && code != null && code.isNotEmpty) {
            _featureCodeById[id] = code;
            _featureIdByCode[code] = id;
          }
          if (id != null && id.isNotEmpty) {
            _featureIndexById[id] = i;
          }
        }
        success = _availableFeatures.isNotEmpty;
      }

      // 2. Склады/Магазины
      final stockRes = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.stock.getList?access_token=$_apiToken',
        ),
      );
      if (stockRes.statusCode == 200) {
        final stockDecoded = json.decode(stockRes.body);
        var stockData =
            (stockDecoded is Map && stockDecoded.containsKey('data'))
            ? stockDecoded['data']
            : stockDecoded;
        if (stockData is List) {
          _availableStocks = stockData;
        } else if (stockData is Map) {
          _availableStocks = stockData.values.toList();
        }
      }
    } catch (e) {
      debugPrint("Filter metadata error: $e");
    } finally {
      _isFilterMetadataLoading = false;
      if (success) {
        _isFilterMetadataLoaded = true;
      }
      if (mounted) setState(() {});
      if (modalSetter != null) {
        try {
          modalSetter(() {});
        } catch (_) {}
      }
    }
  }

  void _ensureFeatureValuesLoaded(String fid, {StateSetter? modalSetter}) {
    if (fid.isEmpty) return;
    if (_featureValueTextById.containsKey(fid)) return;
    if (_featureValuesLoading.contains(fid)) return;
    _featureValuesLoading.add(fid);
    _featureInfoQueue.add(_FeatureInfoRequest(fid, modalSetter));
    _processFeatureInfoQueue();
  }

  void _processFeatureInfoQueue() {
    if (_featureInfoInFlight >= _featureInfoMaxConcurrent) return;
    while (_featureInfoInFlight < _featureInfoMaxConcurrent &&
        _featureInfoQueue.isNotEmpty) {
      final req = _featureInfoQueue.removeAt(0);
      _featureInfoInFlight++;
      _fetchFeatureValuesForId(req.fid)
          .then((result) {
            final int? index = _featureIndexById[req.fid];
            final Map<String, dynamic> values =
                result?['values'] ?? <String, dynamic>{};
            final Map<String, String> textMap =
                result?['textMap'] ?? <String, String>{};
            if (index != null &&
                index >= 0 &&
                index < _availableFeatures.length) {
              _availableFeatures[index]['values'] = values;
            }
            _featureValueTextById[req.fid] = textMap;
          })
          .whenComplete(() {
            _featureInfoInFlight--;
            _featureValuesLoading.remove(req.fid);
            if (mounted) setState(() {});
            if (req.modalSetter != null) {
              try {
                req.modalSetter!(() {});
              } catch (_) {}
            }
            _processFeatureInfoQueue();
          });
    }
  }

  Future<Map<String, dynamic>?> _fetchFeatureValuesForId(String fid) async {
    try {
      final infoRes = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.feature.getInfo?id=$fid&access_token=$_apiToken',
        ),
      );
      if (infoRes.statusCode != 200) return null;
      final infoDecoded = json.decode(infoRes.body);
      final infoData = (infoDecoded is Map && infoDecoded.containsKey('data'))
          ? infoDecoded['data']
          : infoDecoded;
      if (infoData is! Map) return null;
      var rawValues = infoData['values'];
      Map<String, dynamic> processedValues = {};
      if (rawValues is Map) {
        processedValues = Map<String, dynamic>.from(rawValues);
      } else if (rawValues is List) {
        for (int j = 0; j < rawValues.length; j++) {
          processedValues[j.toString()] = rawValues[j];
        }
      }
      final textMap = <String, String>{};
      processedValues.forEach((key, value) {
        textMap[key.toString()] = value.toString();
      });
      return {"values": processedValues, "textMap": textMap};
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchNativeCategory({
    required String key,
    required String categoryId,
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    if (_nativeIsLoadingMore[key] == true) return;
    if (!reset && _nativeHasMore[key] == false) return;
    if (reset) {
      if (_nativeInitialLoadingKeys.contains(key)) return;
      _nativeInitialLoadingKeys.add(key);
    }

    try {
      if (reset) {
        if (mounted) setState(() => _isFilterLoading = true);
        _nativeOffsets[key] = 0;
        _nativeHasMore[key] = true;
        _nativeIsLoadingMore[key] = false;
        _nativeShowLoadingIndicator[key] = false;
        _nativeLoadingIndicatorTimers[key]?.cancel();
        _nativeLoadingIndicatorTimers[key] = null;
        _setNativeListByKey(key, []);
        _setOriginalNativeListByKey(key, []);
        _nativeFilterParams[key] = customParams ?? [];
        _availableFeatureValuesInCategory = {};
        _pendingGalleryRequests.removeWhere((req) => req.categoryKey == key);
        _queuedGalleryRequestKeys.removeWhere((k) => k.startsWith("$key::"));
        _galleryRequestsInFlight.removeWhere((k) => k.startsWith("$key::"));
        _galleryNoImagesUntilMs.clear();
        _galleryNoImagesAttempts.clear();
        if (_lastVisibleCategoryKey == key) {
          _lastVisibleStart = -1;
          _lastVisibleEnd = -1;
        }
      } else {
        _nativeIsLoadingMore[key] = true;
        _nativeShowLoadingIndicator[key] = false;
        // Отменяем предыдущий таймер, если есть
        _nativeLoadingIndicatorTimers[key]?.cancel();
        // Показываем индикатор только через 600ms после начала загрузки
        _nativeLoadingIndicatorTimers[key] = Timer(
          const Duration(milliseconds: 600),
          () {
            if (mounted && _nativeIsLoadingMore[key] == true) {
              _nativeShowLoadingIndicator[key] = true;
              setState(() {});
            }
          },
        );
      }

      final offset = _nativeOffsets[key] ?? 0;
      final effectiveParams = customParams ?? _nativeFilterParams[key] ?? [];
      final queryParts = <String>[
        'access_token=${Uri.encodeQueryComponent(_apiToken)}',
        'limit=$_nativePageSize',
        'offset=$offset',
        'hash=${Uri.encodeQueryComponent('category/$categoryId')}',
        'sort=create_datetime',
        'order=desc',
        'status=1',
        'in_stock=1',
      ];

      if (effectiveParams.isNotEmpty) {
        for (final entry in effectiveParams) {
          final keyParam = entry.key;
          final value = entry.value;
          if (keyParam != 'hash' &&
              keyParam != 'category_id' &&
              keyParam != 'sort' &&
              keyParam != 'order') {
            queryParts.add(
              '${Uri.encodeQueryComponent(keyParam)}=${Uri.encodeQueryComponent(value)}',
            );
          }
        }
      }

      final url =
          'https://hozyain-barin.ru/api.php/shop.product.search?${queryParts.join('&')}';
      final response = await _httpGet(Uri.parse(url));

      if (response.statusCode == 200) {
        final parsed = await compute(
          _parseNativeCategoryPayload,
          response.body,
        );
        final rawItems = parsed['items'];
        final List<dynamic> initialProducts = (rawItems is List)
            ? rawItems
            : [];
        final fetchedCountRaw = parsed['fetchedCount'];
        final int fetchedCount = fetchedCountRaw is int
            ? fetchedCountRaw
            : (fetchedCountRaw is num
                  ? fetchedCountRaw.toInt()
                  : initialProducts.length);

        if (_hasDiscountConfig) {
          _applyDiscountConfigToProducts(initialProducts);
        }
        final List<dynamic> filteredProducts = await _applyLocalFilters(
          initialProducts,
        );
        for (final product in filteredProducts) {
          if (product is! Map) continue;
          product['source_category_id'] = categoryId;
          if (_newCategoryIds.contains(categoryId)) {
            product['is_new'] = true;
          } else {
            final dynamic ids = product['category_ids'];
            if (ids is List &&
                ids.any(
                  (id) => id != null && _newCategoryIds.contains(id.toString()),
                )) {
              product['is_new'] = true;
            }
          }
        }

        final existing = _getNativeListByKey(key);
        final existingOriginal = _getOriginalNativeListByKey(key);
        final existingIds = <String>{};
        for (final item in existing) {
          if (item is! Map) continue;
          final id = item['id']?.toString() ?? "";
          if (id.isNotEmpty) existingIds.add(id);
        }
        final List<dynamic> uniqueNew = [];
        for (final item in filteredProducts) {
          if (item is! Map) {
            uniqueNew.add(item);
            continue;
          }
          final id = item['id']?.toString() ?? "";
          if (id.isEmpty || !existingIds.contains(id)) {
            if (id.isNotEmpty) existingIds.add(id);
            uniqueNew.add(item);
          }
        }
        final merged = [...existing, ...uniqueNew];
        final mergedOriginal = [...existingOriginal, ...uniqueNew];
        final bool isInitialPage = reset && offset == 0;

        if (mounted) {
          setState(() {
            _setNativeListByKey(key, merged);
            _setOriginalNativeListByKey(key, mergedOriginal);
            _isFilterLoading = false;
            _currentSort = "default";
          });
        }

        if (key == _nativeCategory) {
          _updateAvailableFeatureValuesForProducts(uniqueNew);

          // После рендеринга определяем видимые карточки и загружаем для них галереи
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isInitialPage) {
              _precacheCategoryPreviewImages(merged);
            }
            _scheduleVisibleGalleryLoad(key);
            // Если пользователь уже долистал до плейсхолдеров — добираем страницы
            _loadMoreActiveNativeIfNeeded();
          });
        }

        // Добавляем остальные карточки в очередь для фоновой загрузки
        // Видимые карточки будут загружены через _loadGalleriesForVisibleProducts
        final startIndex = merged.length - uniqueNew.length;
        // На первом открытии ограничиваем фоновую очередь, чтобы не грузить лишнее.
        final List<dynamic> queueProducts = isInitialPage
            ? uniqueNew.take(10).toList()
            : uniqueNew;
        _enqueueGalleryRequests(queueProducts, startIndex, key);

        // Запускаем обработку очереди немедленно
        _startGalleryProcessing();

        _nativeOffsets[key] = offset + fetchedCount;
        _nativeHasMore[key] = fetchedCount >= _nativePageSize;
      }
    } catch (e) {
      debugPrint("Native category API error: $e");
    } finally {
      if (reset) {
        _nativeInitialLoadingKeys.remove(key);
      }
      _nativeIsLoadingMore[key] = false;
      _nativeShowLoadingIndicator[key] = false;
      _nativeLoadingIndicatorTimers[key]?.cancel();
      _nativeLoadingIndicatorTimers[key] = null;
      if (mounted) setState(() => _isFilterLoading = false);
    }
  }

  Future<void> _fetchMenBags({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "men",
      categoryId: _menBagsCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<void> _fetchBeltBags({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "belt",
      categoryId: _beltBagsCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<void> _fetchShoulderBags({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "shoulder",
      categoryId: _shoulderBagsCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<void> _fetchTabletBags({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "tablet",
      categoryId: _tabletBagsCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<void> _fetchBusinessBags({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "business",
      categoryId: _businessBagsCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<void> _fetchWomenBags({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "women",
      categoryId: _womenBagsCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<void> _fetchTravelBags({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "travel",
      categoryId: _travelBagsCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<void> _fetchBackpacks({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "backpacks",
      categoryId: _backpacksCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<void> _fetchBelts({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "belts",
      categoryId: _beltsCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<void> _fetchWallets({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "wallets",
      categoryId: _walletsCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<void> _fetchAccessories({
    List<MapEntry<String, String>>? customParams,
    bool reset = true,
  }) async {
    return _fetchNativeCategory(
      key: "accessories",
      categoryId: _accessoriesCategoryId,
      customParams: customParams,
      reset: reset,
    );
  }

  Future<List<dynamic>> _applyLocalFilters(List<dynamic> products) async {
    final priceFiltered = await _applyLocalPriceFilterAsync(products);
    if (_selectedFeatures.isEmpty && _selectedStocks.isEmpty) {
      return priceFiltered;
    }

    await _ensureProductDetails(priceFiltered);

    return _applySelectedFiltersChunked(priceFiltered);
  }

  Future<List<dynamic>> _applySelectedFiltersChunked(
    List<dynamic> products,
  ) async {
    const int chunkSize = 80;
    const int asyncThreshold = 160;
    if (products.length < asyncThreshold) {
      final List<dynamic> filtered = [];
      for (final product in products) {
        final id = product is Map ? product['id']?.toString() ?? "" : "";
        if (id.isEmpty) continue;
        if (_matchesSelectedFeatures(id) && _matchesSelectedStocks(id)) {
          filtered.add(product);
        }
      }
      return filtered;
    }
    final List<dynamic> filtered = [];
    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      final id = product is Map ? product['id']?.toString() ?? "" : "";
      if (id.isNotEmpty &&
          _matchesSelectedFeatures(id) &&
          _matchesSelectedStocks(id)) {
        filtered.add(product);
      }
      if (i > 0 && i % chunkSize == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return filtered;
  }

  Future<List<dynamic>> _applyLocalPriceFilterAsync(
    List<dynamic> products,
  ) async {
    const int isolateThreshold = 120;
    if (products.length < isolateThreshold) {
      return _applyLocalPriceFilter(products);
    }
    final payload = {
      "products": products,
      "minPrice": _currentPriceRange.start,
      "maxPrice": _currentPriceRange.end,
      "mode": "raw",
    };
    return await compute(_filterProductsByPrice, payload);
  }

  List<dynamic> _applyLocalPriceFilter(List<dynamic> products) {
    final minPrice = _currentPriceRange.start;
    final maxPrice = _currentPriceRange.end;
    return products.where((p) {
      final raw = p['raw_price'];
      final price = (raw is num)
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? "0") ?? 0;
      return price >= minPrice && price <= maxPrice;
    }).toList();
  }

  Future<void> _ensureProductDetails(List<dynamic> products) async {
    final List<Future<void>> tasks = [];
    for (final product in products) {
      if (product is! Map) continue;
      final id = product['id']?.toString() ?? "";
      if (id.isEmpty) continue;
      if (_hasProductDetails(id)) continue;
      tasks.add(_queueProductDetailsFetch(id));
    }
    if (tasks.isNotEmpty) {
      await Future.wait(
        tasks.map(
          (t) => t.catchError((e, st) {
            debugPrint("Product details batch error: $e");
            if (kDebugMode) debugPrint("$st");
          }),
        ),
      );
    }
  }

  bool _hasProductDetails(String productId) {
    final hasFeatures = _productFeaturesById.containsKey(productId);
    final hasStocks = _productStockById.containsKey(productId);
    return hasFeatures && (hasStocks || _selectedStocks.isEmpty);
  }

  Future<void> _queueProductDetailsFetch(String productId) {
    if (productId.isEmpty) return Future.value();
    final existing = _productDetailsCompleters[productId];
    if (existing != null) {
      if (_hasProductDetails(productId) && !existing.isCompleted) {
        existing.complete();
      }
      return existing.future;
    }
    if (_hasProductDetails(productId)) return Future.value();
    final completer = Completer<void>();
    _productDetailsCompleters[productId] = completer;
    _productDetailsQueue.add(productId);
    _drainProductDetailsQueue();
    return completer.future;
  }

  void _drainProductDetailsQueue() {
    if (_productDetailsQueue.isEmpty) return;
    while (_productDetailsInFlight.length < _productDetailsMaxConcurrent &&
        _productDetailsQueue.isNotEmpty) {
      final id = _productDetailsQueue.removeAt(0);
      if (id.isEmpty) continue;
      if (_productDetailsInFlight.contains(id)) continue;
      _productDetailsInFlight.add(id);
      _fetchProductDetails(id)
          .catchError((e, st) {
            debugPrint("Product details error for $id: $e");
            if (kDebugMode) debugPrint("$st");
          })
          .whenComplete(() {
            _productDetailsInFlight.remove(id);
            final completer = _productDetailsCompleters.remove(id);
            if (completer != null && !completer.isCompleted) {
              completer.complete();
            }
            _drainProductDetailsQueue();
          });
    }
  }

  Future<void> _updateAvailableFeatureValuesForProducts(
    List<dynamic> products,
  ) async {
    try {
      await _ensureProductDetails(products);
      final Map<String, Set<String>> valuesByFeature = Map.from(
        _availableFeatureValuesInCategory,
      );
      for (final product in products) {
        final id = product['id']?.toString() ?? "";
        if (id.isEmpty) continue;
        final features = _productFeaturesById[id];
        if (features == null) continue;
        features.forEach((code, rawValue) {
          final fid = _featureIdByCode[code.toString()];
          if (fid == null || fid.isEmpty) return;
          final values = _normalizeFeatureValues(
            rawValue,
          ).map(_normalizeComparable).where((v) => v.isNotEmpty);
          if (values.isEmpty) return;
          valuesByFeature.putIfAbsent(fid, () => <String>{}).addAll(values);
        });
      }
      _availableFeatureValuesInCategory = valuesByFeature;
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint("Update feature values error: $e");
      if (kDebugMode) debugPrint("$st");
    }
  }

  Future<void> _fetchProductDetails(String productId) async {
    try {
      final response = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.product.getInfo?id=$productId&access_token=$_apiToken',
        ),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          final features = decoded['features'];
          if (features is Map) {
            _productFeaturesById[productId] = Map<String, dynamic>.from(
              features,
            );
            _productFeaturesVersion++;
          }
          final skus = decoded['skus'];
          if (skus is List) {
            final Map<String, int> stockMap = {};
            for (final sku in skus) {
              if (sku is! Map) continue;
              final stocks = sku['stocks'];
              if (stocks is List) {
                for (final stock in stocks) {
                  if (stock is! Map) continue;
                  final id = stock['id']?.toString();
                  final countRaw = stock['count'];
                  if (id == null || id.isEmpty) continue;
                  final count = (countRaw is num)
                      ? countRaw.toInt()
                      : int.tryParse(countRaw?.toString() ?? "0") ?? 0;
                  stockMap[id] = (stockMap[id] ?? 0) + count;
                }
              }
            }
            if (stockMap.isNotEmpty) {
              _productStockById[productId] = stockMap;
            }
          }
        }
      }
    } catch (e, st) {
      debugPrint("Product details error for $productId: $e");
      if (kDebugMode) debugPrint("$st");
    }
  }

  Future<Map<String, dynamic>?> _fetchProductInfoById(String productId) async {
    try {
      final response = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.product.getInfo?id=$productId&access_token=$_apiToken',
        ),
      );
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      if (decoded is! Map) return null;
      final priceValue = _parsePriceValue(decoded['price']);
      final compareValue = _parsePriceValue(decoded['compare_price']);
      final statusValue = decoded['status']?.toString();
      final rawCompareValue = (compareValue > priceValue && compareValue > 0)
          ? compareValue
          : 0.0;
      String? discountText;
      String? benefitText;
      if (rawCompareValue > priceValue &&
          rawCompareValue > 0 &&
          priceValue > 0) {
        final int percent =
            (((rawCompareValue - priceValue) / rawCompareValue) * 100).round();
        if (percent > 0) {
          discountText = "- $percent%";
          final int benefit = (rawCompareValue - priceValue).round();
          if (benefit > 0) {
            benefitText = "ВЫГОДА ${_formatPrice(benefit.toDouble())} ₽";
          }
        }
      }

      final List<String> images = [];
      final rawImages = _normalizeImageList(decoded['images']);
      final sizeRegex = RegExp(r'\.\d+x\d+\.');
      for (final img in rawImages) {
        final url = img['url'] ?? img['image_url'] ?? img['image'];
        if (url == null) continue;
        String value = url.toString();
        if (value.isNotEmpty) {
          value = value.replaceAll(sizeRegex, '.0x400.');
          images.add(value);
        }
      }
      final mainImage = decoded['image'] ?? decoded['image_url'];
      if (mainImage != null) {
        final value = mainImage.toString().replaceAll(sizeRegex, '.0x400.');
        if (value.isNotEmpty && !images.contains(value)) {
          images.insert(0, value);
        }
      }

      final description = decoded['description'];
      final summary = decoded['summary'];
      final shortDescription =
          decoded['short_description'] ?? decoded['shortDescription'];
      final rawFeatures = decoded['features'];

      int totalCount = 0;
      final rawCount = decoded['count'];
      if (rawCount != null) {
        totalCount = (rawCount is num)
            ? rawCount.toInt()
            : int.tryParse(rawCount.toString()) ?? 0;
      }

      final Map<String, int> stockMap = {};
      final skus = decoded['skus'];
      if (skus is List) {
        for (final sku in skus) {
          if (sku is! Map) continue;
          final stocks = sku['stocks'];
          if (stocks is List) {
            for (final stock in stocks) {
              if (stock is! Map) continue;
              final id = stock['id']?.toString();
              final countRaw = stock['count'];
              if (id == null || id.isEmpty) continue;
              final count = (countRaw is num)
                  ? countRaw.toInt()
                  : int.tryParse(countRaw?.toString() ?? "0") ?? 0;
              stockMap[id] = (stockMap[id] ?? 0) + count;
            }
          }
        }
      }
      if (stockMap.isNotEmpty) {
        _productStockById[productId] = stockMap;
        totalCount = stockMap.values.fold(0, (sum, v) => sum + v);
      }

      final result = <String, dynamic>{
        "id": decoded['id']?.toString() ?? productId,
        "name": decoded['name']?.toString() ?? "",
        "price": priceValue > 0 ? "${_formatPrice(priceValue)} ₽" : "",
        "raw_price": priceValue,
        "raw_compare_price": rawCompareValue,
        if (statusValue != null) "status": statusValue,
        "count": totalCount,
        if (rawCompareValue > 0)
          "old_price": "${_formatPrice(rawCompareValue)} ₽",
        if (discountText != null) "discount": discountText,
        if (benefitText != null) "benefit": benefitText,
        if (images.isNotEmpty) "images": images,
        if (images.isNotEmpty) "image": images.first,
        if (decoded['sku'] != null) "sku": decoded['sku'],
        if (decoded['article'] != null) "article": decoded['article'],
        if (decoded['articul'] != null) "articul": decoded['articul'],
        if (decoded['code'] != null) "code": decoded['code'],
        if (description != null) "description": description,
        if (summary != null) "summary": summary,
        if (shortDescription != null) "short_description": shortDescription,
        if (rawFeatures is Map)
          "features": Map<String, dynamic>.from(rawFeatures),
        if (stockMap.isNotEmpty) "stock_map": stockMap,
        if (decoded['category_id'] != null)
          "category_id": decoded['category_id'],
        if (decoded['categoryId'] != null) "categoryId": decoded['categoryId'],
        if (decoded['cat_id'] != null) "cat_id": decoded['cat_id'],
        if (decoded['categories'] != null) "categories": decoded['categories'],
        if (decoded['category_ids'] != null)
          "category_ids": decoded['category_ids'],
        if (decoded['categoryIds'] != null)
          "categoryIds": decoded['categoryIds'],
        if (decoded['category_list'] != null)
          "category_list": decoded['category_list'],
        if (decoded['url'] != null) "link": "/product/${decoded['url']}/",
      };
      _applyDiscountConfigToProduct(result);
      return result;
    } catch (e, st) {
      debugPrint("Product info error for $productId: $e");
      if (kDebugMode) debugPrint("$st");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProductReviewsById(
    String productId,
  ) async {
    if (productId.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final results = await Future.wait([
        _fetchProductReviewsFromWebasyst(productId),
        _fetchProductReviewsFromCustom(productId),
      ]);
      final base = results[0];
      final custom = results[1];
      if (base.isEmpty) return custom;
      if (custom.isNotEmpty) {
        _mergeReviewImagesInto(base, custom);
      }
      return base;
    } catch (e) {
      debugPrint("Product reviews error for $productId: $e");
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProductReviewsFromWebasyst(
    String productId,
  ) async {
    try {
      final response = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.product.reviews.getTree?product_id=$productId&access_token=$_apiToken',
        ),
      );
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final decoded = json.decode(response.body);
      dynamic data = decoded;
      if (decoded is Map) {
        if (decoded.containsKey('data')) data = decoded['data'];
        if (decoded.containsKey('reviews')) data = decoded['reviews'];
      }
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['reviews'] is List) {
        return (data['reviews'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint("Product reviews webasyst error for $productId: $e");
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProductReviewsFromCustom(
    String productId,
  ) async {
    try {
      final response = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/get_reviews.php?product_id=$productId',
        ),
      );
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final decoded = json.decode(response.body);
      dynamic data = decoded;
      if (decoded is Map) {
        if (decoded.containsKey('data')) data = decoded['data'];
        if (decoded.containsKey('reviews')) data = decoded['reviews'];
      }
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['reviews'] is List) {
        return (data['reviews'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint("Product reviews custom error for $productId: $e");
      return const <Map<String, dynamic>>[];
    }
  }

  void _mergeReviewImagesInto(
    List<Map<String, dynamic>> baseReviews,
    List<Map<String, dynamic>> customReviews,
  ) {
    final Map<String, dynamic> imagesById = {};
    for (final item in customReviews) {
      final id = item['id']?.toString() ?? "";
      if (id.isEmpty) continue;
      final images = item['images'];
      if (images != null) {
        imagesById[id] = images;
      }
    }
    if (imagesById.isEmpty) return;

    void walk(Map review) {
      final id = review['id']?.toString() ?? "";
      if (id.isNotEmpty && imagesById.containsKey(id)) {
        review['images'] = imagesById[id];
      }
      final comments =
          review['comments'] ?? review['children'] ?? review['replies'];
      if (comments is List) {
        for (final item in comments) {
          if (item is Map) walk(item);
        }
      }
    }

    for (final item in baseReviews) {
      walk(item);
    }
  }

  Future<bool> _submitProductReview({
    required String productId,
    required String name,
    required String title,
    required String text,
    required int rate,
    required List<XFile> photos,
  }) async {
    if (productId.isEmpty) return false;
    try {
      final safeName = name.trim().isEmpty ? "Александр" : name.trim();
      final fields = <String, String>{
        "access_token": _apiToken,
        "product_id": productId,
        "name": safeName,
        "title": title,
        "text": text,
        "rate": rate.toString(),
      };
      final uri = Uri.parse('https://hozyain-barin.ru/post_review.php');
      final files = <MultipartFile>[];
      for (final photo in photos) {
        final path = photo.path;
        if (path.isEmpty) continue;
        files.add(await MultipartFile.fromFile(path));
      }
      final formData = FormData.fromMap({
        ...fields,
        if (files.isNotEmpty) 'images[]': files,
      });
      final dio = _getAuthDio();
      final response = await dio.postUri(
        uri,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          validateStatus: (_) => true,
        ),
      );
      final body = _responseDataToString(response.data);
      return _isReviewSubmitOk(response.statusCode ?? 0, body);
    } catch (e) {
      debugPrint("Submit review error for $productId: $e");
      return false;
    }
  }

  bool _isReviewSubmitOk(int statusCode, String body) {
    if (statusCode != 200) return false;
    if (body.trim().isEmpty) return true;
    try {
      final decoded = json.decode(body);
      if (decoded is Map) {
        if (decoded["error"] != null || decoded["errors"] != null) {
          return false;
        }
      }
    } catch (_) {
      // Non-JSON response: treat as success for 200.
    }
    return true;
  }

  String _normalizeCustomerPhotoUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith("http://") || value.startsWith("https://")) {
      return value;
    }
    if (value.startsWith("//")) return "https:$value";
    if (value.startsWith("/")) return "https://hozyain-barin.ru$value";
    return value;
  }

  Future<Map<String, dynamic>?> _fetchCustomerInfoById(String contactId) async {
    if (contactId.isEmpty) return null;
    try {
      final response = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.customer.search?hash=id/$contactId&access_token=$_apiToken',
        ),
      );
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      dynamic data = decoded;
      if (decoded is Map) {
        if (decoded['data'] != null) data = decoded['data'];
        if (decoded['contacts'] != null) data = decoded['contacts'];
        if (decoded['customers'] != null) data = decoded['customers'];
      }
      Map? contact;
      if (data is List && data.isNotEmpty && data.first is Map) {
        contact = data.first as Map;
      } else if (data is Map) {
        contact = data;
      }
      if (contact == null) return null;
      final nameRaw =
          contact['name'] ??
          contact['contact_name'] ??
          contact['fullname'] ??
          contact['display_name'];
      final first = contact['firstname'] ?? contact['first_name'];
      final last = contact['lastname'] ?? contact['last_name'];
      final fullName = [
        first,
        last,
      ].where((v) => v != null && v.toString().trim().isNotEmpty).join(" ");
      final name = (fullName.isNotEmpty ? fullName : nameRaw?.toString() ?? "")
          .trim();
      final photoRaw =
          contact['photo_url'] ??
          contact['photo_url_200'] ??
          contact['photo_url_96'] ??
          contact['photo_url_40'] ??
          contact['photo'] ??
          contact['userpic'] ??
          contact['userpic_url'];
      final photo = photoRaw != null
          ? _normalizeCustomerPhotoUrl(photoRaw.toString())
          : "";
      if (name.isEmpty && photo.isEmpty) return null;
      return {
        "id": contactId,
        if (name.isNotEmpty) "name": name,
        if (photo.isNotEmpty) "photo_url": photo,
      };
    } catch (e) {
      debugPrint("Customer info error for $contactId: $e");
      return null;
    }
  }

  bool _matchesSelectedFeatures(String productId) {
    if (_selectedFeatures.isEmpty) return true;
    final features = _productFeaturesById[productId];
    if (features == null) return false;
    for (final entry in _selectedFeatures.entries) {
      final fid = entry.key;
      final vids = entry.value;
      if (vids.isEmpty) continue;
      final code = _featureCodeById[fid];
      final key = (code != null && code.isNotEmpty) ? code : fid;
      final rawValue = features[key];
      final productValues = _normalizeFeatureValues(rawValue);
      if (productValues.isEmpty) return false;
      final selectedTexts = vids
          .map((vid) {
            final text = _featureValueTextById[fid]?[vid];
            return (text == null || text.isEmpty) ? vid : text;
          })
          .map(_normalizeComparable)
          .where((v) => v.isNotEmpty)
          .toSet();
      final productValuesNormalized = productValues
          .map(_normalizeComparable)
          .where((v) => v.isNotEmpty)
          .toSet();
      if (selectedTexts.isEmpty || productValuesNormalized.isEmpty) {
        return false;
      }
      final hasMatch = productValuesNormalized.any(
        (val) => selectedTexts.contains(val),
      );
      if (!hasMatch) return false;
    }
    return true;
  }

  bool _matchesSelectedStocks(String productId) {
    if (_selectedStocks.isEmpty) return true;
    final stocks = _productStockById[productId];
    if (stocks == null || stocks.isEmpty) return false;
    for (final sid in _selectedStocks) {
      final count = stocks[sid] ?? 0;
      if (count > 0) return true;
    }
    return false;
  }

  List<String> _normalizeFeatureValues(dynamic rawValue) {
    final List<String> values = [];
    if (rawValue == null) return values;
    if (rawValue is List) {
      for (final item in rawValue) {
        if (item is Map) {
          if (item['value'] != null) {
            values.add(item['value'].toString());
          } else if (item['name'] != null) {
            values.add(item['name'].toString());
          } else {
            values.add(item.toString());
          }
        } else {
          values.add(item.toString());
        }
      }
    } else if (rawValue is Map) {
      if (rawValue['value'] != null) {
        values.add(rawValue['value'].toString());
      } else if (rawValue['name'] != null) {
        values.add(rawValue['name'].toString());
      } else {
        values.add(rawValue.toString());
      }
    } else {
      values.add(rawValue.toString());
    }
    return values;
  }

  String _normalizeComparable(String value) {
    return value.trim().toLowerCase();
  }

  bool _stringSetEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }

  bool _isInBuildPhase() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    return phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
  }

  void _setScrollingNotifier(bool value) {
    if (_scrollingNotifier.value == value) return;
    void applyValue() {
      _scrollingNotifier.value = value;
      if (!value) {
        _scheduleGalleryNotifyFlush();
      }
    }

    if (_isInBuildPhase()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollingNotifier.value != value) {
          applyValue();
        }
      });
      return;
    }
    applyValue();
  }

  void _setScrollVisibleMainImageIds(Set<String> newSet) {
    if (_stringSetEquals(_scrollVisibleMainImageIds.value, newSet)) return;
    if (_isInBuildPhase()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            !_stringSetEquals(_scrollVisibleMainImageIds.value, newSet)) {
          _scrollVisibleMainImageIds.value = newSet;
        }
      });
      return;
    }
    _scrollVisibleMainImageIds.value = newSet;
  }

  double _estimateNativeRowExtent() {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 8.0;
    const crossAxisSpacing = 3.0;
    const mainAxisSpacing = 5.0;
    final itemWidth = (screenWidth - horizontalPadding - crossAxisSpacing) / 2;
    final imageHeight = itemWidth * 4 / 3;
    const contentHeight = 146.0; // slight bump to avoid 1px overflow
    final itemHeight = imageHeight + contentHeight;
    return itemHeight + mainAxisSpacing;
  }

  void _updateScrollVisibleMainImages() {
    if (!mounted || !_isNativeCategoryPage) return;
    if (!_nativeScrollController.hasClients) return;
    if (_nativeScrollController.position.viewportDimension == 0) return;
    final list = _getActiveNativeList();
    if (list.isEmpty) return;

    // Расчёт диапазона видимых карточек
    final scrollPosition = _nativeScrollController.position.pixels;
    final viewportHeight = _nativeScrollController.position.viewportDimension;
    final cardHeight = _estimateNativeRowExtent();

    final visibleStartRow = (scrollPosition / cardHeight).floor();
    final visibleEndRow =
        ((scrollPosition + viewportHeight) / cardHeight).ceil() + 1;
    final visibleStartIndex = (visibleStartRow * 2).clamp(0, list.length);
    final visibleEndIndex = (visibleEndRow * 2).clamp(0, list.length);
    final visibleCount = (visibleEndIndex - visibleStartIndex).clamp(
      0,
      list.length,
    );

    // Галерея только для видимой части.
    const int extraTopRows = 1;
    const int extraBottomRows = 2;
    final startRow = visibleStartRow - extraTopRows;
    final endRow = visibleEndRow + extraBottomRows;
    final startIndex = (startRow * 2).clamp(0, list.length);
    final endIndex = (endRow * 2).clamp(0, list.length);
    if (startIndex >= endIndex) return;

    final int prefetchCount = endIndex - startIndex;
    const int bufferCount = (extraTopRows + extraBottomRows) * 2;
    int maxMainImages = _isUserScrolling
        ? (visibleCount.clamp(0, 4))
        : (visibleCount + bufferCount);
    if (!_isUserScrolling && maxMainImages < visibleCount) {
      maxMainImages = visibleCount;
    }
    if (maxMainImages > prefetchCount) {
      maxMainImages = prefetchCount;
    }
    final newSet = <String>{};
    // Сначала добавляем все видимые карточки
    for (int i = visibleStartIndex; i < visibleEndIndex; i++) {
      if (newSet.length >= maxMainImages) break;
      final p = list[i];
      if (p is! Map) continue;
      final id = p['id']?.toString() ?? "";
      if (id.isEmpty) continue;
      newSet.add(id);
    }
    // Затем добавляем буфер сверху
    for (int i = visibleStartIndex - 1; i >= startIndex; i--) {
      if (newSet.length >= maxMainImages) break;
      final p = list[i];
      if (p is! Map) continue;
      final id = p['id']?.toString() ?? "";
      if (id.isEmpty) continue;
      newSet.add(id);
    }
    // И буфер снизу
    for (int i = visibleEndIndex; i < endIndex; i++) {
      if (newSet.length >= maxMainImages) break;
      final p = list[i];
      if (p is! Map) continue;
      final id = p['id']?.toString() ?? "";
      if (id.isEmpty) continue;
      newSet.add(id);
    }

    _setScrollVisibleMainImageIds(newSet);
  }

  void _scheduleVisibleGalleryRetry(String categoryKey, {int delayMs = 800}) {
    if (_visibleGalleryRetryTimer?.isActive == true) return;
    _visibleGalleryRetryTimer = Timer(Duration(milliseconds: delayMs), () {
      _visibleGalleryRetryTimer = null;
      if (!mounted || !_isNativeCategoryPage || _isUserScrolling) return;
      if (categoryKey != _nativeCategory) return;
      final list = _getNativeListByKey(categoryKey);
      if (list.isEmpty) return;
      _loadGalleriesForVisibleProducts(categoryKey, list);
    });
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  bool _isGalleryNoImagesCooldown(String productId) {
    final until = _galleryNoImagesUntilMs[productId];
    if (until == null) return false;
    if (_nowMs() >= until) {
      _galleryNoImagesUntilMs.remove(productId);
      return false;
    }
    return true;
  }

  void _markGalleryNoImages(String productId) {
    if (productId.isEmpty) return;
    final int attempts = (_galleryNoImagesAttempts[productId] ?? 0) + 1;
    _galleryNoImagesAttempts[productId] = attempts;
    int delayMs;
    if (attempts <= 1) {
      delayMs = 8000;
    } else if (attempts == 2) {
      delayMs = 20000;
    } else {
      delayMs = 60000;
    }
    _galleryNoImagesUntilMs[productId] = _nowMs() + delayMs;
  }

  void _clearGalleryNoImages(String productId) {
    _galleryNoImagesUntilMs.remove(productId);
    _galleryNoImagesAttempts.remove(productId);
  }

  List<Map<dynamic, dynamic>> _normalizeImageList(dynamic decoded) {
    List<dynamic> raw = [];
    if (decoded is List) {
      raw = decoded;
    } else if (decoded is Map) {
      final dynamic data =
          decoded['data'] ?? decoded['images'] ?? decoded['items'];
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        raw = data.values.toList();
      } else {
        raw = decoded.values.toList();
      }
    }
    return raw.whereType<Map>().toList();
  }

  void _resetVisibleRangeForCategory(String categoryKey) {
    _lastVisibleCategoryKey = categoryKey;
    _lastVisibleStart = -1;
    _lastVisibleEnd = -1;
  }

  void _resetNativeCategoryScroll() {
    _scrollIdleTimer?.cancel();
    _scrollStopNotifierTimer?.cancel();
    _scrollVisibleImagesTimer?.cancel();
    _visibleGalleryLoadTimer?.cancel();
    _isUserScrolling = false;
    _scrollVelocityPxPerSec = 0.0;
    _lastScrollSampleMs = null;
    _lastScrollSamplePos = 0.0;
    _lastVisibleGalleryLoadMs = null;
    _setScrollingNotifier(false);
    void jumpToTop() {
      if (!mounted || !_nativeScrollController.hasClients) return;
      _nativeScrollController.jumpTo(0);
    }

    if (_nativeScrollController.hasClients) {
      jumpToTop();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToTop());
    }
  }

  void _openNativeCategoryById({
    required String key,
    required String categoryId,
    required String title,
  }) {
    final prevNative = _nativeCategory;
    _nativeCustomCategoryIdByKey[key] = categoryId;
    _rememberCategoryForBackNavigation(nextKey: key);
    setState(() {
      _pageTitle = title;
      _isNativeCategoryPage = true;
      _nativeCategory = key;
      _resetVisibleRangeForCategory(_nativeCategory);
    });
    _updatePageTitleFromCategory(categoryId, key, fallback: title);
    if (prevNative != key) {
      _animatedProductIds.clear();
      _resetNativeCategoryScroll();
    }
    _fetchNativeCategory(
      key: key,
      categoryId: categoryId,
      customParams: _nativeFilterParams[key],
      reset: true,
    );
    _scheduleVisibleGalleryLoad(_nativeCategory);
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  String _getProductPreviewImage(dynamic product) {
    if (product is! Map) return "";
    final images = product['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first?.toString() ?? "";
      if (first.isNotEmpty) return first;
    }
    final image = product['image'] ?? product['image_url'];
    if (image != null) {
      return image.toString();
    }
    return "";
  }

  static final RegExp _previewSizeTokenRegex = RegExp(r'\.0x\d+\.');
  static final RegExp _previewSizeAltRegex = RegExp(r'\.\d+x\d+\.');

  String _toPreviewThumbUrl(String url) {
    if (url.isEmpty) return url;
    if (_previewSizeTokenRegex.hasMatch(url)) {
      return url.replaceAll(_previewSizeTokenRegex, '.0x200.');
    }
    if (_previewSizeAltRegex.hasMatch(url)) {
      return url.replaceAll(_previewSizeAltRegex, '.0x200.');
    }
    return url;
  }

  void _precacheCategoryPreviewImages(List<dynamic> items, {int limit = 6}) {
    if (!mounted || items.isEmpty) return;
    int count = 0;
    for (final item in items) {
      if (count >= limit) break;
      if (item is! Map) continue;
      final url = _getProductPreviewImage(item);
      if (url.isEmpty) continue;
      final thumbUrl = _toPreviewThumbUrl(url);
      precacheImage(CachedNetworkImageProvider(thumbUrl), context);
      count++;
    }
  }

  void _showFavoriteToast(dynamic product, bool added) {
    if (!mounted) return;
    _favoriteOverlayTimer?.cancel();
    _favoriteOverlayEntry?.remove();

    final title = added
        ? "Товар добавлен в избранное"
        : "Товар удален из списка избранного";
    final name = (product is Map ? product['name']?.toString() : null) ?? "";
    final imageUrl = _getProductPreviewImage(product);

    _favoriteOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 6,
        left: 8,
        right: 8,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 0.0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return FractionalTranslation(
              translation: Offset(value, 0),
              child: child,
            );
          },
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: true,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image(
                              image: ResizeImage(
                                CachedNetworkImageProvider(imageUrl),
                                width: 120,
                                height: 160,
                              ),
                              width: 46,
                              height: 62,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                        if (imageUrl.isNotEmpty) const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: _menuStyle.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (name.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    name,
                                    style: _subMenuStyle.copyWith(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final overlay = Overlay.of(context);
    overlay.insert(_favoriteOverlayEntry!);
    _favoriteOverlayTimer = Timer(const Duration(seconds: 2), () {
      _favoriteOverlayEntry?.remove();
      _favoriteOverlayEntry = null;
    });
  }

  void _showCompareToast(dynamic product, bool added) {
    if (!mounted) return;
    _compareOverlayTimer?.cancel();
    _compareOverlayEntry?.remove();

    final title = added
        ? "Товар добавлен к сравнению"
        : "Товар удален из списка сравнения";
    final name = (product is Map ? product['name']?.toString() : null) ?? "";
    final imageUrl = _getProductPreviewImage(product);

    _compareOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 6,
        left: 8,
        right: 8,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 0.0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return FractionalTranslation(
              translation: Offset(value, 0),
              child: child,
            );
          },
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: true,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image(
                              image: ResizeImage(
                                CachedNetworkImageProvider(imageUrl),
                                width: 120,
                                height: 160,
                              ),
                              width: 46,
                              height: 62,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                        if (imageUrl.isNotEmpty) const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: _menuStyle.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (name.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    name,
                                    style: _subMenuStyle.copyWith(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final overlay = Overlay.of(context);
    overlay.insert(_compareOverlayEntry!);
    _compareOverlayTimer = Timer(const Duration(seconds: 2), () {
      _compareOverlayEntry?.remove();
      _compareOverlayEntry = null;
    });
  }

  void _showCartToast(dynamic product) {
    if (!mounted) return;
    _cartOverlayTimer?.cancel();
    _cartOverlayEntry?.remove();

    const title = "Товар добавлен в корзину";
    final name = (product is Map ? product['name']?.toString() : null) ?? "";
    final imageUrl = _getProductPreviewImage(product);

    _cartOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 6,
        left: 8,
        right: 8,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 0.0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return FractionalTranslation(
              translation: Offset(value, 0),
              child: child,
            );
          },
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: true,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image(
                              image: ResizeImage(
                                CachedNetworkImageProvider(imageUrl),
                                width: 120,
                                height: 160,
                              ),
                              width: 46,
                              height: 62,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                        if (imageUrl.isNotEmpty) const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: _menuStyle.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (name.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    name,
                                    style: _subMenuStyle.copyWith(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final overlay = Overlay.of(context);
    overlay.insert(_cartOverlayEntry!);
    _cartOverlayTimer = Timer(const Duration(seconds: 2), () {
      _cartOverlayEntry?.remove();
      _cartOverlayEntry = null;
    });
  }

  void _addToCart(dynamic product) {
    if (product is! Map) return;
    final productId = product['id']?.toString() ?? "";
    if (productId.isEmpty) return;
    _cartQuantityByProductId[productId] =
        (_cartQuantityByProductId[productId] ?? 0) + 1;
    if (!_cartProductsById.containsKey(productId)) {
      try {
        _cartProductsById[productId] = Map<String, dynamic>.from(product);
      } catch (_) {
        _cartProductsById[productId] = <String, dynamic>{
          'id': productId,
          ...product,
        };
      }
      _cartSelectedIds.add(productId);
      _cartSelectionNotifier.value = !_cartSelectionNotifier.value;
    }
    _cartCountNotifier.value = _cartQuantityByProductId.values.fold(
      0,
      (a, b) => a + b,
    );
    _showCartToast(product);
  }

  List<Map<String, dynamic>> _getCartItems() {
    final items = <Map<String, dynamic>>[];
    for (final entry in _cartQuantityByProductId.entries) {
      final product = _cartProductsById[entry.key];
      if (product != null) {
        items.add({...product, 'cart_quantity': entry.value});
      }
    }
    return items;
  }

  void _removeFromCart(String productId) {
    _cartQuantityByProductId.remove(productId);
    _cartProductsById.remove(productId);
    _cartSelectedIds.remove(productId);
    _cartCountNotifier.value = _cartQuantityByProductId.values.fold(
      0,
      (a, b) => a + b,
    );
    _cartSelectionNotifier.value = !_cartSelectionNotifier.value;
    if (mounted) setState(() {});
  }

  void _updateCartQuantity(String productId, int delta) {
    final current = _cartQuantityByProductId[productId] ?? 0;
    final newQty = (current + delta).clamp(0, 999);
    if (newQty <= 0) {
      _removeFromCart(productId);
    } else {
      _cartQuantityByProductId[productId] = newQty;
      _cartCountNotifier.value = _cartQuantityByProductId.values.fold(
        0,
        (a, b) => a + b,
      );
      if (mounted) setState(() {});
    }
  }

  void _clearCart() {
    _cartQuantityByProductId.clear();
    _cartProductsById.clear();
    _cartSelectedIds.clear();
    _cartCountNotifier.value = 0;
    _cartSelectionNotifier.value = !_cartSelectionNotifier.value;
    if (mounted) setState(() {});
  }

  void _openCheckoutPage() {
    final items = _getCartItems();
    if (items.isEmpty) return;
    final showSelectionUI = items.length > 1;
    final selectedItems = showSelectionUI
        ? items
              .where(
                (item) =>
                    _cartSelectedIds.contains(item['id']?.toString() ?? ""),
              )
              .toList()
        : items;
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Выберите товары для оформления")),
      );
      return;
    }
    double totalSum = 0.0;
    final payloadItems = <Map<String, dynamic>>[];
    for (final item in selectedItems) {
      final id = item['id']?.toString() ?? "";
      if (id.isEmpty) continue;
      final qty = item['cart_quantity'] as int? ?? 1;
      final raw = item['raw_price'] ?? item['price'];
      final price = (raw is num) ? raw.toDouble() : _parsePriceValue(raw);
      totalSum += price * qty;
      payloadItems.add({
        'id': id,
        'name': item['name']?.toString() ?? "",
        'quantity': qty,
        'price': price,
      });
    }
    Navigator.push(
      context,
      _adaptivePageRoute(
        builder: (_) => CheckoutPage(
          items: payloadItems,
          total: totalSum,
          onOrderSuccess: _clearCart,
        ),
      ),
    );
  }

  void _toggleCartSelection(String productId) {
    if (_cartSelectedIds.contains(productId)) {
      _cartSelectedIds.remove(productId);
    } else {
      _cartSelectedIds.add(productId);
    }
    _cartSelectionNotifier.value = !_cartSelectionNotifier.value;
    if (mounted) setState(() {});
  }

  void _selectAllCart(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final id = item['id']?.toString() ?? "";
      if (id.isNotEmpty) _cartSelectedIds.add(id);
    }
    _cartSelectionNotifier.value = !_cartSelectionNotifier.value;
    if (mounted) setState(() {});
  }

  void _deselectAllCart() {
    _cartSelectedIds.clear();
    _cartSelectionNotifier.value = !_cartSelectionNotifier.value;
    if (mounted) setState(() {});
  }

  void _deleteSelectedFromCart() {
    for (final id in _cartSelectedIds.toList()) {
      _removeFromCart(id);
    }
    _cartSelectedIds.clear();
    _cartSelectionNotifier.value = !_cartSelectionNotifier.value;
  }

  Map<String, int> _getStockMapForProduct(
    String productId,
    Map<String, dynamic>? product,
  ) {
    final resolved = _productStockById[productId];
    if (resolved != null && resolved.isNotEmpty) {
      return Map<String, int>.from(resolved);
    }
    final raw = product?['stock_map'];
    if (raw is Map) {
      final mapped = <String, int>{};
      raw.forEach((key, value) {
        final sid = key?.toString() ?? "";
        if (sid.isEmpty) return;
        final c = (value is num)
            ? value.toInt()
            : int.tryParse(value?.toString() ?? "0") ?? 0;
        if (c <= 0) return;
        mapped[sid] = c;
      });
      if (mapped.isNotEmpty) return mapped;
    }
    return {};
  }

  void _showCartStockSheet(
    BuildContext context,
    String productId,
    Map<String, dynamic>? product,
  ) {
    final stockMap = _getStockMapForProduct(productId, product);
    if (stockMap.isEmpty) return;
    final scrollController = ScrollController();
    bool showScrollHint = false;
    bool checkedOverflow = false;
    bool pulseUp = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.7;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _getStoresHierarchyForModal(),
              builder: (ctx2, snapshot) {
                final hierarchy = snapshot.data;
                final excludeIds = _extractExcludedStockIdsFromHierarchy(
                  hierarchy,
                );
                final filteredMap = _filterStockMapByExclude(
                  stockMap,
                  excludeIds,
                );
                final hasHierarchy =
                    hierarchy != null && hierarchy['cities'] is List;
                final groups = hasHierarchy
                    ? _buildHierarchyGroupsForModal(
                        filteredMap,
                        hierarchy,
                        _availableStocks,
                      )
                    : _buildFallbackGroupsForModal(
                        filteredMap,
                        _availableStocks,
                      );
                final total = _sumGroupCountsForModal(groups);
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    hierarchy == null;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const SizedBox(height: 6),
                      _buildBottomSheetHandle(),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 36),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "В наличии ",
                                        style: _boldMenuStyle.copyWith(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w100,
                                          color: Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: "$total шт.",
                                        style: _boldMenuStyle.copyWith(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w100,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -8,
                              child: IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.black54,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            height: 28,
                            width: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        )
                      else if (groups.isEmpty)
                        Text(
                          "Нет данных по наличию",
                          style: _subMenuStyle.copyWith(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        )
                      else
                        Expanded(
                          child: StatefulBuilder(
                            builder: (ctx3, setModalState) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!ctx3.mounted ||
                                    !scrollController.hasClients) {
                                  return;
                                }
                                if (checkedOverflow) return;
                                checkedOverflow = true;
                                final canScroll =
                                    scrollController.position.maxScrollExtent >
                                    0;
                                if (showScrollHint != canScroll) {
                                  setModalState(
                                    () => showScrollHint = canScroll,
                                  );
                                }
                              });
                              return NotificationListener<
                                ScrollUpdateNotification
                              >(
                                onNotification: (n) {
                                  if (showScrollHint && n.metrics.pixels > 0) {
                                    setModalState(() => showScrollHint = false);
                                  }
                                  return false;
                                },
                                child: Stack(
                                  children: [
                                    ListView(
                                      controller: scrollController,
                                      padding: EdgeInsets.only(
                                        bottom: showScrollHint ? 30 : 0,
                                      ),
                                      children: groups.map((group) {
                                        final title =
                                            group["title"]?.toString() ?? "";
                                        final items =
                                            group["items"] as List? ?? const [];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 7,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: _boldMenuStyle.copyWith(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w100,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              for (final item in items) ...[
                                                _buildStockRowForModal(
                                                  name:
                                                      item["name"]
                                                          ?.toString() ??
                                                      "",
                                                  count:
                                                      item["count"] as int? ??
                                                      0,
                                                ),
                                                const SizedBox(height: 5),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    if (showScrollHint)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: IgnorePointer(
                                          child: Container(
                                            padding: const EdgeInsets.only(
                                              top: 16,
                                              bottom: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.75,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.98,
                                                  ),
                                                ],
                                                stops: const [0.0, 0.55, 1.0],
                                              ),
                                            ),
                                            child:
                                                TweenAnimationBuilder<double>(
                                                  tween: Tween(
                                                    begin: pulseUp ? 0.85 : 1.1,
                                                    end: pulseUp ? 1.1 : 0.85,
                                                  ),
                                                  duration: const Duration(
                                                    milliseconds: 900,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                  onEnd: () {
                                                    if (showScrollHint) {
                                                      setModalState(
                                                        () =>
                                                            pulseUp = !pulseUp,
                                                      );
                                                    }
                                                  },
                                                  builder: (_, scale, child) =>
                                                      Transform.scale(
                                                        scale: scale,
                                                        child: child,
                                                      ),
                                                  child: const Icon(
                                                    Icons.keyboard_arrow_down,
                                                    size: 28,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _syncWishlistList() {
    final items = <dynamic>[];
    for (final id in _favoriteIds) {
      final product = _favoriteProductsById[id];
      if (product != null) items.add(product);
    }
    _nativeLists["wishlist"] = items;
    _originalNativeLists["wishlist"] = List<dynamic>.from(items);
  }

  void _syncCompareList() {
    final items = <dynamic>[];
    for (final id in _compareIds) {
      final product = _compareProductsById[id];
      if (product != null) items.add(product);
    }
    _nativeLists["compare"] = items;
    _originalNativeLists["compare"] = List<dynamic>.from(items);
  }

  Future<void> _ensureCompareDetails() async {
    final items = _getNativeListByKey("compare");
    if (items.isEmpty) return;
    await _ensureProductDetails(items);
    if (mounted && _nativeCategory == "compare") {
      setState(() {});
    }
  }

  void _toggleFavorite(dynamic product) {
    if (product is! Map) return;
    final id = product['id']?.toString() ?? "";
    if (id.isEmpty) return;
    final bool added;
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      added = false;
    } else {
      _favoriteIds.add(id);
      added = true;
    }
    if (added) {
      try {
        _favoriteProductsById[id] = Map<String, dynamic>.from(product);
      } catch (_) {
        _favoriteProductsById[id] = <String, dynamic>{'id': id};
      }
    } else {
      _favoriteProductsById.remove(id);
    }
    if (_nativeCategory == "wishlist" || _nativeCategory == "compare") {
      _syncWishlistList();
    }
    _wishCountNotifier.value = _favoriteIds.length;
    _getFavoriteNotifier(id).value++;
    _showFavoriteToast(product, added);
  }

  void _toggleCompare(dynamic product) {
    if (product is! Map) return;
    final id = product['id']?.toString() ?? "";
    if (id.isEmpty) return;
    final bool added;
    if (_compareIds.contains(id)) {
      _compareIds.remove(id);
      added = false;
    } else {
      _compareIds.add(id);
      added = true;
    }
    if (added) {
      try {
        _compareProductsById[id] = Map<String, dynamic>.from(product);
      } catch (_) {
        _compareProductsById[id] = <String, dynamic>{'id': id};
      }
    } else {
      _compareProductsById.remove(id);
    }
    _compareCountNotifier.value = _compareIds.length;
    _getCompareNotifier(id).value++;
    _showCompareToast(product, added);
    if (_nativeCategory == "compare") {
      _syncCompareList();
      _ensureCompareDetails();
    }
  }

  void _clearFavorites() {
    if (_favoriteIds.isEmpty) return;
    final ids = List<String>.from(_favoriteIds);
    _favoriteIds.clear();
    _favoriteProductsById.clear();
    _syncWishlistList();
    _wishCountNotifier.value = 0;
    for (final id in ids) {
      final notifier = _favoriteVersionById[id];
      if (notifier != null) notifier.value++;
    }
  }

  void _clearCompare() {
    if (_compareIds.isEmpty) return;
    final ids = List<String>.from(_compareIds);
    _compareIds.clear();
    _compareProductsById.clear();
    _compareRemovingIds.clear();
    _compareCollapsedGroups.clear();
    _compareGroupKeys.clear();
    _compareOnlyDifferences = false;
    _compareLeftIndexByGroup.clear();
    _compareRightIndexByGroup.clear();
    _activeCompareGroupKey = null;
    _compareCountNotifier.value = 0;
    for (final id in ids) {
      final notifier = _compareVersionById[id];
      if (notifier != null) notifier.value++;
    }
    if (_nativeCategory == "compare") {
      _syncCompareList();
      _ensureCompareDetails();
      if (_isInBuildPhase()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _updatePageTitleFromCategory(
    String categoryId,
    String expectedKey, {
    String fallback = "",
  }) async {
    String resolved = _getCategoryTitleById(categoryId, fallback);
    if (resolved.isNotEmpty && resolved != _pageTitle) {
      if (mounted && _nativeCategory == expectedKey) {
        setState(() => _pageTitle = resolved);
      }
      return;
    }
    try {
      final response = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.category.getInfo?id=$categoryId&access_token=$_apiToken',
        ),
      );
      if (response.statusCode != 200) return;
      final decoded = json.decode(response.body);
      if (decoded is! Map) return;
      final name = decoded['name']?.toString() ?? "";
      if (name.isEmpty) return;
      if (mounted && _nativeCategory == expectedKey) {
        setState(() => _pageTitle = name);
      }
    } catch (e, st) {
      debugPrint("Category title error for $categoryId: $e");
      if (kDebugMode) debugPrint("$st");
    }
  }

  void _resetDiscountScroll() {
    void jumpToStart() {
      if (!mounted || !_discountScrollController.hasClients) return;
      _discountScrollController.jumpTo(0);
    }

    if (_discountScrollController.hasClients) {
      jumpToStart();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToStart());
    }
  }

  void _scheduleVisibleGalleryLoad(String categoryKey, {int attempts = 4}) {
    if (!mounted || attempts <= 0) return;
    if (!_isNativeCategoryPage) return;
    if (categoryKey != _nativeCategory) return;
    final list = _getNativeListByKey(categoryKey);
    if (list.isEmpty) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _scheduleVisibleGalleryLoad(categoryKey, attempts: attempts - 1);
      });
      return;
    }
    if (_isUserScrolling || _isLoadingVisibleGalleries) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _scheduleVisibleGalleryLoad(categoryKey, attempts: attempts - 1);
      });
      return;
    }
    if (!_nativeScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleVisibleGalleryLoad(categoryKey, attempts: attempts - 1);
      });
      return;
    }
    if (_nativeScrollController.position.viewportDimension == 0) {
      Future.delayed(const Duration(milliseconds: 16), () {
        _scheduleVisibleGalleryLoad(categoryKey, attempts: attempts - 1);
      });
      return;
    }
    _updateScrollVisibleMainImages();
    _loadGalleriesForVisibleProducts(categoryKey, list);
  }

  Future<void> _loadGalleriesForVisibleProducts(
    String categoryKey,
    List<dynamic> allProducts,
  ) async {
    if (!_nativeScrollController.hasClients ||
        allProducts.isEmpty ||
        !mounted) {
      return;
    }
    if (_isUserScrolling) {
      _pendingVisibleGalleryReload = true;
      return;
    }
    if (_isLoadingVisibleGalleries) {
      _pendingVisibleGalleryReload = true;
      return;
    }
    const int visibleGalleryThrottleMs = 200;
    final int nowMs = _nowMs();
    final int? lastMs = _lastVisibleGalleryLoadMs;
    if (lastMs != null && nowMs - lastMs < visibleGalleryThrottleMs) {
      _pendingVisibleGalleryReload = true;
      if (_visibleGalleryLoadTimer?.isActive != true) {
        final int remainingMs = visibleGalleryThrottleMs - (nowMs - lastMs);
        final int delayMs = remainingMs
            .clamp(0, visibleGalleryThrottleMs)
            .toInt();
        _visibleGalleryLoadTimer = Timer(Duration(milliseconds: delayMs), () {
          _visibleGalleryLoadTimer = null;
          if (!mounted || !_isNativeCategoryPage || _isUserScrolling) return;
          if (categoryKey != _nativeCategory) return;
          final list = _getNativeListByKey(categoryKey);
          if (list.isEmpty) return;
          _loadGalleriesForVisibleProducts(categoryKey, list);
        });
      }
      return;
    }
    _lastVisibleGalleryLoadMs = nowMs;
    bool shouldRetry = false;

    try {
      _isLoadingVisibleGalleries = true;
      if (_lastVisibleCategoryKey != categoryKey) {
        _lastVisibleCategoryKey = categoryKey;
        _lastVisibleStart = -1;
        _lastVisibleEnd = -1;
      }
      // Получаем позицию скролла
      final scrollPosition = _nativeScrollController.position.pixels;
      final viewportHeight = _nativeScrollController.position.viewportDimension;

      // Примерная высота карточки в гриде
      final cardHeight = _estimateNativeRowExtent();

      // Определяем диапазон видимых карточек
      // Учитываем, что карточки идут по 2 в ряд
      final visibleStartRow = (scrollPosition / cardHeight).floor();
      final visibleEndRow =
          ((scrollPosition + viewportHeight) / cardHeight).ceil() + 1;
      const int extraTopRows = 1;
      const int extraBottomRows = 2;
      final startRow = visibleStartRow - extraTopRows;
      final endRow = visibleEndRow + extraBottomRows;

      final startIndex = (startRow * 2).clamp(0, allProducts.length);
      final endIndex = (endRow * 2).clamp(0, allProducts.length);

      if (startIndex >= endIndex) return;

      // Загружаем галереи для видимых карточек
      final visibleProducts = allProducts.sublist(startIndex, endIndex);

      final List<String> cachedIds = [];
      final List<String> pendingIds = [];
      for (final p in visibleProducts) {
        if (p is! Map) continue;
        final id = p['id']?.toString() ?? "";
        if (id.isEmpty) continue;
        if (_isGalleryNoImagesCooldown(id)) continue;
        if (_galleryCache.containsKey(id)) {
          cachedIds.add(id);
        } else if (!_galleryRequestsInFlight.contains(
          _galleryRequestKey(categoryKey, id),
        )) {
          pendingIds.add(id);
        }
      }
      final bool sameRange =
          startIndex == _lastVisibleStart && endIndex == _lastVisibleEnd;
      if (sameRange && pendingIds.isEmpty) return;
      _lastVisibleStart = startIndex;
      _lastVisibleEnd = endIndex;

      // Применяем уже закэшированные галереи
      if (cachedIds.isNotEmpty) {
        for (final id in cachedIds) {
          final gallery = _galleryCache[id];
          if (gallery != null && gallery.isNotEmpty) {
            _updateProductGalleryFromCache(
              id,
              categoryKey,
              gallery,
              notify: true,
            );
          }
        }
      }

      // Загружаем параллельно для видимых карточек
      if (pendingIds.isNotEmpty) {
        final int maxImmediate = visibleProducts.length.clamp(6, 12).toInt();
        final List<String> queuedVisible = [];
        final List<String> unqueuedVisible = [];
        for (final id in pendingIds) {
          final key = _galleryRequestKey(categoryKey, id);
          if (_queuedGalleryRequestKeys.contains(key)) {
            queuedVisible.add(id);
          } else {
            unqueuedVisible.add(id);
          }
        }
        final immediateTargets = unqueuedVisible.take(maxImmediate).toList();
        final priorityTargets = [
          ...queuedVisible,
          ...unqueuedVisible.skip(maxImmediate),
        ];
        for (final productId in immediateTargets) {
          _markGalleryRequestInFlight(categoryKey, productId);
        }
        await Future.wait(
          immediateTargets.map(
            (productId) =>
                _fetchGalleryForProductImmediate(
                  productId,
                  categoryKey,
                ).catchError((e, st) {
                  debugPrint("Immediate gallery batch error: $e");
                  if (kDebugMode) debugPrint("$st");
                }),
          ),
        );
        if (priorityTargets.isNotEmpty) {
          _enqueuePriorityGalleryRequests(priorityTargets, categoryKey);
        }
        _startGalleryProcessing();
        shouldRetry = true;
      }
    } catch (e) {
      debugPrint("Error loading visible galleries: $e");
      _lastVisibleStart = -1;
      _lastVisibleEnd = -1;
    } finally {
      _isLoadingVisibleGalleries = false;
      if (mounted) {
        if (_pendingVisibleGalleryReload && !_isUserScrolling) {
          _pendingVisibleGalleryReload = false;
          final list = _getNativeListByKey(categoryKey);
          if (list.isNotEmpty) {
            Future.microtask(
              () => _loadGalleriesForVisibleProducts(categoryKey, list),
            );
          }
        } else if (shouldRetry && !_isUserScrolling) {
          _scheduleVisibleGalleryRetry(categoryKey);
        }
      }
    }
  }

  Future<void> _fetchGalleryForProductImmediate(
    String productId,
    String categoryKey,
  ) async {
    try {
      // Проверяем кэш
      if (_galleryCache.containsKey(productId)) {
        _updateProductGalleryFromCache(
          productId,
          categoryKey,
          _galleryCache[productId]!,
          notify: true,
        );
        return;
      }

      final imgRes = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.product.images.getList?product_id=$productId&access_token=$_apiToken',
        ),
      );
      if (imgRes.statusCode == 200) {
        final decoded = json.decode(imgRes.body);
        final imgData = _normalizeImageList(decoded);
        List<String> gallery = [];
        for (final img in imgData) {
          if (gallery.length >= 5) break;
          String url = img['url_thumb'] ?? "";
          if (url.isNotEmpty) {
            url = url.replaceAll(RegExp(r'\.\d+x\d+\.'), '.0x400.');
          } else {
            String sub1 = productId.length >= 2
                ? productId.substring(productId.length - 2)
                : productId.padLeft(2, '0');
            String sub2 = productId.length > 2
                ? productId.substring(0, productId.length - 2).padLeft(2, '0')
                : "00";
            url =
                "https://hozyain-barin.ru/wa-data/public/shop/products/$sub1/$sub2/$productId/images/${img['id']}/${img['id']}.0x400.jpg";
          }
          if (url.isNotEmpty) {
            gallery.add(url);
          }
        }
        if (gallery.isNotEmpty) {
          _clearGalleryNoImages(productId);
          // Сохраняем в кэш
          _putGalleryCache(productId, gallery);
          // Обновляем товар
          _updateProductGalleryFromCache(
            productId,
            categoryKey,
            gallery,
            notify: true,
          );
        } else {
          _markGalleryNoImages(productId);
        }
      }
    } catch (e, st) {
      debugPrint("Gallery fetch error for $productId: $e");
      if (kDebugMode) debugPrint("$st");
    } finally {
      _markGalleryRequestComplete(categoryKey, productId);
    }
  }

  String _toLargeProductImageUrl(String url) {
    if (url.isEmpty) return url;
    return url.replaceAll(RegExp(r'\.\d+x\d+\.'), '.0x700.');
  }

  Future<List<String>> _fetchProductImagesFull(String productId) async {
    if (productId.isEmpty) return const [];
    final cached = _productFullGalleryById[productId];
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final imgRes = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.product.images.getList?product_id=$productId&access_token=$_apiToken',
        ),
      );
      if (imgRes.statusCode == 200) {
        final decoded = json.decode(imgRes.body);
        final imgData = _normalizeImageList(decoded);
        final List<String> gallery = [];
        for (final img in imgData) {
          String url = img['url'] ?? img['url_thumb'] ?? "";
          if (url.isNotEmpty) {
            url = _toLargeProductImageUrl(url);
          } else {
            String sub1 = productId.length >= 2
                ? productId.substring(productId.length - 2)
                : productId.padLeft(2, '0');
            String sub2 = productId.length > 2
                ? productId.substring(0, productId.length - 2).padLeft(2, '0')
                : "00";
            url =
                "https://hozyain-barin.ru/wa-data/public/shop/products/$sub1/$sub2/$productId/images/${img['id']}/${img['id']}.0x700.jpg";
          }
          if (url.isNotEmpty) {
            gallery.add(url);
          }
        }
        if (gallery.isNotEmpty) {
          _productFullGalleryById[productId] = gallery;
          return gallery;
        }
      }
    } catch (e, st) {
      debugPrint("Full gallery fetch error for $productId: $e");
      if (kDebugMode) debugPrint("$st");
    }
    return const [];
  }

  void _precacheVisibleGallery(String productId, List<String> gallery) {
    if (!mounted || gallery.isEmpty) return;
    final visibleIds = _scrollVisibleMainImageIds.value;
    if (!visibleIds.contains(productId)) return;
    const int maxPrecache = 2;
    int precached = 0;
    for (final url in gallery) {
      if (url.isEmpty) continue;
      precacheImage(CachedNetworkImageProvider(url), context);
      precached++;
      if (precached >= maxPrecache) break;
    }
  }

  void _updateProductGalleryFromCache(
    String productId,
    String categoryKey,
    List<String> gallery, {
    bool notify = true,
  }) {
    // Получаем актуальные списки по ключу категории
    final list = _getNativeListByKey(categoryKey);
    final original = _getOriginalNativeListByKey(categoryKey);

    // Ищем товар по productId и обновляем
    bool updatedList = false;
    bool updatedOriginal = false;
    List<String> normalizedGallery = gallery
        .where((u) => u.isNotEmpty)
        .toList();
    for (int i = 0; i < list.length; i++) {
      if (list[i] is Map && list[i]['id']?.toString() == productId) {
        final listItem = list[i];
        if (listItem is Map) {
          final existingGallery = listItem['gallery'];
          final existingLen = existingGallery is List
              ? existingGallery.length
              : 0;
          if (existingLen < normalizedGallery.length) {
            listItem['gallery'] = normalizedGallery;
            _putGalleryCache(productId, normalizedGallery);
            updatedList = true;
          }
        }
        break;
      }
    }

    for (int i = 0; i < original.length; i++) {
      if (original[i] is Map && original[i]['id']?.toString() == productId) {
        final originalItem = original[i];
        if (originalItem is Map) {
          final existingGallery = originalItem['gallery'];
          final existingLen = existingGallery is List
              ? existingGallery.length
              : 0;
          if (existingLen < normalizedGallery.length) {
            originalItem['gallery'] = normalizedGallery;
            _putGalleryCache(productId, normalizedGallery);
            updatedOriginal = true;
          }
        }
        break;
      }
    }

    // Если обновили, пересоздаем списки и обновляем UI
    if ((updatedList || updatedOriginal) && notify) {
      _notifyGalleryUpdated(productId);
    }
    _precacheVisibleGallery(productId, normalizedGallery);
  }

  Future<void> _fetchGallerySilentForList(
    String productId,
    int index,
    String categoryKey,
  ) async {
    try {
      // Проверяем кэш
      if (_galleryCache.containsKey(productId)) {
        _updateProductGalleryFromCache(
          productId,
          categoryKey,
          _galleryCache[productId]!,
          notify: true,
        );
        return;
      }

      final imgRes = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.product.images.getList?product_id=$productId&access_token=$_apiToken',
        ),
      );
      if (imgRes.statusCode == 200) {
        final decoded = json.decode(imgRes.body);
        final imgData = _normalizeImageList(decoded);
        List<String> gallery = [];
        for (final img in imgData) {
          if (gallery.length >= 5) break;
          String url = img['url_thumb'] ?? "";
          if (url.isNotEmpty) {
            url = url.replaceAll(RegExp(r'\.\d+x\d+\.'), '.0x400.');
          } else {
            String sub1 = productId.length >= 2
                ? productId.substring(productId.length - 2)
                : productId.padLeft(2, '0');
            String sub2 = productId.length > 2
                ? productId.substring(0, productId.length - 2).padLeft(2, '0')
                : "00";
            url =
                "https://hozyain-barin.ru/wa-data/public/shop/products/$sub1/$sub2/$productId/images/${img['id']}/${img['id']}.0x400.jpg";
          }
          if (url.isNotEmpty) {
            gallery.add(url);
          }
        }
        if (gallery.isNotEmpty) {
          _clearGalleryNoImages(productId);
          // Сохраняем в кэш
          _putGalleryCache(productId, gallery);
          // Используем общий метод обновления
          _updateProductGalleryFromCache(
            productId,
            categoryKey,
            gallery,
            notify: true,
          );
        } else {
          _markGalleryNoImages(productId);
        }
      }
    } catch (e, st) {
      debugPrint("Gallery silent fetch error for $productId: $e");
      if (kDebugMode) debugPrint("$st");
    } finally {
      _markGalleryRequestComplete(categoryKey, productId);
    }
  }

  List<dynamic> _buildDiscountedItems(
    List<dynamic> source,
    String type, {
    int limit = 12,
  }) {
    final List<dynamic> result = [];
    for (final item in source) {
      if (item is! Map) continue;
      if (item['type'] != type) {
        item['type'] = type;
      }
      result.add(item);
      if (result.length >= limit) break;
    }
    return result;
  }

  Future<void> _fetchDiscountedProducts() async {
    try {
      _nativeCustomCategoryIdByKey["discount_men"] = "156";
      _nativeCustomCategoryIdByKey["discount_women"] = "157";

      await Future.wait([
        _fetchNativeCategory(
          key: "discount_men",
          categoryId: "156",
          reset: true,
        ),
        _fetchNativeCategory(
          key: "discount_women",
          categoryId: "157",
          reset: true,
        ),
      ]);

      final menItems = _buildDiscountedItems(
        _getNativeListByKey("discount_men"),
        "men",
      );
      final womenItems = _buildDiscountedItems(
        _getNativeListByKey("discount_women"),
        "women",
      );
      final combined = <dynamic>[...menItems, ...womenItems];
      if (combined.isEmpty) {
        _setMockDiscountedProducts();
        return;
      }
      setState(() {
        _discountedProducts = combined;
      });
    } catch (e, st) {
      debugPrint("Discount products error: $e");
      if (kDebugMode) debugPrint("$st");
      _setMockDiscountedProducts();
    }
  }

  // ignore: unused_element
  Future<void> _fetchDiscountedProductsLegacy() async {
    try {
      final results = await Future.wait<_SimpleHttpResponse>([
        _httpGet(
          Uri.parse(
            'https://hozyain-barin.ru/api.php/shop.product.search?access_token=$_apiToken&hash=category/156&limit=12&status=1&in_stock=1',
          ),
        ).catchError((e, st) {
          debugPrint("Discount search error (men): $e");
          if (kDebugMode) debugPrint("$st");
          return _SimpleHttpResponse.fromString("[]", 500);
        }),
        _httpGet(
          Uri.parse(
            'https://hozyain-barin.ru/api.php/shop.product.search?access_token=$_apiToken&hash=category/157&limit=12&status=1&in_stock=1',
          ),
        ).catchError((e, st) {
          debugPrint("Discount search error (women): $e");
          if (kDebugMode) debugPrint("$st");
          return _SimpleHttpResponse.fromString("[]", 500);
        }),
      ]);

      List<dynamic> allFetchedProducts = [];

      for (int i = 0; i < results.length; i++) {
        final response = results[i];
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          var data = (decoded is Map && decoded.containsKey('data'))
              ? decoded['data']
              : decoded;
          List<dynamic> products = [];
          if (data is List) {
            products = data;
          } else if (data is Map && data.containsKey('products')) {
            products = data['products'];
          } else if (data is Map) {
            products = data.values.toList();
          }

          String type = (i == 0) ? "men" : "women";
          for (var p in products) {
            if (p is Map) {
              if (!_isVisibleProductForIsolate(p)) continue;
              p['type'] = type;
              allFetchedProducts.add(p);
            }
          }
        }
      }

      if (allFetchedProducts.isEmpty) {
        _setMockDiscountedProducts();
        return;
      }

      // Для каждого товара запрашиваем список всех его изображений параллельно
      final List<dynamic> realProducts = await Future.wait(
        allFetchedProducts
            .map((p) async {
              final double price =
                  double.tryParse(p['price']?.toString() ?? "0") ?? 0;
              final double comparePrice =
                  double.tryParse(p['compare_price']?.toString() ?? "0") ?? 0;

              String? discountText;
              String? benefitText;
              String? oldPriceText;
              if (comparePrice > price && comparePrice > 0) {
                final int benefit = (comparePrice - price).round();
                final int discountPercent =
                    (((comparePrice - price) / comparePrice) * 100).round();
                if (discountPercent > 0) {
                  discountText = "- $discountPercent%";
                }
                if (benefit > 0) {
                  benefitText = "ВЫГОДА ${_formatPrice(benefit.toDouble())} ₽";
                }
                oldPriceText = "${_formatPrice(comparePrice)} ₽";
              }

              List<String> images = [];
              try {
                // Запрашиваем дополнительные фото
                final imgRes = await _httpGet(
                  Uri.parse(
                    'https://hozyain-barin.ru/api.php/shop.product.images.getList?product_id=${p['id']}&access_token=$_apiToken',
                  ),
                );
                if (imgRes.statusCode == 200) {
                  final List<dynamic> imgData = json.decode(imgRes.body);
                  for (var img in imgData) {
                    if (images.length >= 5) break;
                    // Формируем URL из thumb или собираем вручную по вашей логике
                    String url = img['url_thumb'] ?? "";
                    if (url.isNotEmpty) {
                      url = url.replaceAll(RegExp(r'\.\d+x\d+\.'), '.0x400.');
                    } else {
                      String pId = p['id'].toString();
                      String sub1 = pId.length >= 2
                          ? pId.substring(pId.length - 2)
                          : pId.padLeft(2, '0');
                      String sub2 = pId.length > 2
                          ? pId.substring(0, pId.length - 2).padLeft(2, '0')
                          : "00";
                      url =
                          "https://hozyain-barin.ru/wa-data/public/shop/products/$sub1/$sub2/$pId/images/${img['id']}/${img['id']}.0x400.jpg";
                    }
                    images.add(url);
                  }
                }
              } catch (e, st) {
                debugPrint("Discounted images fetch error for ${p['id']}: $e");
                if (kDebugMode) debugPrint("$st");
              }

              // Если доп. фото не нашлось, берем основное
              if (images.isEmpty) {
                String mainImg = p['image_url']?.toString() ?? "";
                if (mainImg.isNotEmpty) {
                  images.add(
                    mainImg.replaceAll(RegExp(r'\.\d+x\d+\.'), '.0x400.'),
                  );
                }
              }

              final categoryIds = _extractCategoryIdsForIsolate(p);
              final bool isNew = categoryIds.any(_newCategoryIds.contains);
              return {
                "id": p['id'].toString(),
                "name": p['name']?.toString() ?? "",
                "price": "${_formatPrice(price)} ₽",
                "raw_price": price,
                "raw_compare_price": comparePrice,
                if (oldPriceText != null) "old_price": oldPriceText,
                if (discountText != null) "discount": discountText,
                if (benefitText != null) "benefit": benefitText,
                "images": images,
                "type": p['type'],
                "link": "/product/${p['url']}/",
                "category_ids": categoryIds,
                if (isNew) "is_new": true,
              };
            })
            .map(
              (f) => f.catchError((e, st) {
                debugPrint("Discount product build error: $e");
                if (kDebugMode) debugPrint("$st");
                return <String, dynamic>{};
              }),
            ),
      );
      final List<dynamic> filteredDiscounted = realProducts
          .where((p) => p.isNotEmpty)
          .toList();
      if (_hasDiscountConfig) {
        _applyDiscountConfigToProducts(filteredDiscounted);
      }

      setState(() {
        _discountedProducts = filteredDiscounted;
      });

      // Ограниченное предкэширование первых карточек
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          const int maxProducts = 8;
          int precached = 0;
          for (final product in filteredDiscounted) {
            if (precached >= maxProducts) break;
            if (product is! Map) continue;
            final List<String> images = List<String>.from(
              product['images'] ?? [],
            );
            if (images.isEmpty) continue;
            final String imgUrl = images.first;
            if (imgUrl.isEmpty) continue;
            precacheImage(CachedNetworkImageProvider(imgUrl), context);
            precached++;
          }
        });
      }
    } catch (e) {
      _setMockDiscountedProducts();
    }
  }

  String _formatPrice(double price) {
    return price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  void _setMockDiscountedProducts() {
    setState(() {
      _discountedProducts = [
        {
          "id": "1",
          "name": "Мужской кожаный кошелек арт. KK089 BROWN",
          "price": "2 730 ₽",
          "old_price": "3 900 ₽",
          "discount": "- 30%",
          "benefit": "ВЫГОДА 1 170 ₽",
          "image":
              "https://hozyain-barin.ru/wa-data/public/shop/products/89/00/89/images/456/456.970.jpg",
          "type": "men",
          "link": "/product/muzhskoy-kozhanyy-koshelek-art-kk089-brown/",
        },
        {
          "id": "2",
          "name": "Мужской кожаный кошелек арт. KK094 BROWN",
          "price": "1 700 ₽",
          "old_price": "3 400 ₽",
          "discount": "- 50%",
          "benefit": "ВЫГОДА 1 700 ₽",
          "image":
              "https://hozyain-barin.ru/wa-data/public/shop/products/94/00/94/images/460/460.970.jpg",
          "type": "men",
          "link": "/product/muzhskoy-kozhanyy-koshelek-art-kk094-brown/",
        },
        {
          "id": "3",
          "name": "Женская кожаная сумка арт. SK001 RED",
          "price": "4 500 ₽",
          "old_price": "9 000 ₽",
          "discount": "- 50%",
          "benefit": "ВЫГОДА 4 500 ₽",
          "image":
              "https://hozyain-barin.ru/wa-data/public/shop/products/01/00/01/images/500/500.970.jpg",
          "type": "women",
          "link": "/product/zhenskaya-kozhanaya-sumka-art-sk001-red/",
        },
      ];
    });
  }

  double _parseDoubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    }
    return 0.0;
  }

  double _parsePriceValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value
          .replaceAll(RegExp(r'[^0-9.,]'), '')
          .replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _fetchSpecialDiscountProductIds() async {
    if (_isLoadingSpecialDiscountIds || _specialCategoryDiscounts.isEmpty) {
      return;
    }
    _isLoadingSpecialDiscountIds = true;
    try {
      final Map<String, double> nextMap = {};
      const int limit = 200;
      for (final entry in _specialCategoryDiscounts.entries) {
        final categoryId = entry.key;
        final discount = entry.value;
        if (discount <= 0) continue;
        int offset = 0;
        int guard = 0;
        while (guard < 20) {
          final queryParts = <String>[
            'access_token=${Uri.encodeQueryComponent(_apiToken)}',
            'limit=$limit',
            'offset=$offset',
            'hash=${Uri.encodeQueryComponent('category/$categoryId')}',
            'status=1',
            'in_stock=1',
          ];
          final url =
              'https://hozyain-barin.ru/api.php/shop.product.search?${queryParts.join('&')}';
          final response = await _httpGet(Uri.parse(url));
          if (response.statusCode != 200) break;
          final decoded = json.decode(response.body);
          final products = _extractProductsFromSearchResponse(decoded);
          if (products.isEmpty) break;
          for (final p in products) {
            if (p is! Map) continue;
            final id = p['id']?.toString() ?? "";
            if (id.isEmpty) continue;
            final existing = nextMap[id];
            if (existing == null) {
              nextMap[id] = discount;
            } else {
              if (_allowStackingDiscount) {
                nextMap[id] = existing + discount;
              } else if (_preferHigherDiscount) {
                nextMap[id] = existing > discount ? existing : discount;
              } else {
                nextMap[id] = discount;
              }
            }
          }
          if (products.length < limit) break;
          offset += products.length;
          guard++;
        }
      }
      _specialDiscountByProductId
        ..clear()
        ..addAll(nextMap);
    } catch (e, st) {
      debugPrint("Special discount ids error: $e");
      if (kDebugMode) debugPrint("$st");
    } finally {
      _isLoadingSpecialDiscountIds = false;
    }
  }

  Set<String> _extractProductCategoryIds(Map<dynamic, dynamic> product) {
    final ids = <String>{};
    void addId(dynamic value) {
      if (value == null) return;
      final s = value.toString();
      if (s.isNotEmpty) ids.add(s);
    }

    addId(product['source_category_id']);
    addId(product['category_id']);
    addId(product['categoryId']);
    addId(product['category']);
    addId(product['cat_id']);

    final dynamic categories =
        product['category_ids'] ??
        product['categoryIds'] ??
        product['categories'] ??
        product['category_list'];

    if (categories is List) {
      for (final item in categories) {
        if (item is Map) {
          addId(item['id']);
          addId(item['category_id']);
        } else {
          addId(item);
        }
      }
    } else if (categories is Map) {
      for (final entry in categories.entries) {
        addId(entry.key);
        final value = entry.value;
        if (value is Map) {
          addId(value['id']);
          addId(value['category_id']);
        } else if (value is List) {
          for (final item in value) {
            if (item is Map) {
              addId(item['id']);
              addId(item['category_id']);
            } else {
              addId(item);
            }
          }
        } else {
          addId(value);
        }
      }
    }
    return ids;
  }

  double _computeConfigDiscount(Set<String> categoryIds) {
    final specials = <double>[];
    for (final id in categoryIds) {
      final discount = _specialCategoryDiscounts[id];
      if (discount != null && discount > 0) specials.add(discount);
    }
    final double specialMax = specials.isEmpty
        ? 0.0
        : specials.reduce((a, b) => a > b ? a : b);
    final double specialSum = specials.fold(0.0, (sum, d) => sum + d);

    if (_allowStackingDiscount) {
      return _globalDiscountPercent + specialSum;
    }
    if (_preferHigherDiscount) {
      return (_globalDiscountPercent > specialMax)
          ? _globalDiscountPercent
          : specialMax;
    }
    return specialMax > 0 ? specialMax : _globalDiscountPercent;
  }

  void _clearDiscountFromProduct(
    Map<dynamic, dynamic> product,
    double basePrice,
  ) {
    product['raw_price'] = basePrice;
    product['raw_compare_price'] = 0.0;
    product['price'] = "${_formatPrice(basePrice)} ₽";
    product.remove('old_price');
    product.remove('discount');
    product.remove('benefit');
  }

  void _applyDiscountConfigToProduct(Map<dynamic, dynamic> product) {
    if (!_hasDiscountConfig) return;
    final String productId = product['id']?.toString() ?? "";
    final categoryIds = _extractProductCategoryIds(product);
    if (categoryIds.isEmpty) return;
    if (categoryIds.any(_excludedDiscountCategories.contains)) {
      final rawCompare = _parsePriceValue(product['raw_compare_price']);
      final rawPrice = _parsePriceValue(product['raw_price']);
      final base = rawCompare > 0
          ? rawCompare
          : (rawPrice > 0 ? rawPrice : _parsePriceValue(product['price']));
      if (base > 0) {
        _clearDiscountFromProduct(product, base);
      }
      return;
    }

    final rawCompare = _parsePriceValue(product['raw_compare_price']);
    final rawPrice = _parsePriceValue(product['raw_price']);
    double basePrice = rawCompare > 0 ? rawCompare : rawPrice;
    if (basePrice <= 0) {
      basePrice = _parsePriceValue(product['price']);
    }
    if (basePrice <= 0) return;

    double existingDiscount = 0.0;
    if (rawCompare > 0 && rawCompare > rawPrice && rawPrice > 0) {
      existingDiscount = ((rawCompare - rawPrice) / rawCompare) * 100.0;
    }
    double configDiscount = _computeConfigDiscount(categoryIds);
    final bool hasSpecialCategory = categoryIds.any(
      _specialCategoryDiscounts.containsKey,
    );
    final double? specialByProduct = _specialDiscountByProductId[productId];
    if (!hasSpecialCategory &&
        specialByProduct != null &&
        specialByProduct > 0) {
      if (_allowStackingDiscount) {
        configDiscount += specialByProduct;
      } else if (_preferHigherDiscount) {
        configDiscount = configDiscount > specialByProduct
            ? configDiscount
            : specialByProduct;
      } else {
        configDiscount = specialByProduct;
      }
    }

    double finalDiscount;
    if (_allowStackingDiscount) {
      finalDiscount = existingDiscount + configDiscount;
    } else if (_preferHigherDiscount) {
      finalDiscount = existingDiscount > configDiscount
          ? existingDiscount
          : configDiscount;
    } else {
      finalDiscount = configDiscount > 0 ? configDiscount : existingDiscount;
    }
    finalDiscount = finalDiscount.clamp(0.0, 90.0);
    if (finalDiscount <= 0) {
      _clearDiscountFromProduct(product, basePrice);
      return;
    }

    final double newPrice = (basePrice * (1 - finalDiscount / 100))
        .roundToDouble();
    if (newPrice <= 0) return;

    product['raw_compare_price'] = basePrice;
    product['raw_price'] = newPrice;
    product['price'] = "${_formatPrice(newPrice)} ₽";
    product['old_price'] = "${_formatPrice(basePrice)} ₽";
    final int percent = (((basePrice - newPrice) / basePrice) * 100).round();
    if (percent > 0) {
      product['discount'] = "- $percent%";
    } else {
      product.remove('discount');
    }
    final int benefit = (basePrice - newPrice).round();
    if (benefit > 0) {
      product['benefit'] = "ВЫГОДА ${_formatPrice(benefit.toDouble())} ₽";
    } else {
      product.remove('benefit');
    }
  }

  void _applyDiscountConfigToProducts(List<dynamic> products) {
    for (final item in products) {
      if (item is! Map) continue;
      _applyDiscountConfigToProduct(item);
    }
  }

  void _applyDiscountConfigToAllLoadedProducts() {
    for (final list in _nativeLists.values) {
      _applyDiscountConfigToProducts(list);
    }
    for (final list in _originalNativeLists.values) {
      _applyDiscountConfigToProducts(list);
    }
    _applyDiscountConfigToProducts(_discountedProducts);
    if (mounted) setState(() {});
  }

  Future<void> _fetchAboutData() async {
    try {
      final response = await _httpGet(
        Uri.parse('https://hozyain-barin.ru/native/about.json'),
      );
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
        dynamic data;
        if (decoded is List && decoded.isNotEmpty) {
          data = decoded[0];
        } else if (decoded is Map) {
          data = decoded;
        }

        if (data != null) {
          setState(() {
            _aboutImageUrl = data['image'] ?? _aboutImageUrl;
            _aboutTitle = data['title'] ?? _aboutTitle;
            _aboutDescription = data['description'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("About data error: $e");
    }
  }

  Future<void> _fetchPromoBanners() async {
    try {
      final response = await _httpGet(
        Uri.parse('https://hozyain-barin.ru/native/banners.json'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _promoBanners = data;
        });
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            const int maxPrecache = 2;
            int precached = 0;
            for (final item in data) {
              if (item is! Map) continue;
              final url = item['image']?.toString() ?? "";
              if (url.isEmpty) continue;
              precacheImage(CachedNetworkImageProvider(url), context);
              precached++;
              if (precached >= maxPrecache) break;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Promo banners error: $e");
    }
  }

  Future<void> _fetchDiscountConfig() async {
    const urls = [
      'https://hozyain-barin.ru/native/discounts_config.json',
      'http://hozyain-barin.ru/public_html/native/discounts_config.json',
    ];
    Map<dynamic, dynamic>? decoded;
    for (final url in urls) {
      try {
        final response = await _httpGet(Uri.parse(url));
        if (response.statusCode != 200) continue;
        final body = utf8.decode(response.bodyBytes);
        final data = json.decode(body);
        if (data is Map) {
          decoded = data;
          break;
        }
      } catch (e) {
        debugPrint("Discount config fetch error: $e");
      }
    }
    if (decoded == null) return;

    final globalDiscount = _parseDoubleValue(decoded['global_site_discount']);
    final excluded = <String>{};
    final rawExcluded = decoded['excluded_categories'];
    if (rawExcluded is List) {
      for (final item in rawExcluded) {
        final id = item?.toString();
        if (id != null && id.isNotEmpty) excluded.add(id);
      }
    }
    final special = <String, double>{};
    final rawOffers = decoded['special_offers'];
    if (rawOffers is List) {
      for (final offer in rawOffers) {
        if (offer is! Map) continue;
        final id = offer['category_id']?.toString();
        final discount = _parseDoubleValue(offer['discount']);
        if (id != null && id.isNotEmpty && discount > 0) {
          special[id] = discount;
        }
      }
    }
    final rawSettings = decoded['settings'];
    final preferHigher =
        (rawSettings is Map && rawSettings['prefer_higher_discount'] == false)
        ? false
        : true;
    final allowStacking =
        (rawSettings is Map && rawSettings['allow_stacking'] == true);

    if (!mounted) return;
    setState(() {
      _globalDiscountPercent = globalDiscount;
      _excludedDiscountCategories
        ..clear()
        ..addAll(excluded);
      _specialCategoryDiscounts
        ..clear()
        ..addAll(special);
      _preferHigherDiscount = preferHigher;
      _allowStackingDiscount = allowStacking;
      _hasDiscountConfig = true;
    });
    await _fetchSpecialDiscountProductIds();
    _applyDiscountConfigToAllLoadedProducts();
  }

  void _navigateToApiCategory(dynamic cat) {
    if (_isNativeCategoryPage &&
        (_isUserScrolling || _scrollingNotifier.value)) {
      return;
    }
    final prevNative = _nativeCategory;
    String apiTitle = (cat['name'] ?? "").toString();
    String urlPath = _buildCategoryUrl(cat);
    final catId = cat['id']?.toString();
    final nativeKey = _resolveNativeCategory(catId, urlPath);
    bool isNative = nativeKey != null;

    if (!isNative) {
      _launchUrl('https://hozyain-barin.ru$urlPath');
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    _rememberCategoryForBackNavigation(nextKey: nativeKey);
    setState(() {
      _pageTitle = apiTitle;
      _isNativeCategoryPage = true;
      _nativeCategory = nativeKey;
      _resetVisibleRangeForCategory(_nativeCategory);
    });

    if (prevNative != nativeKey) {
      _animatedProductIds.clear();
      _resetNativeCategoryScroll();
    }
    _fetchActiveNativeCategoryIfNeeded();
    _scheduleVisibleGalleryLoad(_nativeCategory);

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _navigateToSimple(String title, String path) {
    if (_isNativeCategoryPage &&
        (_isUserScrolling || _scrollingNotifier.value)) {
      return;
    }
    final prevNative = _nativeCategory;
    final nativeKey = _resolveNativeCategory(null, path);
    bool isNative = nativeKey != null;

    if (!isNative) {
      _launchUrl('https://hozyain-barin.ru$path');
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    if (nativeKey == "wishlist") {
      _syncWishlistList();
    }
    if (nativeKey == "compare") {
      _syncCompareList();
      _ensureCompareDetails();
    }
    if (nativeKey == "cart") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _nativeCategory == "cart") {
          _updateCartFloatingButtonVisibility();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _nativeCategory == "cart") {
            _updateCartFloatingButtonVisibility();
          }
        });
      });
    }

    _rememberCategoryForBackNavigation(nextKey: nativeKey);
    setState(() {
      _pageTitle = title;
      _isNativeCategoryPage = true;
      _nativeCategory = nativeKey;
      _resetVisibleRangeForCategory(_nativeCategory);
    });

    if (prevNative != nativeKey) {
      _animatedProductIds.clear();
      _resetNativeCategoryScroll();
    }
    if (nativeKey == "cart") {
      _resetNativeCategoryScroll();
    }
    _updateCartFloatingButtonVisibility();
    _fetchActiveNativeCategoryIfNeeded();
    _scheduleVisibleGalleryLoad(_nativeCategory);

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _openProductPage(dynamic product, {bool showStockSheetOnLoad = false}) {
    if (product is! Map) return;
    final String productId = product['id']?.toString() ?? "";
    if (productId.isNotEmpty) {
      _queueProductDetailsFetch(productId);
    }
    final detailPage = ProductDetailPage(
      product: Map<String, dynamic>.from(product),
      isNew: _isNewProduct(product),
      showStockSheetOnLoad: showStockSheetOnLoad,
      resolveFavoriteListenable: _getFavoriteNotifier,
      resolveCompareListenable: _getCompareNotifier,
      resolveGalleryListenable: _getGalleryNotifier,
      isFavoriteResolver: _isFavorite,
      isCompareResolver: _isCompared,
      onFavoriteTap: _toggleFavorite,
      onCompareTap: _toggleCompare,
      onAddToCart: () => _addToCart(product),
      cartListenable: _cartCountNotifier,
      isInCartResolver: (id) => (_cartQuantityByProductId[id] ?? 0) > 0,
      onShare: () => _shareProduct(product),
      onOpenProduct: _openProductPage,
      resolveImages: _resolveProductImages,
      fetchImagesById: _fetchProductImagesFull,
      fetchProductById: _fetchProductInfoById,
      resolveArticle: _resolveProductArticle,
      resolveStockCount: _resolveProductStockCount,
      availableFeatures: _availableFeatures,
      featureCodeById: _featureCodeById,
      featureValueTextById: _featureValueTextById,
      availableStocks: _availableStocks,
      resolveStockMap: (id) => _productStockById[id],
      fetchReviewsById: _fetchProductReviewsById,
      fetchCustomerById: _fetchCustomerInfoById,
      submitReview: _submitProductReview,
      bottomBar: _buildBottomBar(showTopBorder: false),
    );

    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute<void>(builder: (_) => detailPage)
          : PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 380),
              reverseTransitionDuration: const Duration(milliseconds: 380),
              pageBuilder: (_, __, ___) => detailPage,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    );
                    final offsetTween = Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    );
                    return SlideTransition(
                      position: curved.drive(offsetTween),
                      child: child,
                    );
                  },
            ),
    );
  }

  List<String> _resolveProductImages(Map product) {
    final productId = product['id']?.toString() ?? "";
    final cached = _productFullGalleryById[productId];
    if (cached != null && cached.isNotEmpty) return List<String>.from(cached);
    final List<String> images = [];
    final rawImages = product['images'];
    if (rawImages is List) {
      for (final img in rawImages) {
        final value = img?.toString() ?? "";
        if (value.isNotEmpty) images.add(value);
      }
    }
    if (images.isEmpty) {
      final gallery = product['gallery'];
      if (gallery is List) {
        for (final img in gallery) {
          final value = img?.toString() ?? "";
          if (value.isNotEmpty) images.add(value);
        }
      }
    }
    if (images.isEmpty) {
      final fallback = product['image'] ?? product['image_url'];
      final value = fallback?.toString() ?? "";
      if (value.isNotEmpty) images.add(value);
    }
    return images;
  }

  String _resolveProductArticle(Map product) {
    final candidates = [
      product['sku'],
      product['article'],
      product['articul'],
      product['code'],
      product['id'],
    ];
    for (final value in candidates) {
      final text = value?.toString() ?? "";
      if (text.isNotEmpty) return text;
    }
    return "";
  }

  int _resolveProductStockCount(Map product) {
    final productId = product['id']?.toString() ?? "";
    if (productId.isNotEmpty) {
      final stocks = _productStockById[productId];
      if (stocks != null && stocks.isNotEmpty) {
        int total = 0;
        for (final count in stocks.values) {
          total += count;
        }
        return total;
      }
    }
    final raw = product['count']?.toString() ?? "";
    return int.tryParse(raw) ?? 0;
  }

  void _shareProduct(Map product) {
    final name = product['name']?.toString().trim() ?? "";
    final link = product['link']?.toString().trim() ?? "";
    final url = link.isNotEmpty ? "https://hozyain-barin.ru$link" : "";
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (url.isNotEmpty) parts.add(url);
    if (parts.isEmpty) return;
    SharePlus.instance.share(
      ShareParams(
        text: parts.join("\n"),
        subject: name.isNotEmpty ? name : "Товар",
      ),
    );
  }

  void _goHome() {
    if (!mounted) return;

    setState(() {
      _isNativeCategoryPage = false;
      _pageTitle = "";
      _catalogBackSwipeScrollLocked = false;
      _nativeCategoryBackStack.clear();
    });
    _resetCatalogBackSwipeTracking();
    _updateCartFloatingButtonVisibility();
  }

  void _rememberCategoryForBackNavigation({required String nextKey}) {
    if (!_isNativeCategoryPage) return;
    if (_nativeCategory == nextKey) return;
    final entry = (
      key: _nativeCategory,
      title: _pageTitle,
      customCategoryId: _nativeCustomCategoryIdByKey[_nativeCategory],
    );
    if (_nativeCategoryBackStack.isNotEmpty) {
      final last = _nativeCategoryBackStack.last;
      if (last.key == entry.key &&
          last.customCategoryId == entry.customCategoryId) {
        return;
      }
    }
    _nativeCategoryBackStack.add(entry);
    if (_nativeCategoryBackStack.length > _maxNativeCategoryHistoryDepth) {
      _nativeCategoryBackStack.removeAt(0);
    }
  }

  void _goBackFromCategory() {
    if (!_isNativeCategoryPage) return;
    if (_nativeCategoryBackStack.isEmpty) {
      _goHome();
      return;
    }

    final previous = _nativeCategoryBackStack.removeLast();
    final prevNative = _nativeCategory;
    final customCategoryId = previous.customCategoryId;
    if (customCategoryId != null && customCategoryId.isNotEmpty) {
      _nativeCustomCategoryIdByKey[previous.key] = customCategoryId;
    }

    if (previous.key == "wishlist") {
      _syncWishlistList();
    }
    if (previous.key == "compare") {
      _syncCompareList();
      _ensureCompareDetails();
    }
    if (previous.key == "cart") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _nativeCategory == "cart") {
          _updateCartFloatingButtonVisibility();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _nativeCategory == "cart") {
            _updateCartFloatingButtonVisibility();
          }
        });
      });
    }

    setState(() {
      _pageTitle = previous.title;
      _isNativeCategoryPage = true;
      _nativeCategory = previous.key;
      _catalogBackSwipeScrollLocked = false;
      _resetVisibleRangeForCategory(_nativeCategory);
    });

    if (prevNative != previous.key) {
      _animatedProductIds.clear();
      _resetNativeCategoryScroll();
    }
    if (previous.key == "cart") {
      _resetNativeCategoryScroll();
    }
    _updateCartFloatingButtonVisibility();
    _fetchActiveNativeCategoryIfNeeded();
    _scheduleVisibleGalleryLoad(_nativeCategory);
    _resetCatalogBackSwipeTracking();
  }

  bool get _canHandleCatalogEdgeBackSwipe {
    return Platform.isIOS && _isNativeCategoryPage;
  }

  void _setCatalogBackSwipeScrollLocked(bool locked) {
    if (_catalogBackSwipeScrollLocked == locked) return;
    if (!mounted) {
      _catalogBackSwipeScrollLocked = locked;
      return;
    }
    setState(() {
      _catalogBackSwipeScrollLocked = locked;
    });
  }

  void _resetCatalogBackSwipeTracking({bool keepOffset = false}) {
    _catalogBackSwipeController.stop();
    _catalogBackSwipeAnimation = null;
    _catalogBackSwipePointer = null;
    _catalogBackSwipeStart = null;
    _catalogBackSwipeIsSettling = false;
    _catalogBackSwipeCompletesToHome = false;
    if (!keepOffset) {
      _catalogBackSwipeOffsetNotifier.value = 0;
    }
  }

  void _animateCatalogBackSwipeTo({
    required double targetOffset,
    required bool completeToHome,
  }) {
    final begin = _catalogBackSwipeOffsetNotifier.value;
    final end = targetOffset.clamp(0.0, double.infinity).toDouble();
    if ((begin - end).abs() < 0.5) {
      _catalogBackSwipeOffsetNotifier.value = end;
      if (completeToHome) {
        _goBackFromCategory();
      } else {
        _setCatalogBackSwipeScrollLocked(false);
        _resetCatalogBackSwipeTracking(keepOffset: true);
      }
      return;
    }
    _catalogBackSwipeIsSettling = true;
    _catalogBackSwipeCompletesToHome = completeToHome;
    _catalogBackSwipeAnimation = Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(
        parent: _catalogBackSwipeController,
        curve: Curves.easeOutCubic,
      ),
    );
    _catalogBackSwipeController
      ..duration = _catalogBackSwipeSettleDuration
      ..reset()
      ..forward();
  }

  void _handleCatalogBackSwipePointerDown(PointerDownEvent event) {
    if (!_canHandleCatalogEdgeBackSwipe) return;
    if (_catalogBackSwipePointer != null) return;
    if (event.position.dx > _catalogBackSwipeEdgeWidth) return;
    if (_catalogBackSwipeIsSettling) {
      _catalogBackSwipeController.stop();
      _catalogBackSwipeIsSettling = false;
      _catalogBackSwipeCompletesToHome = false;
      _catalogBackSwipeAnimation = null;
    }
    _catalogBackSwipePointer = event.pointer;
    _catalogBackSwipeStart =
        event.position - Offset(_catalogBackSwipeOffsetNotifier.value, 0);
    _setCatalogBackSwipeScrollLocked(true);
  }

  void _handleCatalogBackSwipePointerMove(PointerMoveEvent event) {
    if (!_canHandleCatalogEdgeBackSwipe) {
      _setCatalogBackSwipeScrollLocked(false);
      _resetCatalogBackSwipeTracking();
      return;
    }
    if (_catalogBackSwipePointer != event.pointer) {
      return;
    }
    final start = _catalogBackSwipeStart;
    if (start == null) return;
    final width = MediaQuery.of(context).size.width;
    final delta = event.position - start;
    final dx = delta.dx;
    final dy = delta.dy.abs();
    if (dy > _catalogBackSwipeMaxVerticalDrift) {
      _catalogBackSwipePointer = null;
      _catalogBackSwipeStart = null;
      _animateCatalogBackSwipeTo(targetOffset: 0, completeToHome: false);
      return;
    }
    if (dx <= 0) return;
    final clampedDx = dx.clamp(0.0, width * 0.98).toDouble();
    if ((_catalogBackSwipeOffsetNotifier.value - clampedDx).abs() >= 0.5) {
      _catalogBackSwipeOffsetNotifier.value = clampedDx;
    }
  }

  void _handleCatalogBackSwipePointerUp(PointerUpEvent event) {
    if (_catalogBackSwipePointer != event.pointer) return;
    _catalogBackSwipePointer = null;
    _catalogBackSwipeStart = null;
    final width = MediaQuery.of(context).size.width;
    final completeThreshold = math.max(
      _catalogBackSwipeMinDistance,
      width * _catalogBackSwipeCompleteRatio,
    );
    final shouldComplete =
        _catalogBackSwipeOffsetNotifier.value >= completeThreshold;
    final targetOffset = shouldComplete ? width : 0.0;
    _animateCatalogBackSwipeTo(
      targetOffset: targetOffset,
      completeToHome: shouldComplete,
    );
  }

  void _handleCatalogBackSwipePointerCancel(PointerCancelEvent event) {
    if (_catalogBackSwipePointer != event.pointer) return;
    _catalogBackSwipePointer = null;
    _catalogBackSwipeStart = null;
    _animateCatalogBackSwipeTo(targetOffset: 0, completeToHome: false);
  }

  Widget _buildCategoryHeaderPreview(String title) {
    return Row(
      children: [
        const SizedBox(
          width: 48,
          child: Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildHomeScrollPreview() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: RepaintBoundary(child: _buildMainBannerSlider()),
        ),
        SliverToBoxAdapter(
          child: RepaintBoundary(child: _buildCategoryScroll()),
        ),
        SliverToBoxAdapter(
          child: RepaintBoundary(child: _buildPromoBannerScroll()),
        ),
        SliverToBoxAdapter(
          child: RepaintBoundary(child: _buildDiscountedProductsSection()),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(child: _buildAboutSection()),
      ],
    );
  }

  Widget _buildNativeCategoryPreviewSliver(
    String previewKey,
    List<dynamic> items,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 8.0;
    const crossAxisSpacing = 3.0;
    const mainAxisSpacing = 5.0;
    final itemWidth = (screenWidth - horizontalPadding - crossAxisSpacing) / 2;
    final imageHeight = itemWidth * 4 / 3;
    const contentHeight = 146.0;
    final itemHeight = imageHeight + contentHeight;
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      mainAxisExtent: itemHeight,
    );
    if (items.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            "Ничего не найдено",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      sliver: SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = items[index];
          String productId = "";
          if (product is Map) {
            productId = product['id']?.toString() ?? "";
          }
          final itemKey = productId.isNotEmpty
              ? "preview_${previewKey}_$productId"
              : "preview_${previewKey}_idx_$index";
          return RepaintBoundary(
            key: ValueKey(itemKey),
            child: _simpleProductCard(product),
          );
        }, childCount: items.length),
      ),
    );
  }

  Widget _buildCategoryScrollPreview(String previewKey) {
    final items = _getNativeListByKey(previewKey);
    Widget previewSliver;
    if (previewKey == "wishlist") {
      previewSliver = _buildWishlistGrid(items);
    } else if (previewKey == "cart") {
      previewSliver = _buildCartPage(_getCartItems());
    } else if (previewKey == "compare") {
      previewSliver = _buildNativeCategoryPreviewSliver(previewKey, items);
    } else {
      previewSliver = _buildNativeCategoryPreviewSliver(previewKey, items);
    }

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        if (previewKey == "men")
          const SliverToBoxAdapter(child: SizedBox(height: 5)),
        if (previewKey == "men") _buildMenSubcategoriesSliver(),
        previewSliver,
        if (previewKey != "wishlist" &&
            previewKey != "compare" &&
            previewKey != "cart")
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }

  Widget _buildCatalogBackSwipeDestinationPreview() {
    final destination = _nativeCategoryBackStack.isNotEmpty
        ? _nativeCategoryBackStack.last
        : null;
    final bool showHomePreview = destination == null;
    final String previewKey = destination?.key ?? "";
    final String previewTitle = destination?.title ?? "";

    return IgnorePointer(
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: showHomePreview
                      ? _buildMainHeader()
                      : _buildCategoryHeaderPreview(previewTitle),
                ),
              ),
            ),
            Container(color: Colors.grey.shade200, height: 1),
            Expanded(
              child: showHomePreview
                  ? _buildHomeScrollPreview()
                  : _buildCategoryScrollPreview(previewKey),
            ),
            SafeArea(
              top: false,
              left: false,
              right: false,
              child: _buildBottomBar(showTopBorder: previewKey != "cart"),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveNativeCategory(String? catId, String? urlPath) {
    final path = urlPath ?? "";
    if (path.contains('wishlist=true')) return "wishlist";
    if (path.startsWith('/compare')) return "compare";
    if (path.startsWith('/cart')) return "cart";
    if (catId != null && catId.isNotEmpty) {
      if (catId == _menBagsCategoryId) return "men";
      if (catId == _beltBagsCategoryId) return "belt";
      if (catId == _shoulderBagsCategoryId) return "shoulder";
      if (catId == _tabletBagsCategoryId) return "tablet";
      if (catId == _businessBagsCategoryId) return "business";
      if (catId == _womenBagsCategoryId) return "women";
      if (catId == _travelBagsCategoryId) return "travel";
      if (catId == _backpacksCategoryId) return "backpacks";
      if (catId == _beltsCategoryId) return "belts";
      if (catId == _walletsCategoryId) return "wallets";
      if (catId == _accessoriesCategoryId) return "accessories";
      if (catId == "156") return "discount_men";
      if (catId == "157") return "discount_women";
    }
    if (path.contains('/muzhskie-sumki/')) return "men";
    if (path.contains('/poyasnye-sumki/')) return "belt";
    if (path.contains('/sumki-cherez-plecho/')) return "shoulder";
    if (path.contains('/sumki-planshet/')) return "tablet";
    if (path.contains('/delovye-sumki/')) return "business";
    if (path.contains('/zhenskie-sumki/')) return "women";
    if (path.contains('/dorozhnye-sumki/')) return "travel";
    if (path.contains('/ryukzaki/')) return "backpacks";
    if (path.contains('/remni/')) return "belts";
    if (path.contains('/koshelki/')) return "wallets";
    if (path.contains('/aksessuary/')) return "accessories";
    return null;
  }

  void _fetchActiveNativeCategoryIfNeeded() {
    if (_nativeCategory == "wishlist" ||
        _nativeCategory == "compare" ||
        _nativeCategory == "cart") {
      return;
    }
    final customId = _nativeCustomCategoryIdByKey[_nativeCategory];
    if (customId != null && customId.isNotEmpty) {
      if (_getActiveNativeList().isEmpty) {
        _fetchNativeCategory(key: _nativeCategory, categoryId: customId);
      }
      return;
    }
    switch (_nativeCategory) {
      case "belt":
        if (_getNativeListByKey("belt").isEmpty) _fetchBeltBags();
        break;
      case "shoulder":
        if (_getNativeListByKey("shoulder").isEmpty) _fetchShoulderBags();
        break;
      case "tablet":
        if (_getNativeListByKey("tablet").isEmpty) _fetchTabletBags();
        break;
      case "business":
        if (_getNativeListByKey("business").isEmpty) _fetchBusinessBags();
        break;
      case "women":
        if (_getNativeListByKey("women").isEmpty) _fetchWomenBags();
        break;
      case "travel":
        if (_getNativeListByKey("travel").isEmpty) _fetchTravelBags();
        break;
      case "backpacks":
        if (_getNativeListByKey("backpacks").isEmpty) _fetchBackpacks();
        break;
      case "belts":
        if (_getNativeListByKey("belts").isEmpty) _fetchBelts();
        break;
      case "wallets":
        if (_getNativeListByKey("wallets").isEmpty) _fetchWallets();
        break;
      case "accessories":
        if (_getNativeListByKey("accessories").isEmpty) _fetchAccessories();
        break;
      default:
        if (_getNativeListByKey("men").isEmpty) _fetchMenBags();
    }
  }

  List<dynamic> _getActiveNativeList() {
    return _getNativeListByKey(_nativeCategory);
  }

  List<dynamic> _getOriginalNativeList() {
    return _getOriginalNativeListByKey(_nativeCategory);
  }

  void _setActiveNativeList(List<dynamic> items) {
    _setNativeListByKey(_nativeCategory, items);
  }

  List<dynamic> _getNativeListByKey(String key) {
    return _nativeLists.putIfAbsent(key, () => []);
  }

  List<dynamic> _getOriginalNativeListByKey(String key) {
    return _originalNativeLists.putIfAbsent(key, () => []);
  }

  void _setNativeListByKey(String key, List<dynamic> items) {
    _nativeLists[key] = items;
  }

  void _setOriginalNativeListByKey(String key, List<dynamic> items) {
    _originalNativeLists[key] = items;
  }

  void _initDeepLinks() async {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _launchUrl(uri.toString());
    });
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await _httpGet(
        Uri.parse(
          'https://hozyain-barin.ru/api.php/shop.category.getTree?access_token=$_apiToken',
        ),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        var rawData = (decoded is Map && decoded.containsKey('data'))
            ? decoded['data']
            : decoded;

        List<dynamic> categoriesList = [];
        if (rawData is List) {
          categoriesList = rawData;
        } else if (rawData is Map) {
          categoriesList = rawData.values.toList();
        }

        final menCategoryId = _findCategoryIdBySlug(
          categoriesList,
          "muzhskie-sumki",
        );
        final beltCategoryId = _findCategoryIdBySlug(
          categoriesList,
          "poyasnye-sumki",
        );
        final shoulderCategoryId = _findCategoryIdBySlug(
          categoriesList,
          "sumki-cherez-plecho",
        );
        final tabletCategoryId = _findCategoryIdBySlug(
          categoriesList,
          "sumki-planshet",
        );
        final businessCategoryId = _findCategoryIdBySlug(
          categoriesList,
          "delovye-sumki",
        );
        final womenCategoryId = _findCategoryIdBySlug(
          categoriesList,
          "zhenskie-sumki",
        );
        final travelCategoryId = _findCategoryIdBySlug(
          categoriesList,
          "dorozhnye-sumki",
        );
        final backpacksCategoryId = _findCategoryIdBySlug(
          categoriesList,
          "ryukzaki",
        );
        final beltsCategoryId = _findCategoryIdBySlug(categoriesList, "remni");
        final walletsCategoryId = _findCategoryIdBySlug(
          categoriesList,
          "koshelki",
        );
        final accessoriesCategoryId = _findCategoryIdBySlug(
          categoriesList,
          "aksessuary",
        );
        setState(() {
          _allCategories = categoriesList;
          _apiCategories = categoriesList
              .where((cat) => cat['status'].toString() != "0")
              .toList();
          _isMenuLoading = false;
          if (menCategoryId != null && menCategoryId.isNotEmpty) {
            _menBagsCategoryId = menCategoryId;
          }
          if (beltCategoryId != null && beltCategoryId.isNotEmpty) {
            _beltBagsCategoryId = beltCategoryId;
          }
          if (shoulderCategoryId != null && shoulderCategoryId.isNotEmpty) {
            _shoulderBagsCategoryId = shoulderCategoryId;
          }
          if (tabletCategoryId != null && tabletCategoryId.isNotEmpty) {
            _tabletBagsCategoryId = tabletCategoryId;
          }
          if (businessCategoryId != null && businessCategoryId.isNotEmpty) {
            _businessBagsCategoryId = businessCategoryId;
          }
          if (womenCategoryId != null && womenCategoryId.isNotEmpty) {
            _womenBagsCategoryId = womenCategoryId;
          }
          if (travelCategoryId != null && travelCategoryId.isNotEmpty) {
            _travelBagsCategoryId = travelCategoryId;
          }
          if (backpacksCategoryId != null && backpacksCategoryId.isNotEmpty) {
            _backpacksCategoryId = backpacksCategoryId;
          }
          if (beltsCategoryId != null && beltsCategoryId.isNotEmpty) {
            _beltsCategoryId = beltsCategoryId;
          }
          if (walletsCategoryId != null && walletsCategoryId.isNotEmpty) {
            _walletsCategoryId = walletsCategoryId;
          }
          if (accessoriesCategoryId != null &&
              accessoriesCategoryId.isNotEmpty) {
            _accessoriesCategoryId = accessoriesCategoryId;
          }
        });

        if (menCategoryId != null && menCategoryId.isNotEmpty) {
          _fetchMenBags();
        }
      }
    } catch (e) {
      setState(() {
        _isMenuLoading = false;
      });
    }
  }

  List<dynamic> _extractProductsFromSearchResponse(dynamic decoded) {
    final data = (decoded is Map && decoded.containsKey('data'))
        ? decoded['data']
        : decoded;
    if (data is Map && data.containsKey('products')) {
      final rawProducts = data['products'];
      if (rawProducts is List) return rawProducts;
      if (rawProducts is Map) return rawProducts.values.toList();
    } else if (data is List) {
      return data;
    } else if (data is Map) {
      return data.values.toList();
    }
    return [];
  }

  Future<void> _fetchNewCategoryProductIds() async {
    if (_isLoadingNewProductIds) return;
    _isLoadingNewProductIds = true;
    try {
      final Set<String> nextIds = <String>{};
      const int limit = 200;
      for (final categoryId in _newCategoryIds) {
        int offset = 0;
        int guard = 0;
        while (guard < 20) {
          final queryParts = <String>[
            'access_token=${Uri.encodeQueryComponent(_apiToken)}',
            'limit=$limit',
            'offset=$offset',
            'hash=${Uri.encodeQueryComponent('category/$categoryId')}',
            'status=1',
            'in_stock=1',
          ];
          final url =
              'https://hozyain-barin.ru/api.php/shop.product.search?${queryParts.join('&')}';
          final response = await _httpGet(Uri.parse(url));
          if (response.statusCode != 200) break;
          final decoded = json.decode(response.body);
          final products = _extractProductsFromSearchResponse(decoded);
          if (products.isEmpty) break;
          for (final p in products) {
            if (p is! Map) continue;
            final id = p['id']?.toString() ?? "";
            if (id.isNotEmpty) nextIds.add(id);
          }
          if (products.length < limit) break;
          offset += products.length;
          guard++;
        }
      }
      _newProductIds
        ..clear()
        ..addAll(nextIds);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("New category ids error: $e");
    } finally {
      _isLoadingNewProductIds = false;
    }
  }

  List<dynamic> _extractCategoryChildren(Map<dynamic, dynamic> cat) {
    final rawChildren = cat['categories'] ?? cat['children'] ?? cat['childs'];
    if (rawChildren is List) return rawChildren;
    return [];
  }

  String? _findCategoryIdBySlug(List<dynamic> categories, String slug) {
    for (final cat in categories) {
      if (cat is! Map) continue;
      final rawUrl = (cat['url'] ?? cat['full_url'] ?? "").toString();
      final normalized = rawUrl.replaceAll('\\', '/');
      if (normalized == slug ||
          normalized.endsWith('/$slug') ||
          normalized.endsWith(slug) ||
          normalized.contains('/$slug/')) {
        final id = cat['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
      final children = _extractCategoryChildren(cat);
      if (children.isNotEmpty) {
        final found = _findCategoryIdBySlug(children, slug);
        if (found != null) return found;
      }
    }
    return null;
  }

  Map<String, dynamic>? _findCategoryById(List<dynamic> categories, String id) {
    for (final cat in categories) {
      if (cat is! Map) continue;
      if (cat['id']?.toString() == id) {
        return Map<String, dynamic>.from(cat);
      }
      final children = _extractCategoryChildren(cat);
      if (children.isNotEmpty) {
        final found = _findCategoryById(children, id);
        if (found != null) return found;
      }
    }
    return null;
  }

  List<dynamic> _getCategoryChildren(String id) {
    final cat = _findCategoryById(_apiCategories, id);
    if (cat == null) return [];
    final children = _extractCategoryChildren(cat);
    return children
        .where((c) => c is Map && c['status']?.toString() != "0")
        .toList();
  }

  String _getCategorySlug(dynamic cat) {
    String slug = (cat['url'] ?? cat['full_url'] ?? "").toString();
    slug = slug.replaceAll('\\', '/');
    if (slug.contains('/')) {
      slug = slug.split('/').where((s) => s.isNotEmpty).last;
    }
    return slug;
  }

  String _getCategoryTitleById(String id, String fallback) {
    final source = _allCategories.isNotEmpty ? _allCategories : _apiCategories;
    final cat = _findCategoryById(source, id);
    final name = cat?['name']?.toString() ?? "";
    return name.isNotEmpty ? name : fallback;
  }

  bool _isProductInCategory(Map<dynamic, dynamic> product, String categoryId) {
    if (categoryId.isEmpty) return false;
    final dynamic sourceId = product['source_category_id'];
    if (sourceId != null && sourceId.toString() == categoryId) return true;
    final dynamic directId = product['category_id'] ?? product['categoryId'];
    if (directId != null && directId.toString() == categoryId) return true;
    final dynamic ids =
        product['category_ids'] ??
        product['categoryIds'] ??
        product['categories'] ??
        product['category_list'];
    if (ids is List) {
      for (final item in ids) {
        if (item is Map) {
          final id = item['id'] ?? item['category_id'];
          if (id != null && id.toString() == categoryId) return true;
        } else if (item != null && item.toString() == categoryId) {
          return true;
        }
      }
    } else if (ids is Map) {
      for (final entry in ids.entries) {
        final key = entry.key;
        if (key != null && key.toString() == categoryId) return true;
        final value = entry.value;
        if (value is Map) {
          final id = value['id'] ?? value['category_id'];
          if (id != null && id.toString() == categoryId) return true;
        } else if (value is List) {
          for (final item in value) {
            if (item is Map) {
              final id = item['id'] ?? item['category_id'];
              if (id != null && id.toString() == categoryId) return true;
            } else if (item != null && item.toString() == categoryId) {
              return true;
            }
          }
        } else if (value != null && value.toString() == categoryId) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isNewProduct(Map<dynamic, dynamic> product) {
    final dynamic isNew = product['is_new'];
    if (isNew == true || isNew?.toString() == "1") return true;
    final String productId = product['id']?.toString() ?? "";
    if (productId.isNotEmpty && _newProductIds.contains(productId)) return true;
    for (final id in _newCategoryIds) {
      if (_isProductInCategory(product, id)) return true;
    }
    return false;
  }

  String _formatProductCount(String raw) {
    final value = int.tryParse(raw) ?? 0;
    final mod10 = value % 10;
    final mod100 = value % 100;
    String suffix;
    if (mod10 == 1 && mod100 != 11) {
      suffix = "товар";
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      suffix = "товара";
    } else {
      suffix = "товаров";
    }
    return "$value $suffix";
  }

  Future<void> _fetchBanners() async {
    try {
      final response = await _httpGet(
        Uri.parse('https://hozyain-barin.ru/native/slider.json'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _apiBanners = data;
        });
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            const int maxPrecache = 3;
            int precached = 0;
            for (final item in data) {
              if (item is! Map) continue;
              final url = item['image']?.toString() ?? "";
              if (url.isEmpty) continue;
              precacheImage(CachedNetworkImageProvider(url), context);
              precached++;
              if (precached >= maxPrecache) break;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Slider config error: $e");
    }
  }

  String _buildCategoryUrl(dynamic cat) {
    String slug = (cat['url'] ?? cat['full_url'] ?? "").toString().trim();
    if (slug.isEmpty) return "/";
    slug = slug.startsWith('/') ? slug.substring(1) : slug;
    slug = slug.endsWith('/') ? slug.substring(0, slug.length - 1) : slug;
    return "/category/$slug/";
  }

  @override
  Widget build(BuildContext context) {
    final rootContent = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_isNativeCategoryPage) {
          _goBackFromCategory();
          return;
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.transparent,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _isNativeCategoryPage
                ? _buildCategoryHeader()
                : _buildMainHeader(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: Colors.grey.shade200, height: 1.0),
          ),
        ),
        body: Stack(
          children: [
            // 1. Главная страница (всегда в памяти для сохранения скролла)
            Offstage(
              offstage: _isNativeCategoryPage,
              child: CustomScrollView(
                key: const PageStorageKey('home_scroll'),
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: RepaintBoundary(child: _buildMainBannerSlider()),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(child: _buildCategoryScroll()),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(child: _buildPromoBannerScroll()),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: _buildDiscountedProductsSection(),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(child: _buildAboutSection()),
                ],
              ),
            ),

            // 2. Нативная категория
            Offstage(
              offstage: !_isNativeCategoryPage,
              child: RefreshIndicator(
                onRefresh: () => CategoryCounterService.loadCounts().then((_) {
                  if (mounted) setState(() {});
                }),
                child: CustomScrollView(
                  controller: _nativeScrollController,
                  key: const PageStorageKey('native_category_scroll'),
                  cacheExtent: MediaQuery.of(context).size.height * 0.9,
                  physics: _catalogBackSwipeScrollLocked
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                  slivers: [
                    if (_nativeCategory == "men")
                      const SliverToBoxAdapter(child: SizedBox(height: 5)),
                    if (_nativeCategory == "men")
                      _buildMenSubcategoriesSliver(),
                    if (_nativeCategory == "compare")
                      _buildComparePage(_getActiveNativeList())
                    else if (_nativeCategory == "wishlist")
                      ValueListenableBuilder<int>(
                        valueListenable: _wishCountNotifier,
                        builder: (context, _, __) {
                          return _buildWishlistGrid(_getActiveNativeList());
                        },
                      )
                    else if (_nativeCategory == "cart")
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _cartCountNotifier,
                          _cartSelectionNotifier,
                        ]),
                        builder: (context, _) {
                          return _buildCartPage(_getCartItems());
                        },
                      )
                    else
                      _buildNativeCategoryPage(_getActiveNativeList()),
                    if (_nativeCategory != "wishlist" &&
                        _nativeCategory != "compare" &&
                        _nativeCategory != "cart")
                      _buildNativeLoadMoreSliver(),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                ),
              ),
            ),

            // 2.1 Липкая шапка сравнения
            _buildCompareStickyOverlay(),

            // 2.2 Плавающая кнопка корзины
            _buildCartFloatingButton(),

            // 3. WebView категория удалена (полностью нативная версия)
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          left: false,
          right: false,
          child: _buildBottomBar(
            showTopBorder:
                _nativeCategory != "cart" || !_showCartFloatingButton,
          ),
        ),
      ),
    );

    final destinationPreview = _buildCatalogBackSwipeDestinationPreview();

    final content = Platform.isIOS
        ? Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handleCatalogBackSwipePointerDown,
            onPointerMove: _handleCatalogBackSwipePointerMove,
            onPointerUp: _handleCatalogBackSwipePointerUp,
            onPointerCancel: _handleCatalogBackSwipePointerCancel,
            child: ValueListenableBuilder<double>(
              valueListenable: _catalogBackSwipeOffsetNotifier,
              child: rootContent,
              builder: (context, rawOffset, child) {
                final width = MediaQuery.of(context).size.width;
                final offset =
                    (_canHandleCatalogEdgeBackSwipe ? rawOffset : 0.0)
                        .clamp(0.0, width)
                        .toDouble();
                if (offset <= 0) return child!;
                final shadowAlpha = ((offset / width) * 0.16).clamp(0.0, 0.16);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    destinationPreview,
                    Transform.translate(
                      offset: Offset(offset, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: shadowAlpha,
                              ),
                              blurRadius: 14,
                              offset: const Offset(-2, 0),
                            ),
                          ],
                        ),
                        child: child!,
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        : rootContent;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.white,
        systemNavigationBarContrastEnforced: false,
      ),
      child: content,
    );
  }

  Widget _simpleProductCard(dynamic product, {bool deferHighRes = false}) {
    final id = product['id']?.toString() ?? "";
    return NativeProductCard(
      key: ValueKey("grid_${product['id']}"),
      product: product,
      isNew: product is Map ? _isNewProduct(product) : false,
      galleryListenable: id.isNotEmpty ? _getGalleryNotifier(id) : null,
      scrollListenable: _scrollingNotifier,
      scrollMainImageListenable: _scrollVisibleMainImageIds,
      deferHighRes: deferHighRes,
      favoriteListenable: id.isNotEmpty ? _getFavoriteNotifier(id) : null,
      isFavoriteResolver: _isFavorite,
      onFavoriteTap: () => _toggleFavorite(product),
      compareListenable: id.isNotEmpty ? _getCompareNotifier(id) : null,
      isCompareResolver: _isCompared,
      onCompareTap: () => _toggleCompare(product),
      onAddToCart: () => _addToCart(product),
      cartListenable: _cartCountNotifier,
      isInCartResolver: (id) => (_cartQuantityByProductId[id] ?? 0) > 0,
      onTap: () => _openProductPage(product),
    );
  }

  Widget _animatedCategoryProductCard(dynamic product) {
    final id = product['id']?.toString() ?? "";
    return _SlideInOutCard(
      id: id,
      animatedIds: _animatedProductIds,
      child: _simpleProductCard(product, deferHighRes: true),
    );
  }

  Widget _buildLoadingProductCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(color: Colors.grey.shade100),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 18, width: 80, color: Colors.grey.shade100),
                  const SizedBox(height: 10),
                  Container(
                    height: 12,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 140,
                    color: Colors.grey.shade100,
                  ),
                  const Spacer(),
                  Container(height: 28, width: 90, color: Colors.grey.shade100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _discountedProductCard(dynamic product) {
    final id = product['id']?.toString() ?? "";
    return NativeProductCard(
      key: ValueKey("home_disc_${product['id']}"),
      product: product,
      isNew: product is Map ? _isNewProduct(product) : false,
      isHorizontal: true,
      galleryListenable: id.isNotEmpty ? _getGalleryNotifier(id) : null,
      favoriteListenable: id.isNotEmpty ? _getFavoriteNotifier(id) : null,
      isFavoriteResolver: _isFavorite,
      onFavoriteTap: () => _toggleFavorite(product),
      compareListenable: id.isNotEmpty ? _getCompareNotifier(id) : null,
      isCompareResolver: _isCompared,
      onCompareTap: () => _toggleCompare(product),
      onAddToCart: () => _addToCart(product),
      cartListenable: _cartCountNotifier,
      isInCartResolver: (id) => (_cartQuantityByProductId[id] ?? 0) > 0,
      onTap: () => _openProductPage(product),
    );
  }

  Widget _buildNativeCategoryPage(List<dynamic> items) {
    final key = _nativeCategory;
    final bool isLoading =
        _isFilterLoading ||
        _isLocalSortLoading ||
        _isLocalFilterLoading ||
        _nativeIsLoadingMore[key] == true;
    final bool hasMore = _nativeHasMore[key] != false;
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 8.0; // 4 слева + 4 справа
    const crossAxisSpacing = 3.0;
    const mainAxisSpacing = 5.0;
    final itemWidth = (screenWidth - horizontalPadding - crossAxisSpacing) / 2;
    final imageHeight = itemWidth * 4 / 3;
    const contentHeight = 146.0; // slight bump to avoid 1px overflow
    final itemHeight = imageHeight + contentHeight;
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      mainAxisExtent: itemHeight,
    );
    Widget buildPlaceholderGrid(int count) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        sliver: SliverGrid(
          gridDelegate: gridDelegate,
          delegate: SliverChildBuilderDelegate((context, index) {
            return RepaintBoundary(
              key: ValueKey("native_${_nativeCategory}_placeholder_$index"),
              child: _buildLoadingProductCard(),
            );
          }, childCount: count),
        ),
      );
    }

    if (items.isEmpty) {
      if (isLoading || hasMore) {
        final int initialPlaceholderCount =
            ((MediaQuery.of(context).size.height / itemHeight).ceil() + 1) * 2;
        return buildPlaceholderGrid(initialPlaceholderCount);
      }
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            "Ничего не найдено",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    final int placeholderCount = hasMore ? 24 : 0;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      sliver: SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= items.length) {
            return RepaintBoundary(
              key: ValueKey("native_${_nativeCategory}_placeholder_$index"),
              child: _buildLoadingProductCard(),
            );
          }
          final product = items[index];
          String productId = "";
          if (product is Map) {
            productId = product['id']?.toString() ?? "";
          }
          final itemKey = productId.isNotEmpty
              ? "native_${_nativeCategory}_$productId"
              : "native_${_nativeCategory}_idx_$index";
          return RepaintBoundary(
            key: ValueKey(itemKey),
            child: _animatedCategoryProductCard(product),
          );
        }, childCount: items.length + placeholderCount),
      ),
    );
  }

  Widget _buildWishlistGrid(List<dynamic> items) {
    if (items.isEmpty) {
      return _buildEmptyState(
        title: "Список избранного пуст",
        subtitle: "Для добавления товаров в избранное",
      );
    }
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 8.0;
    const crossAxisSpacing = 3.0;
    const mainAxisSpacing = 5.0;
    final itemWidth = (screenWidth - horizontalPadding - crossAxisSpacing) / 2;
    final imageHeight = itemWidth * 4 / 3;
    const contentHeight = 146.0; // slight bump to avoid 1px overflow
    final itemHeight = imageHeight + contentHeight;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          mainAxisExtent: itemHeight,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          return RepaintBoundary(child: _simpleProductCard(items[index]));
        }, childCount: items.length),
      ),
    );
  }

  Widget _buildCartPage(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return _buildEmptyState(
        title: "Корзина пуста",
        subtitle: "Добавьте товары из каталога",
      );
    }
    final showSelectionUI = items.length > 1;
    final selectedItems = showSelectionUI
        ? items
              .where(
                (item) =>
                    _cartSelectedIds.contains(item['id']?.toString() ?? ""),
              )
              .toList()
        : items;
    final selectedCount = selectedItems.fold<int>(
      0,
      (sum, item) => sum + (item['cart_quantity'] as int? ?? 1),
    );
    double totalSum = 0.0;
    double totalCompareSum = 0.0;
    for (final item in selectedItems) {
      final qty = item['cart_quantity'] as int? ?? 1;
      final raw = item['raw_price'] ?? item['price'];
      final price = (raw is num) ? raw.toDouble() : _parsePriceValue(raw);
      totalSum += price * qty;
      final rawCompare = item['raw_compare_price'] ?? item['compare_price'];
      final comparePrice = (rawCompare is num)
          ? rawCompare.toDouble()
          : _parsePriceValue(rawCompare);
      if (comparePrice > price && comparePrice > 0) {
        totalCompareSum += comparePrice * qty;
      }
    }
    final allSelected = _cartSelectedIds.length == items.length;
    final countWord = (selectedCount % 10 == 1 && selectedCount % 100 != 11)
        ? "товар"
        : (selectedCount % 10 >= 2 &&
              selectedCount % 10 <= 4 &&
              (selectedCount % 100 < 10 || selectedCount % 100 >= 20))
        ? "товара"
        : "товаров";
    final discountSum = totalCompareSum > totalSum
        ? totalCompareSum - totalSum
        : 0.0;
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 2),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == 0 && showSelectionUI) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (allSelected) {
                            _deselectAllCart();
                          } else {
                            _selectAllCart(items);
                          }
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: allSelected,
                              onChanged: (_) {
                                if (allSelected) {
                                  _deselectAllCart();
                                } else {
                                  _selectAllCart(items);
                                }
                              },
                              activeColor: Colors.black,
                              fillColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.black;
                                }
                                return Colors.transparent;
                              }),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Выбрать все",
                              style: _menuStyle.copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _cartSelectedIds.isEmpty
                            ? null
                            : _deleteSelectedFromCart,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: _cartSelectedIds.isEmpty
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Удалить выбранные",
                              style: _menuStyle.copyWith(
                                fontSize: 14,
                                color: _cartSelectedIds.isEmpty
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (index == 0 && !showSelectionUI) {
                return const SizedBox.shrink();
              }
              final item = items[index - 1];
              final productId = item['id']?.toString() ?? "";
              final qty = item['cart_quantity'] as int? ?? 1;
              final raw = item['raw_price'] ?? item['price'];
              final price = (raw is num)
                  ? raw.toDouble()
                  : _parsePriceValue(raw);
              final rawCompare =
                  item['raw_compare_price'] ?? item['compare_price'];
              final comparePrice = (rawCompare is num)
                  ? rawCompare.toDouble()
                  : _parsePriceValue(rawCompare);
              final showOldPrice = comparePrice > price && comparePrice > 0;
              final displayPrice = price * qty;
              final displayComparePrice = comparePrice * qty;
              final imageUrl = _getProductPreviewImage(item);
              final name = item['name']?.toString() ?? "";
              final stockCount = _resolveProductStockCount(item);
              const cartItemHeight = 105.0;
              const cartImageWidth = 85.0;
              final isSelected = _cartSelectedIds.contains(productId);
              return Container(
                margin: const EdgeInsets.fromLTRB(5, 4, 5, 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _openProductPage(item),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        width: cartImageWidth,
                                        height: cartItemHeight,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          color: Colors.grey.shade100,
                                          width: cartImageWidth,
                                          height: cartItemHeight,
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          color: Colors.grey.shade100,
                                          width: cartImageWidth,
                                          height: cartItemHeight,
                                          child: const Icon(Icons.image),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey.shade100,
                                        width: cartImageWidth,
                                        height: cartItemHeight,
                                        child: const Icon(Icons.image),
                                      ),
                              ),
                            ),
                            if (showSelectionUI)
                              Positioned(
                                top: 2,
                                left: 2,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) =>
                                      _toggleCartSelection(productId),
                                  activeColor: Colors.black,
                                  fillColor: WidgetStateProperty.resolveWith((
                                    states,
                                  ) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.black;
                                    }
                                    return Colors.white;
                                  }),
                                  side: const BorderSide(color: Colors.black),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: cartItemHeight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      "${_formatPrice(displayPrice)} ₽",
                                      style: _cardPriceStyle.copyWith(
                                        fontSize: 18,
                                      ),
                                    ),
                                    if (showOldPrice)
                                      Text(
                                        "${_formatPrice(displayComparePrice)} ₽",
                                        style: _cardOldPriceStyle.copyWith(
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _openProductPage(item),
                                  child: Text(
                                    name,
                                    style: _cardNameStyle.copyWith(
                                      fontSize: 15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Spacer(),
                                if (stockCount > 0)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _showCartStockSheet(
                                      context,
                                      productId,
                                      item,
                                    ),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          const WidgetSpan(
                                            alignment:
                                                PlaceholderAlignment.middle,
                                            child: Icon(
                                              Icons.add,
                                              size: 17,
                                              color: Colors.black38,
                                            ),
                                          ),
                                          const WidgetSpan(
                                            child: SizedBox(width: 4),
                                          ),
                                          TextSpan(
                                            text: "В наличии ",
                                            style: _subMenuStyle.copyWith(
                                              fontSize: 14,
                                              color: Colors.black,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "$stockCount шт.",
                                            style: _subMenuStyle.copyWith(
                                              fontSize: 14,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (qty == 1)
                                  IconButton(
                                    onPressed: () => _removeFromCart(productId),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 22,
                                    ),
                                    style: IconButton.styleFrom(
                                      padding: const EdgeInsets.all(4),
                                      minimumSize: const Size(40, 36),
                                      overlayColor: Colors.transparent,
                                    ),
                                  )
                                else
                                  IconButton(
                                    onPressed: () =>
                                        _updateCartQuantity(productId, -1),
                                    icon: const Icon(Icons.remove, size: 22),
                                    style: IconButton.styleFrom(
                                      padding: const EdgeInsets.all(4),
                                      minimumSize: const Size(40, 36),
                                      overlayColor: Colors.transparent,
                                    ),
                                  ),
                                SizedBox(
                                  width: 28,
                                  child: Center(
                                    child: Text(
                                      "$qty",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _updateCartQuantity(productId, 1),
                                  icon: const Icon(Icons.add, size: 22),
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(40, 36),
                                    overlayColor: Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  unawaited(
                                    _launchUrl(
                                      'https://hozyain-barin.ru/cart/',
                                    ),
                                  );
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Colors.black),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Купить",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }, childCount: items.length + 1),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            key: _cartItogoKey,
            padding: const EdgeInsets.fromLTRB(5, 16, 5, 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Итого:",
                            style: _boldMenuStyle.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$selectedCount $countWord",
                            style: _subMenuStyle.copyWith(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${_formatPrice(totalSum)} ₽",
                            style: _boldMenuStyle.copyWith(fontSize: 18),
                          ),
                          if (totalCompareSum > 0)
                            Text(
                              "${_formatPrice(totalCompareSum)} ₽",
                              style: _cardOldPriceStyle.copyWith(fontSize: 14),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (discountSum > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Общая скидка",
                          style: _subMenuStyle.copyWith(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          "-${_formatPrice(discountSum)} ₽",
                          style: _subMenuStyle.copyWith(
                            fontSize: 14,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!mounted) return;
                        _openCheckoutPage();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Перейти к оформлению",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _syncCompareHorizontalScroll(
    ScrollController source,
    ScrollController target,
  ) {
    if (_isCompareScrollSyncing) return;
    if (!source.hasClients || !target.hasClients) return;
    final double targetOffset = source.position.pixels.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if ((target.position.pixels - targetOffset).abs() < 0.5) return;
    _isCompareScrollSyncing = true;
    target.jumpTo(targetOffset);
    _isCompareScrollSyncing = false;
  }

  void _setCompareStickyVisible(bool value) {
    if (_isCompareStickyVisible == value) return;
    void apply() {
      if (mounted) setState(() => _isCompareStickyVisible = value);
    }

    if (_isInBuildPhase()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isCompareStickyVisible != value) apply();
      });
      return;
    }
    apply();
  }

  void _scheduleCartFloatingButtonUpdate() {
    if (!mounted) return;
    if (!_isNativeCategoryPage || _nativeCategory != "cart") return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isNativeCategoryPage || _nativeCategory != "cart") {
        return;
      }
      _updateCartFloatingButtonVisibility();
    });
  }

  void _updateCompareStickyVisibility() {
    if (!_isNativeCategoryPage || _nativeCategory != "compare") {
      if (_isCompareStickyVisible) _setCompareStickyVisible(false);
      return;
    }
    final ctx = _compareHeaderKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox) return;
    final offset = renderObject.localToGlobal(Offset.zero);
    final height = renderObject.size.height;
    final topLimit = MediaQuery.of(context).padding.top + kToolbarHeight;
    final bool shouldShow = offset.dy + height <= topLimit + 1;
    _setCompareStickyVisible(shouldShow);
  }

  void _updateCartFloatingButtonVisibility() {
    if (!_isNativeCategoryPage || _nativeCategory != "cart") {
      if (_showCartFloatingButton && mounted) {
        setState(() => _showCartFloatingButton = false);
      }
      return;
    }
    final items = _getCartItems();
    if (items.isEmpty) {
      if (_showCartFloatingButton && mounted) {
        setState(() => _showCartFloatingButton = false);
      }
      return;
    }
    final ctx = _cartItogoKey.currentContext;
    if (ctx == null) {
      if (!_nativeScrollController.hasClients) return;
      final pos = _nativeScrollController.position;
      final viewportHeight = pos.viewportDimension;
      final maxScrollExtent = pos.maxScrollExtent;
      final scrollOffset = pos.pixels;
      final mainButtonVisible =
          maxScrollExtent <= viewportHeight + 20 ||
          (scrollOffset + viewportHeight >= maxScrollExtent - 100);
      final bool shouldShow = !mainButtonVisible;
      if (_showCartFloatingButton != shouldShow && mounted) {
        setState(() => _showCartFloatingButton = shouldShow);
      }
      return;
    }
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox) return;
    final offset = renderObject.localToGlobal(Offset.zero);
    final height = renderObject.size.height;
    final screenHeight = MediaQuery.of(ctx).size.height;
    final padding = MediaQuery.of(ctx).padding;
    final visibleTop = padding.top + kToolbarHeight;
    final visibleBottom = screenHeight - padding.bottom - 80;
    final mainButtonVisible =
        offset.dy + height > visibleTop && offset.dy < visibleBottom;
    final bool shouldShow = !mainButtonVisible;
    if (_showCartFloatingButton != shouldShow && mounted) {
      setState(() => _showCartFloatingButton = shouldShow);
    }
  }

  Widget _buildCartFloatingButton() {
    if (!_isNativeCategoryPage || _nativeCategory != "cart") {
      return const SizedBox.shrink();
    }
    final items = _getCartItems();
    if (items.isEmpty) return const SizedBox.shrink();
    final showSelectionUI = items.length > 1;
    final selectedItems = showSelectionUI
        ? items
              .where(
                (item) =>
                    _cartSelectedIds.contains(item['id']?.toString() ?? ""),
              )
              .toList()
        : items;
    final selectedCount = selectedItems.fold<int>(
      0,
      (sum, item) => sum + (item['cart_quantity'] as int? ?? 1),
    );
    double totalSum = 0.0;
    double totalCompareSum = 0.0;
    for (final item in selectedItems) {
      final qty = item['cart_quantity'] as int? ?? 1;
      final raw = item['raw_price'] ?? item['price'];
      final price = (raw is num) ? raw.toDouble() : _parsePriceValue(raw);
      totalSum += price * qty;
      final rawCompare = item['raw_compare_price'] ?? item['compare_price'];
      final comparePrice = (rawCompare is num)
          ? rawCompare.toDouble()
          : _parsePriceValue(rawCompare);
      if (comparePrice > price && comparePrice > 0) {
        totalCompareSum += comparePrice * qty;
      }
    }
    final countWord = (selectedCount % 10 == 1 && selectedCount % 100 != 11)
        ? "товар"
        : (selectedCount % 10 >= 2 &&
              selectedCount % 10 <= 4 &&
              (selectedCount % 100 < 10 || selectedCount % 100 >= 20))
        ? "товара"
        : "товаров";
    const duration = Duration(milliseconds: 280);
    const curve = Curves.easeOutCubic;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: IgnorePointer(
          ignoring: !_showCartFloatingButton,
          child: AnimatedOpacity(
            opacity: _showCartFloatingButton ? 1 : 0,
            duration: duration,
            curve: curve,
            child: AnimatedSlide(
              offset: _showCartFloatingButton
                  ? Offset.zero
                  : const Offset(0, 1),
              duration: duration,
              curve: curve,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Итого:",
                              style: _boldMenuStyle.copyWith(
                                fontSize: 18,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "$selectedCount $countWord",
                              style: _subMenuStyle.copyWith(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${_formatPrice(totalSum)} ₽",
                              style: _boldMenuStyle.copyWith(
                                fontSize: 18,
                                height: 1.05,
                              ),
                            ),
                            if (totalCompareSum > 0) ...[
                              const SizedBox(height: 5),
                              Text(
                                "${_formatPrice(totalCompareSum)} ₽",
                                style: _cardOldPriceStyle.copyWith(
                                  fontSize: 14,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 140,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!mounted) return;
                            _openCheckoutPage();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text(
                            "К оформлению",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _compareItemWidthForCount(
    int productCount,
    double screenWidth, {
    double labelWidth = 150.0,
    double horizontalPadding = 24.0,
  }) {
    final int visibleColumns = productCount < 1
        ? 1
        : (productCount > 2 ? 2 : productCount);
    double itemWidth =
        (screenWidth - labelWidth - horizontalPadding) / visibleColumns;
    if (itemWidth.isNaN || itemWidth.isInfinite || itemWidth <= 0) {
      itemWidth = 170.0;
    }
    if (itemWidth > 240.0) itemWidth = 240.0;
    return itemWidth;
  }

  void _startCompareRemoveAnimation(Map product) {
    final id = product['id']?.toString() ?? "";
    if (id.isEmpty ||
        !_compareIds.contains(id) ||
        _compareRemovingIds.contains(id)) {
      return;
    }
    setState(() => _compareRemovingIds.add(id));
    const duration = Duration(milliseconds: 240);
    Future.delayed(duration, () {
      if (!mounted) return;
      _compareRemovingIds.remove(id);
      if (_compareIds.contains(id)) {
        _toggleCompare(product);
      }
      if (mounted) setState(() {});
    });
  }

  int _wrapIndex(int index, int totalCount) {
    if (totalCount <= 0) return 0;
    final mod = index % totalCount;
    return mod < 0 ? mod + totalCount : mod;
  }

  int _advanceIndexAvoidOther({
    required int start,
    required int step,
    required int other,
    required int totalCount,
  }) {
    if (totalCount <= 1) return _wrapIndex(start, totalCount);
    int candidate = _wrapIndex(start, totalCount);
    if (candidate != other) return candidate;
    for (int i = 0; i < totalCount; i++) {
      candidate = _wrapIndex(candidate + step, totalCount);
      if (candidate != other) return candidate;
    }
    return candidate;
  }

  _CompareIndices _resolveCompareIndicesForGroup(
    String groupKey,
    int totalCount,
  ) {
    if (totalCount <= 0) {
      return const _CompareIndices(0, 0, false);
    }
    final int maxIndex = totalCount - 1;
    int left = (_compareLeftIndexByGroup[groupKey] ?? 0).clamp(0, maxIndex);
    int right = (_compareRightIndexByGroup[groupKey] ?? 1).clamp(0, maxIndex);
    final bool hasRight = totalCount > 1;
    if (!hasRight) {
      right = left;
    } else if (left == right) {
      right = _advanceIndexAvoidOther(
        start: right + 1,
        step: 1,
        other: left,
        totalCount: totalCount,
      );
    }
    return _CompareIndices(left, right, hasRight);
  }

  void _setCompareLeftIndexForGroup(String groupKey, int next, int totalCount) {
    if (totalCount <= 0) return;
    final int maxIndex = totalCount - 1;
    final int right = (_compareRightIndexByGroup[groupKey] ?? 1).clamp(
      0,
      maxIndex,
    );
    final int current = (_compareLeftIndexByGroup[groupKey] ?? 0).clamp(
      0,
      maxIndex,
    );
    final int step = next >= current ? 1 : -1;
    final int left = _advanceIndexAvoidOther(
      start: next,
      step: step,
      other: right,
      totalCount: totalCount,
    );
    if (left == current) return;
    setState(() {
      _compareLeftIndexByGroup[groupKey] = left;
      _activeCompareGroupKey = groupKey;
    });
  }

  void _setCompareRightIndexForGroup(
    String groupKey,
    int next,
    int totalCount,
  ) {
    if (totalCount <= 1) return;
    final int maxIndex = totalCount - 1;
    final int left = (_compareLeftIndexByGroup[groupKey] ?? 0).clamp(
      0,
      maxIndex,
    );
    final int current = (_compareRightIndexByGroup[groupKey] ?? 1).clamp(
      0,
      maxIndex,
    );
    final int step = next >= current ? 1 : -1;
    final int right = _advanceIndexAvoidOther(
      start: next,
      step: step,
      other: left,
      totalCount: totalCount,
    );
    if (right == current) return;
    setState(() {
      _compareRightIndexByGroup[groupKey] = right;
      _activeCompareGroupKey = groupKey;
    });
  }

  List<Map> _compareSelectedProducts(
    List<Map> products,
    int leftIndex,
    int rightIndex,
    bool hasRight,
  ) {
    if (products.isEmpty) return <Map>[];
    final result = <Map>[products[leftIndex]];
    if (hasRight) result.add(products[rightIndex]);
    return result;
  }

  List<String> _compareSelectedValues(
    List<String> values,
    int leftIndex,
    int rightIndex,
    bool hasRight,
  ) {
    final result = <String>[];
    result.add(leftIndex < values.length ? values[leftIndex] : "");
    if (hasRight) {
      result.add(rightIndex < values.length ? values[rightIndex] : "");
    }
    return result;
  }

  List<String> _compareSelectedProductIds(
    List<Map> products,
    int leftIndex,
    int rightIndex,
    bool hasRight,
  ) {
    final result = <String>[];
    if (products.isEmpty) return result;
    result.add(products[leftIndex]['id']?.toString() ?? "");
    if (hasRight) {
      result.add(products[rightIndex]['id']?.toString() ?? "");
    }
    return result;
  }

  String _normalizeCompareValue(String value) {
    final v = value.trim().toLowerCase();
    if (v == "-" || v.isEmpty) return "";
    return v.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _compareValuesDiffer(String a, String b) {
    return _normalizeCompareValue(a) != _normalizeCompareValue(b);
  }

  Widget _buildCompareCardPager({
    required int displayIndex,
    required int totalCount,
    required bool canPrev,
    required bool canNext,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    if (totalCount <= 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _buildComparePagerButton(
                icon: Icons.chevron_left,
                enabled: canPrev,
                onTap: onPrev,
              ),
            ),
            Text(
              "${displayIndex + 1} из $totalCount",
              style: _subMenuStyle.copyWith(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _buildComparePagerButton(
                icon: Icons.chevron_right,
                enabled: canNext,
                onTap: onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparePagerButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.black54 : Colors.black26,
        ),
      ),
    );
  }

  String _resolveCompareProductCategoryId(Map product) {
    final source = product['source_category_id']?.toString() ?? "";
    if (source.isNotEmpty) return source;
    final direct = product['category_id'] ?? product['categoryId'];
    final directId = direct?.toString() ?? "";
    if (directId.isNotEmpty) return directId;
    final dynamic ids =
        product['category_ids'] ??
        product['categoryIds'] ??
        product['categories'] ??
        product['category_list'];
    if (ids is List && ids.isNotEmpty) {
      final first = ids.first;
      if (first is Map) {
        return (first['id'] ?? first['category_id'])?.toString() ?? "";
      }
      return first?.toString() ?? "";
    }
    if (ids is Map && ids.isNotEmpty) {
      for (final entry in ids.entries) {
        final key = entry.key?.toString() ?? "";
        if (key.isNotEmpty) return key;
        final value = entry.value;
        if (value is Map) {
          final id = value['id'] ?? value['category_id'];
          if (id != null) return id.toString();
        } else if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is Map) {
            final id = first['id'] ?? first['category_id'];
            if (id != null) return id.toString();
          } else if (first != null) {
            return first.toString();
          }
        }
      }
    }
    return "";
  }

  Map<String, List<Map>> _groupCompareProducts(List<Map> products) {
    final Map<String, List<Map>> groups = {};
    for (final product in products) {
      final id = _resolveCompareProductCategoryId(product);
      final key = id.isNotEmpty ? id : _compareUnknownGroupKey;
      groups.putIfAbsent(key, () => <Map>[]).add(product);
    }
    return groups;
  }

  String _resolveCompareGroupTitle(String groupKey) {
    if (groupKey == _compareUnknownGroupKey) return "Сравнение";
    return _getCategoryTitleById(groupKey, "Сравнение");
  }

  String _buildCompareShareText(List<Map> products) {
    final lines = <String>[];
    for (final product in products) {
      final name = product['name']?.toString().trim() ?? "";
      final price = _resolveComparePrice(product);
      final link = product['link']?.toString().trim() ?? "";
      final parts = <String>[];
      if (name.isNotEmpty) parts.add(name);
      if (price.isNotEmpty) parts.add(price);
      if (link.isNotEmpty) parts.add(link);
      if (parts.isNotEmpty) {
        lines.add(parts.join(" — "));
      }
    }
    return lines.join("\n");
  }

  void _shareCompareList() {
    final products = _getActiveNativeList().whereType<Map>().toList();
    if (products.isEmpty) return;
    final text = _buildCompareShareText(products);
    if (text.isEmpty) return;
    SharePlus.instance.share(
      ShareParams(text: text, subject: "Список сравнения"),
    );
  }

  void _showCompareSectionsMenu() {
    if (_nativeCategory != "compare") return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _buildBottomSheetHandle(),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(
                  Icons.share_outlined,
                  color: Colors.black54,
                ),
                title: Text(
                  "Поделиться списком",
                  style: _subMenuStyle.copyWith(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _shareCompareList();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: Text(
                  "Удалить все списки",
                  style: _subMenuStyle.copyWith(
                    fontSize: 16,
                    color: Colors.redAccent,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _clearCompare();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _removeCompareGroup(String groupKey) {
    final allProducts = _getActiveNativeList().whereType<Map>().toList();
    final grouped = _groupCompareProducts(allProducts);
    final groupProducts = grouped[groupKey] ?? <Map>[];
    if (groupProducts.isEmpty) return;
    final ids = groupProducts
        .map((p) => p['id']?.toString() ?? "")
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    for (final id in ids) {
      _compareIds.remove(id);
      _compareProductsById.remove(id);
      _compareRemovingIds.remove(id);
      final notifier = _compareVersionById[id];
      if (notifier != null) notifier.value++;
    }
    _compareCountNotifier.value = _compareIds.length;
    _compareLeftIndexByGroup.remove(groupKey);
    _compareRightIndexByGroup.remove(groupKey);
    _compareCollapsedGroups.removeWhere((key) => key.startsWith("$groupKey::"));
    _compareGroupKeys.removeWhere((key, _) => key.startsWith("$groupKey::"));
    _compareRowsKey = "";
    _compareRowsCache = [];

    if (_nativeCategory == "compare") {
      _syncCompareList();
      _ensureCompareDetails();
    }
    final remaining = _groupCompareProducts(
      _getActiveNativeList().whereType<Map>().toList(),
    );
    if (_activeCompareGroupKey == groupKey) {
      _activeCompareGroupKey = remaining.isNotEmpty
          ? remaining.keys.first
          : null;
    }
    if (mounted) setState(() {});
  }

  void _openCompareGroupCategory(String groupKey) {
    if (groupKey.isEmpty || groupKey == _compareUnknownGroupKey) return;
    final String key =
        _resolveNativeCategory(groupKey, null) ?? "custom_$groupKey";
    final String title = _getCategoryTitleById(groupKey, "Категория");
    _openNativeCategoryById(key: key, categoryId: groupKey, title: title);
  }

  Widget _buildCompareGroupTabs(
    List<String> groupKeys,
    String activeKey,
    Map<String, List<Map>> grouped,
  ) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: groupKeys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = groupKeys[index];
          final isActive = key == activeKey;
          final title = _resolveCompareGroupTitle(key);
          final count = grouped[key]?.length ?? 0;
          return _buildCompareGroupChip(
            title: title,
            count: count,
            isActive: isActive,
            onTap: () => setState(() => _activeCompareGroupKey = key),
            onRemove: isActive ? () => _removeCompareGroup(key) : null,
          );
        },
      ),
    );
  }

  Widget _buildCompareGroupChip({
    required String title,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onRemove,
  }) {
    final textStyle = (isActive ? _boldSubMenuStyle : _subMenuStyle).copyWith(
      fontSize: 15,
      color: isActive ? Colors.black : Colors.black54,
    );
    final countStyle = _subMenuStyle.copyWith(
      fontSize: 15,
      color: Colors.black54,
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: Colors.grey.shade200) : null,
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: textStyle),
            const SizedBox(width: 4),
            Text("$count", style: countStyle),
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove ?? onTap,
              child: const Icon(Icons.close, size: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareLabel(
    String label, {
    double fontSize = 12,
    bool showDot = true,
    bool dotAtEnd = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDot && !dotAtEnd)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFF4A21D),
                shape: BoxShape.circle,
              ),
            ),
          ),
        if (showDot && !dotAtEnd) const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: _subMenuStyle.copyWith(
              fontSize: fontSize,
              color: Colors.black54,
            ),
          ),
        ),
        if (showDot && dotAtEnd) const SizedBox(width: 6),
        if (showDot && dotAtEnd)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFF4A21D),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  static const List<String> _compareGroupOrder = <String>[
    "Общие параметры",
    "Внешний вид",
    "Конструкция",
    "Габариты и вес",
    "Дополнительно",
  ];
  static const String _compareUnknownGroupKey = "__unknown__";

  String _compareGroupForFeatureName(String name) {
    final n = name.toLowerCase();
    if (n.contains("габар") ||
        n.contains("вес") ||
        n.contains("ширин") ||
        n.contains("высот") ||
        n.contains("длин") ||
        n.contains("толщ") ||
        n.contains("объем")) {
      return "Габариты и вес";
    }
    if (n.contains("цвет") ||
        n.contains("внеш") ||
        n.contains("дизайн") ||
        n.contains("рисунк") ||
        n.contains("фактур") ||
        n.contains("отделк")) {
      return "Внешний вид";
    }
    if (n.contains("материал") ||
        n.contains("карман") ||
        n.contains("отдел") ||
        n.contains("конструк") ||
        n.contains("молни") ||
        n.contains("ремень") ||
        n.contains("ручк") ||
        n.contains("застеж") ||
        n.contains("клапан") ||
        n.contains("жестк") ||
        n.contains("каркас")) {
      return "Конструкция";
    }
    if (n.contains("тип") ||
        n.contains("модель") ||
        n.contains("код") ||
        n.contains("ноутбук") ||
        n.contains("формат") ||
        n.contains("размер") ||
        n.contains("назнач")) {
      return "Общие параметры";
    }
    return "Дополнительно";
  }

  Widget _buildCompareGroupHeader(
    String title,
    double totalWidth, {
    required bool isCollapsed,
    required VoidCallback onToggle,
    Key? headerKey,
  }) {
    return GestureDetector(
      key: headerKey,
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        width: totalWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: _boldMenuStyle.copyWith(fontSize: 16)),
            ),
            Icon(
              isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              size: 18,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareLabelRow(
    String label,
    double totalWidth, {
    required Color backgroundColor,
    required bool showDot,
  }) {
    return Container(
      width: totalWidth,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      color: backgroundColor,
      child: _buildCompareLabel(label, fontSize: 12, showDot: showDot),
    );
  }

  Widget _buildCompareValuesRow(
    List<String> values,
    double itemWidth,
    List<String> productIds, {
    required Color backgroundColor,
    bool highlighted = false,
  }) {
    final borderColor = Colors.grey.shade200;
    final bool leftCollapsed =
        productIds.isNotEmpty && _compareRemovingIds.contains(productIds[0]);
    final bool rightCollapsed =
        productIds.length > 1 && _compareRemovingIds.contains(productIds[1]);
    final bool showDivider =
        values.length > 1 && !leftCollapsed && !rightCollapsed;
    return Container(
      color: highlighted ? const Color(0xFFFFF8D9) : backgroundColor,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCompareValueCellBox(
              value: values.isNotEmpty ? values[0] : "",
              width: leftCollapsed ? 0 : itemWidth,
              isCollapsed: leftCollapsed,
              fontSize: 14,
            ),
            if (values.length > 1)
              SizedBox(
                width: 1,
                child: showDivider
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Container(color: borderColor),
                      )
                    : const SizedBox.shrink(),
              ),
            if (values.length > 1)
              _buildCompareValueCellBox(
                value: values.length > 1 ? values[1] : "",
                width: rightCollapsed ? 0 : itemWidth,
                isCollapsed: rightCollapsed,
                fontSize: 14,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareValueCellBox({
    required String value,
    required double width,
    required bool isCollapsed,
    required double fontSize,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      width: width,
      padding: isCollapsed
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: isCollapsed
          ? const SizedBox.shrink()
          : Text(
              value.isEmpty ? "-" : value,
              style: _subMenuStyle.copyWith(
                fontSize: fontSize,
                color: Colors.black87,
              ),
            ),
    );
  }

  Widget _buildCompareFeatureBlock({
    required String label,
    required List<String> values,
    required double itemWidth,
    required List<String> productIds,
    required double totalWidth,
    required Color backgroundColor,
    required bool showDot,
    required bool highlighted,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: totalWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompareLabelRow(
                label,
                totalWidth,
                backgroundColor: backgroundColor,
                showDot: showDot,
              ),
              _buildCompareValuesRow(
                values,
                itemWidth,
                productIds,
                backgroundColor: backgroundColor,
                highlighted: highlighted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompareAddPlaceholderCard({
    required double height,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                child: const Icon(Icons.add, size: 12, color: Colors.black54),
              ),
              const SizedBox(width: 8),
              Text(
                "Добавить товар",
                style: _subMenuStyle.copyWith(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompareCompactAddPlaceholder({
    required double width,
    required double height,
    required VoidCallback onTap,
    double sidePadding = 8,
  }) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: SizedBox(
            height: height,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Добавить товар",
                      style: _subMenuStyle.copyWith(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompareProductsGrid({
    required List<Map> products,
    required List<int> indices,
    required int totalCount,
    required String groupKey,
    required bool showSecondColumn,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisSpacing = 3.0;
        const mainAxisSpacing = 5.0;
        final int gridColumns = showSecondColumn ? 2 : 1;
        final maxWidth = constraints.maxWidth;
        final itemWidth =
            (maxWidth - (gridColumns - 1) * crossAxisSpacing) / gridColumns;
        final imageHeight = itemWidth * 4 / 3;
        const contentHeight = 146.0; // slight bump to avoid 1px overflow
        final cardHeight = imageHeight + contentHeight;
        const double pagerHeight = 32.0;
        const double pagerTopSpacing = 6.0;
        final bool showPager = totalCount > 2;
        final itemHeight =
            cardHeight + (showPager ? (pagerHeight + pagerTopSpacing) : 0);
        final bool showAddPlaceholder =
            showSecondColumn && products.length == 1;
        final int totalItems = products.length + (showAddPlaceholder ? 1 : 0);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridColumns,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            mainAxisExtent: itemHeight,
          ),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            if (showAddPlaceholder && index >= products.length) {
              return SizedBox(
                height: cardHeight,
                child: _buildCompareAddPlaceholderCard(
                  height: cardHeight,
                  onTap: () => _openCompareGroupCategory(groupKey),
                ),
              );
            }
            final product = products[index];
            final displayIndex = (index < indices.length) ? indices[index] : 0;
            final bool isLeft = index == 0;
            final bool canPrev = totalCount > 1;
            final bool canNext = totalCount > 1;
            final VoidCallback onPrev = isLeft
                ? () => _setCompareLeftIndexForGroup(
                    groupKey,
                    displayIndex - 1,
                    totalCount,
                  )
                : () => _setCompareRightIndexForGroup(
                    groupKey,
                    displayIndex - 1,
                    totalCount,
                  );
            final VoidCallback onNext = isLeft
                ? () => _setCompareLeftIndexForGroup(
                    groupKey,
                    displayIndex + 1,
                    totalCount,
                  )
                : () => _setCompareRightIndexForGroup(
                    groupKey,
                    displayIndex + 1,
                    totalCount,
                  );
            return Column(
              children: [
                SizedBox(
                  height: cardHeight,
                  child: Stack(
                    children: [
                      RepaintBoundary(child: _simpleProductCard(product)),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _startCompareRemoveAnimation(product),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showPager)
                  Padding(
                    padding: const EdgeInsets.only(top: pagerTopSpacing),
                    child: SizedBox(
                      height: pagerHeight,
                      child: _buildCompareCardPager(
                        displayIndex: displayIndex,
                        totalCount: totalCount,
                        canPrev: canPrev,
                        canNext: canNext,
                        onPrev: onPrev,
                        onNext: onNext,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Transform.translate(
            offset: const Offset(0, -30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/apple_touch_icon.png',
                  width: 280,
                  height: 280,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: _boldMenuStyle.copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: _subMenuStyle.copyWith(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openCustomMenu,
                  child: Text(
                    "перейдите в каталог",
                    style: _subMenuStyle.copyWith(
                      fontSize: 15,
                      color: const Color(0xFF4A4A4A),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparePage(List<dynamic> items) {
    final products = items.whereType<Map>().toList();
    if (products.isEmpty) {
      return _buildEmptyState(
        title: "Список сравнения пуст",
        subtitle: "Для добавления товаров к сравнению",
      );
    }
    final grouped = _groupCompareProducts(products);
    if (grouped.isEmpty) {
      return _buildEmptyState(
        title: "Список сравнения пуст",
        subtitle: "Для добавления товаров к сравнению",
      );
    }

    final groupKeys = grouped.keys.toList(growable: false);
    final String activeKey =
        (_activeCompareGroupKey != null &&
            grouped.containsKey(_activeCompareGroupKey))
        ? _activeCompareGroupKey!
        : groupKeys.first;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_activeCompareGroupKey != activeKey) {
        setState(() => _activeCompareGroupKey = activeKey);
      }
      _updateCompareStickyVisibility();
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final groupProducts = grouped[activeKey] ?? <Map>[];
    if (groupProducts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompareGroupTabs(groupKeys, activeKey, grouped),
              const SizedBox(height: 12),
              const Text(
                "Список сравнения пуст",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final String rowsKey = _compareCacheKeyForProducts(groupProducts);
    List<Map<String, dynamic>> rows;
    if (rowsKey == _compareRowsKey) {
      rows = _compareRowsCache;
    } else {
      rows = _collectCompareFeatureRows(groupProducts);
      _compareRowsKey = rowsKey;
      _compareRowsCache = rows;
    }

    final indices = _resolveCompareIndicesForGroup(
      activeKey,
      groupProducts.length,
    );
    final int leftIndex = indices.left;
    final int rightIndex = indices.right;
    final bool hasRight = indices.hasRight;
    final bool showSecondColumn = hasRight || groupProducts.length == 1;
    final int layoutColumns = showSecondColumn ? 2 : 1;
    const double compareCenterGap = 1.0;
    final double itemWidth = _compareItemWidthForCount(
      layoutColumns,
      screenWidth,
      labelWidth: 0.0,
      horizontalPadding: 12.0 + (layoutColumns > 1 ? compareCenterGap : 0),
    );
    final List<Map> pageProducts = _compareSelectedProducts(
      groupProducts,
      leftIndex,
      rightIndex,
      hasRight,
    );
    final List<String> pageProductIds = _compareSelectedProductIds(
      groupProducts,
      leftIndex,
      rightIndex,
      hasRight,
    );
    final List<String> pageProductIdsForCells =
        showSecondColumn && pageProductIds.length == 1
        ? [...pageProductIds, ""]
        : pageProductIds;
    final List<int> pageProductIndices = hasRight
        ? [leftIndex, rightIndex]
        : [leftIndex];
    final double totalWidth =
        itemWidth * layoutColumns + (layoutColumns > 1 ? compareCenterGap : 0);

    final List<Widget> compareRows = <Widget>[];
    String? currentGroupTitle;
    List<Map<String, dynamic>> currentFeatures = <Map<String, dynamic>>[];

    void flushGroup() {
      if (currentGroupTitle == null) return;
      final title = currentGroupTitle!;
      final collapseKey = "$activeKey::$title";
      final bool isCollapsed = _compareCollapsedGroups.contains(collapseKey);
      final List<_CompareFeatureRender> features = <_CompareFeatureRender>[];
      for (final row in currentFeatures) {
        final label = row['label'] as String;
        List<String> values = _compareSelectedValues(
          row['values'] as List<String>,
          leftIndex,
          rightIndex,
          hasRight,
        );
        if (showSecondColumn && values.length == 1) {
          values = [values.first, ""];
        }
        final bool hasDiff = hasRight
            ? (values.length > 1 && _compareValuesDiffer(values[0], values[1]))
            : true;
        if (_compareOnlyDifferences && hasRight && !hasDiff) {
          continue;
        }
        final bool highlighted = label.toLowerCase().contains("код производ");
        features.add(
          _CompareFeatureRender(label, values, hasDiff, highlighted),
        );
      }

      if (_compareOnlyDifferences && features.isEmpty) {
        currentGroupTitle = null;
        currentFeatures = <Map<String, dynamic>>[];
        return;
      }

      compareRows.add(
        _buildCompareGroupHeader(
          title,
          totalWidth,
          isCollapsed: isCollapsed,
          onToggle: () {
            setState(() {
              if (_compareCollapsedGroups.contains(collapseKey)) {
                _compareCollapsedGroups.remove(collapseKey);
              } else {
                _compareCollapsedGroups.add(collapseKey);
              }
            });
          },
          headerKey: _compareGroupKeys.putIfAbsent(
            collapseKey,
            () => GlobalKey(),
          ),
        ),
      );

      if (!isCollapsed) {
        int featureRowIndex = 0;
        for (final feature in features) {
          final Color backgroundColor = featureRowIndex.isEven
              ? const Color(0xFFF7F7F7)
              : Colors.white;
          compareRows.add(
            _buildCompareFeatureBlock(
              label: feature.label,
              values: feature.values,
              itemWidth: itemWidth,
              productIds: pageProductIdsForCells,
              totalWidth: totalWidth,
              backgroundColor: backgroundColor,
              showDot: hasRight && feature.hasDiff,
              highlighted: feature.highlighted,
            ),
          );
          featureRowIndex++;
        }
      }

      currentGroupTitle = null;
      currentFeatures = <Map<String, dynamic>>[];
    }

    for (final row in rows) {
      if (row['type'] == 'group') {
        flushGroup();
        currentGroupTitle = row['label'] as String;
        currentFeatures = <Map<String, dynamic>>[];
        continue;
      }
      currentFeatures.add(row);
    }
    flushGroup();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompareGroupTabs(groupKeys, activeKey, grouped),
            const SizedBox(height: 10),
            Column(
              key: _compareHeaderKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                _buildCompareProductsGrid(
                  products: pageProducts,
                  indices: pageProductIndices,
                  totalCount: groupProducts.length,
                  groupKey: activeKey,
                  showSecondColumn: showSecondColumn,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Сравнение характеристик",
                    style: _boldMenuStyle.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompareLabel(
                          "Только различающиеся",
                          fontSize: 14,
                          showDot: true,
                          dotAtEnd: true,
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(
                          () => _compareOnlyDifferences =
                              !_compareOnlyDifferences,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 40,
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: _compareOnlyDifferences
                                ? Colors.black
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 160),
                            alignment: _compareOnlyDifferences
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: compareRows,
                ),
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  "Характеристики загружаются...",
                  style: _subMenuStyle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _compareCacheKeyForProducts(List<Map> products) {
    final ids = products
        .map((p) => p['id']?.toString() ?? "")
        .where((id) => id.isNotEmpty)
        .join(",");
    return "$ids|${_availableFeatures.length}|${_featureValueTextById.length}|$_productFeaturesVersion";
  }

  List<Map<String, dynamic>> _collectCompareFeatureRows(List<Map> products) {
    if (_availableFeatures.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final feature in _availableFeatures) {
      if (feature is! Map) continue;
      final fid = feature['id']?.toString() ?? "";
      final label = feature['name']?.toString() ?? "";
      if (fid.isEmpty || label.isEmpty) continue;
      final values = <String>[];
      bool hasAny = false;
      for (final product in products) {
        final productId = product['id']?.toString() ?? "";
        final value = _getCompareFeatureValue(productId, feature);
        if (value.isNotEmpty) hasAny = true;
        values.add(value);
      }
      if (hasAny) {
        final group = _compareGroupForFeatureName(label);
        grouped.putIfAbsent(group, () => <Map<String, dynamic>>[]).add({
          'type': 'feature',
          'label': label,
          'values': values,
        });
      }
    }
    if (grouped.isEmpty) return <Map<String, dynamic>>[];
    final result = <Map<String, dynamic>>[];
    final added = <String>{};
    for (final group in _compareGroupOrder) {
      final rows = grouped[group];
      if (rows == null || rows.isEmpty) continue;
      result.add({'type': 'group', 'label': group});
      result.addAll(rows);
      added.add(group);
    }
    for (final entry in grouped.entries) {
      if (added.contains(entry.key)) continue;
      result.add({'type': 'group', 'label': entry.key});
      result.addAll(entry.value);
    }
    return result;
  }

  String _resolveComparePrice(Map product) {
    final price = product['price']?.toString() ?? "";
    if (price.isNotEmpty) return price;
    final raw = product['raw_price'];
    final rawValue = (raw is num)
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? "");
    if (rawValue == null) return "";
    return "${_formatPrice(rawValue)} ₽";
  }

  String _getCompareFeatureValue(String productId, Map feature) {
    if (productId.isEmpty) return "";
    final features = _productFeaturesById[productId];
    if (features == null || features.isEmpty) return "";
    final fid = feature['id']?.toString() ?? "";
    String? code = feature['code']?.toString();
    if (code == null || code.isEmpty) {
      code = _featureCodeById[fid];
    }

    dynamic rawValue;
    if (code != null && code.isNotEmpty && features.containsKey(code)) {
      rawValue = features[code];
    } else if (fid.isNotEmpty && features.containsKey(fid)) {
      rawValue = features[fid];
    }

    if (rawValue == null) return "";
    final values = _normalizeFeatureValues(rawValue);
    if (values.isEmpty) return "";
    final textMap = _featureValueTextById[fid];
    final resolved = values
        .map((value) {
          final mapped = textMap?[value];
          return (mapped == null || mapped.isEmpty) ? value : mapped;
        })
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return resolved.join(", ");
  }

  Widget _buildCompareRow({
    Key? rowKey,
    required String label,
    required List<Widget> cells,
    required double labelWidth,
    required double itemWidth,
    List<String>? productIds,
    bool isHeader = false,
    bool showCellBorder = true,
    double interCellGap = 0,
    EdgeInsetsGeometry? cellPadding,
    EdgeInsetsGeometry? labelPadding,
    TextStyle? labelStyleOverride,
    Widget? labelWidget,
    Color? centerDividerColor,
    EdgeInsetsGeometry? centerDividerPadding,
  }) {
    final labelStyle =
        labelStyleOverride ??
        (isHeader
            ? _boldMenuStyle.copyWith(fontSize: 13)
            : _boldSubMenuStyle.copyWith(fontSize: 13));
    final Widget labelChild = labelWidget ?? Text(label, style: labelStyle);
    final bool showLabelCell = labelWidth > 0.5;
    return Row(
      key: rowKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabelCell)
          _buildCompareCell(
            width: labelWidth,
            isHeader: isHeader,
            showBorder: showCellBorder,
            padding: labelPadding ?? cellPadding,
            child: labelChild,
          ),
        for (int i = 0; i < cells.length; i++) ...[
          if (i > 0 && interCellGap > 0)
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              width:
                  (productIds != null &&
                      i < productIds.length &&
                      _compareRemovingIds.contains(productIds[i]))
                  ? 0
                  : interCellGap,
              child: centerDividerColor == null
                  ? null
                  : Padding(
                      padding: centerDividerPadding ?? EdgeInsets.zero,
                      child: Container(color: centerDividerColor),
                    ),
            ),
          _buildCompareCell(
            width:
                (productIds != null &&
                    i < productIds.length &&
                    _compareRemovingIds.contains(productIds[i]))
                ? 0
                : itemWidth,
            isHeader: isHeader,
            isCollapsed:
                productIds != null &&
                i < productIds.length &&
                _compareRemovingIds.contains(productIds[i]),
            showBorder: showCellBorder,
            padding: cellPadding,
            child: cells[i],
          ),
        ],
      ],
    );
  }

  Widget _buildCompareCell({
    required double width,
    required Widget child,
    bool isHeader = false,
    bool isCollapsed = false,
    EdgeInsetsGeometry? padding,
    bool showBorder = true,
  }) {
    final resolvedPadding = isCollapsed
        ? EdgeInsets.zero
        : (padding ?? const EdgeInsets.all(8));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      width: width,
      padding: resolvedPadding,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        border: (showBorder && !isCollapsed)
            ? Border.all(color: Colors.grey.shade200)
            : null,
      ),
      child: isCollapsed ? const SizedBox.shrink() : child,
    );
  }

  Widget _buildCompareCompactArrowButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: Icon(icon, size: 20, color: Colors.black54)),
      ),
    );
  }

  Widget _buildCompareCompactProductHeader({
    required Map product,
    required double itemWidth,
    required double imageWidth,
    required double imageHeight,
    required double arrowSize,
    required double sidePadding,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required bool showPrev,
    required bool showNext,
  }) {
    final name = product['name']?.toString() ?? "";
    final price = _resolveComparePrice(product);
    final imageUrl = _resolveCompareImage(product);
    return SizedBox(
      width: itemWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 2),
            child: Row(
              mainAxisAlignment: (showPrev || showNext)
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                if (showPrev)
                  _buildCompareCompactArrowButton(
                    icon: Icons.chevron_left,
                    size: arrowSize,
                    onTap: onPrev,
                  ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: imageWidth,
                    height: imageHeight,
                    child: imageUrl.isEmpty
                        ? Container(color: Colors.grey.shade50)
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey.shade50),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.broken_image, size: 18),
                          ),
                  ),
                ),
                if (showNext)
                  _buildCompareCompactArrowButton(
                    icon: Icons.chevron_right,
                    size: arrowSize,
                    onTap: onNext,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sidePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? "-" : name,
                  style: _cardNameStyle.copyWith(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    price.isEmpty ? "-" : price,
                    style: _cardPriceStyle.copyWith(fontSize: 14),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareStickyOverlay() {
    if (!_isNativeCategoryPage || _nativeCategory != "compare") {
      return const SizedBox.shrink();
    }
    final allProducts = _getActiveNativeList().whereType<Map>().toList();
    if (allProducts.isEmpty) {
      return const SizedBox.shrink();
    }
    final grouped = _groupCompareProducts(allProducts);
    if (grouped.isEmpty) {
      return const SizedBox.shrink();
    }
    final String groupKey =
        (_activeCompareGroupKey != null &&
            grouped.containsKey(_activeCompareGroupKey))
        ? _activeCompareGroupKey!
        : grouped.keys.first;
    final products = grouped[groupKey] ?? <Map>[];
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }
    const labelWidth = 0.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final indices = _resolveCompareIndicesForGroup(groupKey, products.length);
    final int leftIndex = indices.left;
    final int rightIndex = indices.right;
    final bool hasRight = indices.hasRight;
    final bool showSecondColumn = hasRight || products.length == 1;
    final int layoutColumns = showSecondColumn ? 2 : 1;
    const double compactOuterPadding = 6;
    const double compactCenterGap = 1;
    const double compactSidePadding = 8;
    const double arrowSize = 30;
    final double horizontalPadding =
        compactOuterPadding * 2 + (layoutColumns > 1 ? compactCenterGap : 0);
    final double itemWidth = _compareItemWidthForCount(
      layoutColumns,
      screenWidth,
      labelWidth: labelWidth,
      horizontalPadding: horizontalPadding,
    );
    final List<Map> pageProducts = _compareSelectedProducts(
      products,
      leftIndex,
      rightIndex,
      hasRight,
    );
    final List<String> pageProductIds = _compareSelectedProductIds(
      products,
      leftIndex,
      rightIndex,
      hasRight,
    );
    final List<String> pageProductIdsForCells =
        showSecondColumn && pageProductIds.length == 1
        ? [...pageProductIds, ""]
        : pageProductIds;
    final bool showArrows = products.length > 2;
    final bool reserveArrowSpace = showSecondColumn;
    final double rawImageWidth = reserveArrowSpace
        ? (itemWidth - (arrowSize * 2) - (compactSidePadding * 2))
        : (itemWidth - (compactSidePadding * 2));
    final double imageWidth = (rawImageWidth * 0.78).clamp(46.0, rawImageWidth);
    final double imageHeight = imageWidth * 1.2;
    final double compactHeight = imageHeight + 72;
    final List<Widget> cells = [];
    for (int i = 0; i < pageProducts.length; i++) {
      final product = pageProducts[i];
      final bool isLeft = i == 0;
      final int displayIndex = isLeft ? leftIndex : rightIndex;
      final VoidCallback onPrev = isLeft
          ? () => _setCompareLeftIndexForGroup(
              groupKey,
              displayIndex - 1,
              products.length,
            )
          : () => _setCompareRightIndexForGroup(
              groupKey,
              displayIndex - 1,
              products.length,
            );
      final VoidCallback onNext = isLeft
          ? () => _setCompareLeftIndexForGroup(
              groupKey,
              displayIndex + 1,
              products.length,
            )
          : () => _setCompareRightIndexForGroup(
              groupKey,
              displayIndex + 1,
              products.length,
            );
      cells.add(
        _buildCompareCompactProductHeader(
          product: product,
          itemWidth: itemWidth,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          arrowSize: arrowSize,
          sidePadding: compactSidePadding,
          onPrev: onPrev,
          onNext: onNext,
          showPrev: showArrows,
          showNext: showArrows,
        ),
      );
    }
    if (showSecondColumn && pageProducts.length == 1) {
      cells.add(
        _buildCompareCompactAddPlaceholder(
          width: itemWidth,
          height: compactHeight,
          onTap: () => _openCompareGroupCategory(groupKey),
          sidePadding: compactSidePadding,
        ),
      );
    }
    while (cells.length < layoutColumns) {
      cells.add(const SizedBox.shrink());
    }
    final double totalWidth =
        itemWidth * layoutColumns + (layoutColumns > 1 ? compactCenterGap : 0);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_isCompareStickyVisible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          opacity: _isCompareStickyVisible ? 1 : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            offset: _isCompareStickyVisible
                ? Offset.zero
                : const Offset(0, -0.1),
            child: Material(
              color: Colors.white,
              elevation: 3,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SizedBox(
                  height: compactHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: compactOuterPadding,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.translate(
                        offset: const Offset(0.5, 0),
                        child: SizedBox(
                          width: totalWidth,
                          child: Stack(
                            children: [
                              _buildCompareRow(
                                label: "",
                                labelWidget: const SizedBox.shrink(),
                                cells: cells,
                                labelWidth: labelWidth,
                                itemWidth: itemWidth,
                                productIds: pageProductIdsForCells,
                                isHeader: true,
                                showCellBorder: false,
                                interCellGap: layoutColumns > 1
                                    ? compactCenterGap
                                    : 0,
                                cellPadding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 6,
                                ),
                                labelPadding: EdgeInsets.zero,
                                labelStyleOverride: _boldSubMenuStyle.copyWith(
                                  fontSize: 12,
                                ),
                                centerDividerColor: Colors.grey.shade200,
                                centerDividerPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveCompareImage(Map product) {
    final rawImages = product['images'];
    if (rawImages is List) {
      for (final img in rawImages) {
        final value = img?.toString() ?? "";
        if (value.isNotEmpty) return value;
      }
    }
    final image = product['image']?.toString() ?? "";
    return image;
  }

  Widget _buildMenSubcategoriesSliver() {
    final children = _getCategoryChildren(_menBagsCategoryId);
    if (children.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox(height: 10));
    }
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 136,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          itemCount: children.length,
          itemBuilder: (context, index) {
            final cat = children[index];
            final name = cat['name']?.toString() ?? "";
            final count = cat['count']?.toString() ?? "";
            final slug = _getCategorySlug(cat);
            final catId = cat['id']?.toString() ?? "";
            final visibleCount = (catId.isNotEmpty)
                ? CategoryCounterService.getCount(catId)
                : null;
            final assetPath = 'assets/categories/$slug.png';
            final double cardWidth =
                (MediaQuery.of(context).size.width - 20) / 1.5;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () => _navigateToApiCategory(cat),
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          assetPath,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            color: Colors.grey.shade200,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _subMenuStyle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (visibleCount != null)
                              Text(
                                _formatProductCount(visibleCount),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _subMenuStyle.copyWith(fontSize: 13),
                              )
                            else if (count.isNotEmpty)
                              Text(
                                _formatProductCount(count),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _subMenuStyle.copyWith(fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _loadMoreActiveNativeIfNeeded() {
    final key = _nativeCategory;
    if (_isFilterLoading || _isLocalSortLoading || _isLocalFilterLoading) {
      return;
    }
    if (_nativeIsLoadingMore[key] == true) return;
    if (_nativeHasMore[key] == false) return;
    if (_nativeScrollController.hasClients) {
      final list = _getActiveNativeList();
      if (list.isNotEmpty) {
        final rows = (list.length / 2).ceil();
        final rowExtent = _estimateNativeRowExtent();
        final realExtent = rows * rowExtent;
        final pos = _nativeScrollController.position;
        final double speed = _isUserScrolling ? _scrollVelocityPxPerSec : 0.0;
        final int speedTier = (speed / 1500).floor().clamp(0, 3);
        final int prefetchScreens = 2 + (speedTier * 2);
        final prefetchDistance = pos.viewportDimension * prefetchScreens;
        if (pos.pixels + pos.viewportDimension <
            realExtent - prefetchDistance) {
          return;
        }
      }
    }
    final customId = _nativeCustomCategoryIdByKey[key];
    if (customId != null && customId.isNotEmpty) {
      _fetchNativeCategory(key: key, categoryId: customId, reset: false);
      return;
    }
    switch (key) {
      case "belt":
        _fetchBeltBags(reset: false);
        break;
      case "shoulder":
        _fetchShoulderBags(reset: false);
        break;
      case "tablet":
        _fetchTabletBags(reset: false);
        break;
      case "business":
        _fetchBusinessBags(reset: false);
        break;
      case "women":
        _fetchWomenBags(reset: false);
        break;
      case "travel":
        _fetchTravelBags(reset: false);
        break;
      case "backpacks":
        _fetchBackpacks(reset: false);
        break;
      case "belts":
        _fetchBelts(reset: false);
        break;
      case "wallets":
        _fetchWallets(reset: false);
        break;
      case "accessories":
        _fetchAccessories(reset: false);
        break;
      default:
        _fetchMenBags(reset: false);
    }
  }

  Widget _buildNativeLoadMoreSliver() {
    final key = _nativeCategory;
    final bool showIndicator =
        _nativeShowLoadingIndicator[key] == true ||
        _isLocalSortLoading ||
        _isLocalFilterLoading;
    if (!showIndicator) {
      return const SliverToBoxAdapter(child: SizedBox(height: 12));
    }
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(bottom: 16, top: 4),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black26,
            ),
          ),
        ),
      ),
    );
  }

  String _galleryRequestKey(String categoryKey, String productId) {
    return "$categoryKey::$productId";
  }

  Set<String> _collectAllLoadedProductIds() {
    final ids = <String>{};
    for (final list in _nativeLists.values) {
      for (final item in list) {
        if (item is! Map) continue;
        final id = item['id']?.toString() ?? "";
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
  }

  void _trimGalleryCaches() {
    if (_galleryCache.length <= _maxGalleryCacheEntries &&
        _galleryVersionById.length <= _maxGalleryNotifierEntries) {
      return;
    }
    final activeIds = _collectAllLoadedProductIds();
    if (_galleryCache.length > _maxGalleryCacheEntries) {
      final keys = List<String>.from(_galleryCache.keys);
      for (final key in keys) {
        if (_galleryCache.length <= _maxGalleryCacheEntries) break;
        if (activeIds.contains(key)) continue;
        _galleryCache.remove(key);
      }
    }
    if (_galleryVersionById.length > _maxGalleryNotifierEntries) {
      final keys = List<String>.from(_galleryVersionById.keys);
      for (final key in keys) {
        if (_galleryVersionById.length <= _maxGalleryNotifierEntries) break;
        if (activeIds.contains(key)) continue;
        _galleryVersionById.remove(key)?.dispose();
      }
    }
  }

  void _putGalleryCache(String productId, List<String> gallery) {
    if (productId.isEmpty || gallery.isEmpty) return;
    if (_galleryCache.containsKey(productId)) {
      _galleryCache.remove(productId);
    }
    _galleryCache[productId] = gallery;
    _trimGalleryCaches();
  }

  ValueNotifier<int> _getGalleryNotifier(String productId) {
    final bool wasMissing = !_galleryVersionById.containsKey(productId);
    final notifier = _galleryVersionById.putIfAbsent(
      productId,
      () => ValueNotifier<int>(0),
    );
    if (wasMissing) _trimGalleryCaches();
    return notifier;
  }

  ValueNotifier<int> _getFavoriteNotifier(String productId) {
    return _favoriteVersionById.putIfAbsent(
      productId,
      () => ValueNotifier<int>(0),
    );
  }

  bool _isFavorite(String productId) {
    return productId.isNotEmpty && _favoriteIds.contains(productId);
  }

  ValueNotifier<int> _getCompareNotifier(String productId) {
    return _compareVersionById.putIfAbsent(
      productId,
      () => ValueNotifier<int>(0),
    );
  }

  bool _isCompared(String productId) {
    return productId.isNotEmpty && _compareIds.contains(productId);
  }

  void _scheduleGalleryNotifyFlush() {
    if (_pendingGalleryNotifyIds.isEmpty) return;
    if (_galleryNotifyFlushTimer?.isActive == true) return;
    _galleryNotifyFlushTimer = Timer(const Duration(milliseconds: 32), () {
      _galleryNotifyFlushTimer = null;
      _flushPendingGalleryNotifies();
    });
  }

  void _flushPendingGalleryNotifies() {
    if (_pendingGalleryNotifyIds.isEmpty) return;
    if (_isUserScrolling || _scrollingNotifier.value) return;
    final visibleIds = _scrollVisibleMainImageIds.value;
    if (visibleIds.isEmpty) {
      _pendingGalleryNotifyIds.clear();
      return;
    }
    final ids = _pendingGalleryNotifyIds
        .where((id) => visibleIds.contains(id))
        .toList(growable: false);
    _pendingGalleryNotifyIds.clear();
    if (ids.isEmpty) return;
    if (_isInBuildPhase()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final id in ids) {
          final notifier = _galleryVersionById[id];
          if (notifier != null) notifier.value++;
        }
      });
      return;
    }
    for (final id in ids) {
      final notifier = _galleryVersionById[id];
      if (notifier != null) notifier.value++;
    }
  }

  void _notifyGalleryUpdated(String productId) {
    if (productId.isEmpty) return;
    final notifier = _galleryVersionById[productId];
    if (_isUserScrolling || _scrollingNotifier.value) {
      _pendingGalleryNotifyIds.add(productId);
      return;
    }
    if (notifier != null) {
      if (_isInBuildPhase()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _galleryVersionById[productId] != null) {
            _galleryVersionById[productId]!.value++;
          }
        });
        return;
      }
      notifier.value++;
    }
  }

  bool _isGalleryRequestBusy(String categoryKey, String productId) {
    final key = _galleryRequestKey(categoryKey, productId);
    return _queuedGalleryRequestKeys.contains(key) ||
        _galleryRequestsInFlight.contains(key);
  }

  bool _canEnqueueGalleryRequest(String categoryKey, String productId) {
    if (productId.isEmpty) return false;
    if (_isGalleryNoImagesCooldown(productId)) return false;
    if (_galleryCache.containsKey(productId)) return false;
    return !_isGalleryRequestBusy(categoryKey, productId);
  }

  void _markGalleryRequestInFlight(String categoryKey, String productId) {
    if (productId.isEmpty) return;
    final key = _galleryRequestKey(categoryKey, productId);
    _queuedGalleryRequestKeys.remove(key);
    _galleryRequestsInFlight.add(key);
  }

  void _markGalleryRequestComplete(String categoryKey, String productId) {
    if (productId.isEmpty) return;
    final key = _galleryRequestKey(categoryKey, productId);
    _galleryRequestsInFlight.remove(key);
  }

  void _enqueueGalleryRequests(
    List<dynamic> products,
    int startIndex,
    String categoryKey, {
    bool priority = false,
  }) {
    final List<_GalleryRequest> requests = [];
    for (int i = 0; i < products.length; i++) {
      final item = products[i];
      if (item is! Map) continue;
      final id = item['id']?.toString() ?? "";
      if (!_canEnqueueGalleryRequest(categoryKey, id)) continue;
      final key = _galleryRequestKey(categoryKey, id);
      _queuedGalleryRequestKeys.add(key);
      requests.add(
        _GalleryRequest(
          productId: id,
          index: startIndex + i,
          categoryKey: categoryKey,
        ),
      );
    }
    if (requests.isEmpty) return;
    if (priority) {
      _pendingGalleryRequests.insertAll(0, requests);
    } else {
      _pendingGalleryRequests.addAll(requests);
    }
  }

  void _enqueuePriorityGalleryRequests(
    List<String> productIds,
    String categoryKey,
  ) {
    final List<_GalleryRequest> requests = [];
    for (final id in productIds) {
      if (id.isEmpty) continue;
      if (_galleryCache.containsKey(id)) continue;
      final key = _galleryRequestKey(categoryKey, id);
      if (_galleryRequestsInFlight.contains(key)) continue;
      if (_queuedGalleryRequestKeys.contains(key)) {
        final existingIndex = _pendingGalleryRequests.indexWhere(
          (req) => req.categoryKey == categoryKey && req.productId == id,
        );
        if (existingIndex != -1) {
          requests.add(_pendingGalleryRequests.removeAt(existingIndex));
          continue;
        } else {
          _queuedGalleryRequestKeys.remove(key);
        }
      }
      _queuedGalleryRequestKeys.add(key);
      requests.add(
        _GalleryRequest(productId: id, index: -1, categoryKey: categoryKey),
      );
    }
    if (requests.isNotEmpty) {
      _pendingGalleryRequests.insertAll(0, requests);
    }
  }

  void _startGalleryProcessing() {
    // Если уже обрабатываем или нет запросов, не запускаем
    if (_isProcessingGalleries ||
        _pendingGalleryRequests.isEmpty ||
        _isUserScrolling) {
      return;
    }

    // Отменяем предыдущий таймер
    if (_galleryProcessingTimer?.isActive == true) return;
    _galleryProcessingTimer?.cancel();

    // Запускаем обработку с небольшой задержкой
    _galleryProcessingTimer = Timer(const Duration(milliseconds: 50), () {
      _processGalleryBatch();
    });
  }

  Future<void> _processGalleryBatch() async {
    if (_pendingGalleryRequests.isEmpty || _isProcessingGalleries) return;

    _isProcessingGalleries = true;

    try {
      // Берем только часть запросов (например, первые 5-8) для обработки порциями
      const batchSize = 6;
      final batch = _pendingGalleryRequests.length > batchSize
          ? _pendingGalleryRequests.sublist(0, batchSize)
          : List<_GalleryRequest>.from(_pendingGalleryRequests);

      // Удаляем обработанные запросы из очереди
      _pendingGalleryRequests.removeRange(0, batch.length);
      for (final req in batch) {
        _markGalleryRequestInFlight(req.categoryKey, req.productId);
      }

      // Группируем запросы по категориям
      final Map<String, List<_GalleryRequest>> requestsByCategory = {};
      for (final req in batch) {
        requestsByCategory.putIfAbsent(req.categoryKey, () => []).add(req);
      }

      // Выполняем запросы для каждой категории
      for (final entry in requestsByCategory.entries) {
        final categoryRequests = entry.value;

        final tasks = categoryRequests.map((req) {
          return _fetchGallerySilentForList(
            req.productId,
            req.index,
            req.categoryKey,
          ).catchError((e, st) {
            debugPrint("Gallery batch error: $e");
            if (kDebugMode) debugPrint("$st");
          });
        }).toList();
        await Future.wait(tasks);
      }

      // Если еще есть запросы, планируем следующую порцию
      if (_pendingGalleryRequests.isNotEmpty && !_isUserScrolling) {
        _galleryProcessingTimer = Timer(const Duration(milliseconds: 150), () {
          _isProcessingGalleries = false;
          _processGalleryBatch();
        });
      } else {
        _isProcessingGalleries = false;
      }
    } catch (e) {
      _isProcessingGalleries = false;
      debugPrint("Gallery processing error: $e");
    }
  }

  Widget _buildDiscountedProductsSection() {
    final filteredProducts = _discountedProducts
        .where((p) => p['type'] == _selectedDiscountType)
        .toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final discountCardWidth = (screenWidth - 40) / 1.4;
    final discountImageHeight = discountCardWidth * 4 / 3;
    final discountCardsHeight = (discountImageHeight + 152)
        .clamp(470.0, 560.0)
        .toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: const Color(0xFFF8F8F8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(
              "Товар со скидкой",
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 22,
                fontWeight: FontWeight.normal,
                color: Colors.black,
                letterSpacing: 0,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _discountTab("до 50 % для мужчин", "men"),
                  const SizedBox(width: 8),
                  _discountTab("до 50 % для женщин", "women"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: discountCardsHeight,
            child: ListView.builder(
              controller: _discountScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                return _discountedProductCard(filteredProducts[index]);
              },
            ),
          ),
          const SizedBox(height: 30), // Увеличил отступ кнопки от карточек
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (_selectedDiscountType == "men") {
                    _openNativeCategoryById(
                      key: "discount_men",
                      categoryId: "156",
                      title: _getCategoryTitleById(
                        "156",
                        "до 50% скидка для мужчин",
                      ),
                    );
                  } else {
                    _openNativeCategoryById(
                      key: "discount_women",
                      categoryId: "157",
                      title: _getCategoryTitleById(
                        "157",
                        "до 50% скидка для женщин",
                      ),
                    );
                  }
                },
                child: Container(
                  width: double.infinity, // На всю ширину
                  height: 38, // По высоте уже
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Все товары",
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _discountTab(String title, String type) {
    bool isActive = _selectedDiscountType == type;
    return GestureDetector(
      onTap: () {
        if (_selectedDiscountType == type) return;
        setState(() => _selectedDiscountType = type);
        _resetDiscountScroll();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBannerScroll() {
    if (_promoBanners.isEmpty) return const SizedBox.shrink();
    double screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = screenWidth * 0.63;

    return Container(
      height: itemWidth * 0.89,
      margin: const EdgeInsets.only(
        bottom: 20,
      ), // Унифицированный отступ 20 вниз
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6), // Уменьшен отступ
        itemCount: _promoBanners.length,
        itemBuilder: (context, index) {
          final item = _promoBanners[index];
          return RepaintBoundary(
            child: GestureDetector(
              onTap: () {
                if (item['link'] != null) {
                  _navigateToSimple(item['title'] ?? "Акция", item['link']);
                }
              },
              child: Container(
                width: itemWidth,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: item['image'] ?? "",
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.black12),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 25),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Colors.grey.shade200,
        ), // Та же серая обводка, что и в контактах
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(
              10,
            ), // Чуть меньше, чем у рамки, для красоты
            child: CachedNetworkImage(
              imageUrl: _aboutImageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 200,
                color: Colors.grey.shade100,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.black12),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Text(
            _aboutTitle,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 22,
              fontWeight: FontWeight.normal,
              color: Colors.black,
              height: 1.1, // Уменьшил с 1.2
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 15),
          if (_aboutDescription.isEmpty) ...[
            _aboutText(
              'Ищете идеальную кожаную сумку или аксессуар?',
              isBold: true,
            ),
            _aboutText(
              'Вам больше не придется выбирать между стилем, качеством и практичностью. Мы уже нашли идеальный баланс для вас — HOZYAIN-BARIN.RU',
            ),
            _aboutText(
              'В «Хозяин Барин» мы создаём не просто аксессуары, а надёжных партнёров в создании безупречного образа.',
            ),
          ] else
            ..._aboutDescription.map((item) {
              if (item is Map) {
                return _aboutText(
                  item['text']?.toString() ?? "",
                  isBold: item['is_bold'] == true,
                );
              }
              return _aboutText(item.toString());
            }),
        ],
      ),
    );
  }

  Widget _aboutText(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          // Темно-серый для жирного, обычный серый для остального
          color: isBold ? Colors.grey.shade800 : Colors.black54,
          height: 1.1, // Уменьшил межстрочное расстояние (было 1.3)
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildMainBannerSlider() {
    double screenWidth = MediaQuery.of(context).size.width;

    if (_apiBanners.isEmpty) {
      // Резервируем место под слайдер, чтобы не было прыжков при загрузке
      return Container(
        width: screenWidth,
        height: screenWidth,
        margin: const EdgeInsets.only(bottom: 25),
        color: Colors.grey.shade50,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.black12,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      child: CarouselSlider(
        options: CarouselOptions(
          height: screenWidth,
          viewportFraction: 1.0,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 5),
        ),
        items: _apiBanners.map((item) {
          return GestureDetector(
            onTap: () {
              if (item['link'] != null) {
                _navigateToSimple(item['title'] ?? "Акция", item['link']);
              }
            },
            child: Container(
              width: screenWidth,
              color: Colors.white,
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: item['image'] ?? "",
                    width: screenWidth,
                    height: screenWidth,
                    fit: BoxFit.fitWidth,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.black26,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                  if (item['title'] != null &&
                      item['title'].toString().isNotEmpty)
                    Positioned(
                      left: 20,
                      top: 40,
                      child: Text(
                        item['title'].toString().toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.0, // Уменьшил с 1.1
                          letterSpacing: 0,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 10,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryScroll() {
    const orderedIds = ["16", "19", "4", "143", "14", "84", "8", "101"];
    final byId = <String, dynamic>{};
    for (final cat in _apiCategories) {
      if (cat is! Map) continue;
      final id = cat['id']?.toString();
      if (id == null || id.isEmpty) continue;
      byId[id] = cat;
    }
    final filtered = orderedIds
        .map((id) => byId[id])
        .where((cat) => cat != null)
        .toList();
    double screenWidth = MediaQuery.of(context).size.width;
    double gap = 10.0;
    double sidePadding = 10.0;
    double cardWidth = (screenWidth - (sidePadding * 2) - gap) / 2;

    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 25),
      color: Colors.white,
      child: _isMenuLoading && filtered.isEmpty
          ? ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              itemCount: 4,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(right: gap),
                child: Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                ),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == filtered.length - 1 ? 0 : gap,
                  ),
                  child: RepaintBoundary(
                    child: _categoryCard(filtered[index], cardWidth),
                  ),
                );
              },
            ),
    );
  }

  Widget _categoryCard(dynamic cat, double width) {
    return GestureDetector(
      onTap: () => _navigateToApiCategory(cat),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  "assets/categories/${cat['url'].toString()}.png",
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.shopping_bag_outlined,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
              child: Text(
                cat['name'].toString(),
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _navBtn('assets/images/menu.svg', () => _openCustomMenu()),
        GestureDetector(
          onTap: _goHome,
          child: Image.asset('assets/images/logo.png', height: 28),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _navBtn(
              'assets/images/search.svg',
              () => _showSearchMenu(context),
              hPadding: 10,
            ),
            _navBtn(
              'assets/images/phone.svg',
              () => _showContactsMenu(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            _goBackFromCategory();
          },
        ),
        Expanded(
          child: Text(
            _pageTitle,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_isNativeCategoryPage &&
            _nativeCategory != "wishlist" &&
            _nativeCategory != "compare" &&
            _nativeCategory != "cart")
          _navBtnIcon(
            Icons.filter_list,
            () => _showFilterMenu(context),
            hPadding: 10,
          ),
        if (_isNativeCategoryPage && _nativeCategory == "compare")
          _navBtnIcon(Icons.more_vert, _showCompareSectionsMenu, hPadding: 10),
        if (_isNativeCategoryPage &&
            _nativeCategory != "compare" &&
            _nativeCategory != "cart")
          _navBtnIcon(Icons.sort, () => _showSortMenu(context), hPadding: 10),
        if (_isNativeCategoryPage && _nativeCategory == "wishlist")
          _navBtnIcon(Icons.delete_outline, _clearFavorites, hPadding: 10),
        if (_isNativeCategoryPage && _nativeCategory == "cart")
          const SizedBox(width: 48),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width,
      backgroundColor: Colors.white,
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 5, 10, 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/images/logo.png', height: 28),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.black87),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: _isMenuLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        const SizedBox(height: 10),
                        ..._apiCategories.map((cat) => _buildCategoryItem(cat)),
                        const SizedBox(height: 15),
                        Container(
                          height: 1,
                          color: Colors.black87,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            "Персонализация",
                            textAlign: TextAlign.center,
                            style: _boldMenuStyle,
                          ),
                        ),
                        Container(
                          height: 1,
                          color: Colors.black87,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        const SizedBox(height: 10),
                        _menuRow("О компании", "/o-kompanii/"),
                        _menuRow("АДРЕСА | КОНТАТЫ", "/adryesa--kontakty/"),
                        _menuRow("Гарантия", "/garantiya/"),
                        _menuRow(
                          "Политика конфиденциальности",
                          "/politika-konfidentsialnosti/",
                        ),
                        _menuRow("Доставка и оплата", "/dostavka-oplata/"),
                        _menuRow(
                          "Система лояльности",
                          "/novaya-bonusnaya-sistyema/",
                        ),
                        _menuRow("Отзывы и предложения", "/otzyvy/"),
                        _menuRow(
                          "Персонализация и тиснение вещей",
                          "/personalizatsiya-i-tesnenie-veshchey/",
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey.shade100, thickness: 8),
                        _profileRow(
                          Icons.person_outline,
                          "Личный кабинет",
                          "/my/",
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _cartCountNotifier,
                          builder: (context, count, _) {
                            final badge = count > 0 ? count.toString() : "";
                            return _profileRow(
                              Icons.shopping_cart_outlined,
                              "Корзина",
                              "/cart/",
                              badge: badge,
                            );
                          },
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _compareCountNotifier,
                          builder: (context, count, _) {
                            final badge = count > 0 ? count.toString() : "";
                            return _profileRow(
                              Icons.bar_chart_outlined,
                              "Сравнение",
                              "/compare/",
                              badge: badge,
                            );
                          },
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _wishCountNotifier,
                          builder: (context, count, _) {
                            final badge = count > 0 ? count.toString() : "";
                            return _profileRow(
                              Icons.favorite_border,
                              "Избранное",
                              "/search/?wishlist=true",
                              badge: badge,
                            );
                          },
                        ),
                        Divider(color: Colors.grey.shade100, thickness: 8),
                        _buildSimpleContacts(),
                        const SizedBox(height: 30),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(dynamic cat) {
    var rawChildren = cat['categories'] ?? cat['children'];
    List<dynamic> children = (rawChildren is List)
        ? rawChildren.where((sub) => sub['status'].toString() != "0").toList()
        : [];
    String catId = cat['id'].toString();
    bool isExpanded = _expandedCategoryId == catId;

    return Column(
      children: [
        _menuRow(
          cat['name'].toString(),
          "",
          hasChildren: children.isNotEmpty,
          isExpanded: isExpanded,
          onTap: () {
            if (children.isNotEmpty) {
              setState(() => _expandedCategoryId = isExpanded ? null : catId);
            } else {
              _navigateToApiCategory(cat);
            }
          },
          onExpand: () =>
              setState(() => _expandedCategoryId = isExpanded ? null : catId),
        ),
        if (isExpanded)
          Column(
            children: [
              _menuRow(
                "Все товары",
                "",
                isSub: true,
                isBold: true,
                onTap: () => _navigateToApiCategory(cat),
              ),
              ...children.map(
                (sub) => _menuRow(
                  sub['name'].toString(),
                  "",
                  isSub: true,
                  onTap: () => _navigateToApiCategory(sub),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _menuRow(
    String title,
    String path, {
    bool isSub = false,
    bool isBold = false,
    bool hasChildren = false,
    bool isExpanded = false,
    VoidCallback? onExpand,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () => _navigateToSimple(title, path),
      child: Padding(
        padding: EdgeInsets.only(
          left: isSub ? 35 : 25,
          right: 20,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: isSub
                    ? (isBold ? _boldSubMenuStyle : _subMenuStyle)
                    : (isBold ? _boldMenuStyle : _menuStyle),
              ),
            ),
            if (hasChildren)
              GestureDetector(
                onTap: onExpand,
                child: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 22,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(
    IconData icon,
    String title,
    String path, {
    String? badge,
  }) {
    return InkWell(
      onTap: () => _navigateToSimple(title, path),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 12, 20, 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.black87),
            const SizedBox(width: 15),
            Expanded(child: Text(title, style: _menuStyle)),
            if (badge != null && badge != "0" && badge != "")
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar({bool showTopBorder = true}) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        border: showTopBorder
            ? Border(top: BorderSide(color: Colors.grey.shade200, width: 1))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(
            'assets/images/nav_catalog.svg',
            'Каталог',
            () => _openCustomMenu(),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _compareCountNotifier,
            builder: (context, count, _) {
              final badge = count > 0 ? count.toString() : "";
              return _navItem(
                'assets/images/nav_compare.svg',
                'Сравнение',
                () => _navigateToSimple("Сравнение", "/compare/"),
                badge: badge,
              );
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: _wishCountNotifier,
            builder: (context, count, _) {
              final badge = count > 0 ? count.toString() : "";
              return _navItem(
                'assets/images/nav_wishlist.svg',
                'Избранное',
                () => _navigateToSimple("Избранное", "/search/?wishlist=true"),
                badge: badge,
              );
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: _cartCountNotifier,
            builder: (context, count, _) {
              final badge = count > 0 ? count.toString() : "";
              return _navItem(
                'assets/images/nav_cart.svg',
                'Корзина',
                () => _navigateToSimple("Корзина", "/cart/"),
                badge: badge,
              );
            },
          ),
          _navItem(
            'assets/images/nav_profile.svg',
            'Войти',
            () => _navigateToSimple("Вход", "/signup/"),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    String asset,
    String label,
    VoidCallback onTap, {
    String? badge,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(asset, height: 23),
                if (badge != null && badge != "0" && badge != "")
                  Positioned(
                    right: -8,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 9,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(String icon, VoidCallback onTap, {double hPadding = 12}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 12),
        child: SvgPicture.asset(
          icon,
          height: 18,
          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _navBtnIcon(
    IconData icon,
    VoidCallback onTap, {
    double hPadding = 12,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 12),
        child: Icon(icon, size: 22, color: Colors.black),
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _buildBottomSheetHandle(),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Center(
                child: Text("Сортировка", style: _modalHeaderStyle),
              ),
            ),
            Container(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            ListTile(
              leading: Icon(
                Icons.sort,
                color: _currentSort == "default" ? Colors.blue : Colors.black,
              ),
              title: Text(
                "По умолчанию",
                style: TextStyle(
                  color: _currentSort == "default" ? Colors.blue : Colors.black,
                ),
              ),
              onTap: () {
                _applySort("default");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.new_releases_outlined,
                color: _currentSort == "newest" ? Colors.blue : Colors.black,
              ),
              title: Text(
                "Новинки",
                style: TextStyle(
                  color: _currentSort == "newest" ? Colors.blue : Colors.black,
                ),
              ),
              onTap: () {
                _applySort("newest");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.percent,
                color: _currentSort == "discount" ? Colors.blue : Colors.black,
              ),
              title: Text(
                "Выгодные",
                style: TextStyle(
                  color: _currentSort == "discount"
                      ? Colors.blue
                      : Colors.black,
                ),
              ),
              onTap: () {
                _applySort("discount");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.trending_up,
                color: _currentSort == "price_asc" ? Colors.blue : Colors.black,
              ),
              title: Text(
                "Сначала дешевле",
                style: TextStyle(
                  color: _currentSort == "price_asc"
                      ? Colors.blue
                      : Colors.black,
                ),
              ),
              onTap: () {
                _applySort("price_asc");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.trending_down,
                color: _currentSort == "price_desc"
                    ? Colors.blue
                    : Colors.black,
              ),
              title: Text(
                "Сначала дороже",
                style: TextStyle(
                  color: _currentSort == "price_desc"
                      ? Colors.blue
                      : Colors.black,
                ),
              ),
              onTap: () {
                _applySort("price_desc");
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _applySort(String criteria) {
    final int sortToken = ++_sortSeq;
    final activeList = _getActiveNativeList();
    final originalList = _getOriginalNativeList();
    const int isolateThreshold = 120;

    double rawPrice(dynamic item) {
      if (item is! Map) return 0.0;
      dynamic raw = item['raw_price'];
      raw ??= item['price'];
      return (raw is num)
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? "0") ?? 0.0;
    }

    double comparePrice(dynamic item) {
      if (item is! Map) return 0.0;
      dynamic raw = item['raw_compare_price'] ?? item['compare_price'];
      return (raw is num)
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? "0") ?? 0.0;
    }

    int idValue(dynamic item) {
      if (item is! Map) return 0;
      return int.tryParse(item['id']?.toString() ?? "") ?? 0;
    }

    void sortInPlace(List<dynamic> list) {
      list.sort((a, b) {
        switch (criteria) {
          case "price_asc":
            return rawPrice(a).compareTo(rawPrice(b));
          case "price_desc":
            return rawPrice(b).compareTo(rawPrice(a));
          case "newest":
            return idValue(b).compareTo(idValue(a));
          case "discount":
            final discA = comparePrice(a) - rawPrice(a);
            final discB = comparePrice(b) - rawPrice(b);
            return discB.compareTo(discA);
          default:
            return 0;
        }
      });
    }

    if (criteria == "default") {
      setState(() {
        _currentSort = criteria;
        _setActiveNativeList(List.from(originalList));
        _isLocalSortLoading = false;
      });
      if (_isNativeCategoryPage) _resetNativeCategoryScroll();
      return;
    }

    if (activeList.length >= isolateThreshold) {
      setState(() {
        _currentSort = criteria;
        _isLocalSortLoading = true;
      });
      final payload = {
        "products": List<dynamic>.from(activeList),
        "criteria": criteria,
      };
      compute(_sortProductsByCriteria, payload)
          .then((sorted) {
            if (!mounted || sortToken != _sortSeq) return;
            final List<dynamic> result = List<dynamic>.from(sorted);
            setState(() {
              _setActiveNativeList(result);
              _isLocalSortLoading = false;
            });
            if (_isNativeCategoryPage) _resetNativeCategoryScroll();
          })
          .catchError((_) {
            if (!mounted || sortToken != _sortSeq) return;
            setState(() {
              _isLocalSortLoading = false;
            });
          });
      return;
    }

    setState(() {
      _currentSort = criteria;
      sortInPlace(activeList);
      _isLocalSortLoading = false;
    });
    if (_isNativeCategoryPage) _resetNativeCategoryScroll();
  }

  void _showFilterMenu(BuildContext context) {
    final bool isWishlist = _nativeCategory == "wishlist";
    RangeValues localPrice = _currentPriceRange;
    Map<String, List<String>> localFeatures = {};
    _selectedFeatures.forEach((k, v) => localFeatures[k] = List.from(v));
    List<String> localStocks = List.from(_selectedStocks);
    if (isWishlist) {
      localFeatures = {};
      localStocks = <String>[];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!isWishlist) {
            _fetchFilterMetadata(modalSetter: setModalState);
          }
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildBottomSheetHandle(),
                const SizedBox(height: 8),
                // Заголовок
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Center(
                    child: Text("Фильтры", style: _modalHeaderStyle),
                  ),
                ),
                Container(height: 1, color: Colors.grey.shade200),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: (() {
                      const int baseCount =
                          5; // price title, spacing, slider, row, divider
                      final int featureCount = isWishlist
                          ? 0
                          : _availableFeatures.length;
                      final bool showStocks =
                          !isWishlist && _availableStocks.isNotEmpty;
                      final int stockHeaderCount = showStocks
                          ? 2
                          : 0; // title + spacing
                      final int stockCount = showStocks
                          ? _availableStocks.length
                          : 0;
                      return baseCount +
                          featureCount +
                          stockHeaderCount +
                          stockCount;
                    })(),
                    itemBuilder: (context, index) {
                      // Цена
                      if (index == 0) {
                        return const Text("Цена", style: _boldSubMenuStyle);
                      }
                      if (index == 1) {
                        return const SizedBox(height: 10);
                      }
                      if (index == 2) {
                        return RangeSlider(
                          values: localPrice,
                          min: 0,
                          max: 30000,
                          divisions: 30,
                          activeColor: Colors.black,
                          inactiveColor: Colors.grey.shade300,
                          labels: RangeLabels(
                            "${localPrice.start.round()} ₽",
                            "${localPrice.end.round()} ₽",
                          ),
                          onChanged: (val) =>
                              setModalState(() => localPrice = val),
                        );
                      }
                      if (index == 3) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${localPrice.start.round()} ₽",
                              style: _subMenuStyle,
                            ),
                            Text(
                              "${localPrice.end.round()} ₽",
                              style: _subMenuStyle,
                            ),
                          ],
                        );
                      }
                      if (index == 4) {
                        final bool showMetadataLoading =
                            _isFilterMetadataLoading &&
                            _availableFeatures.isEmpty &&
                            _availableStocks.isEmpty;
                        if (showMetadataLoading) {
                          return const Column(
                            children: [
                              Divider(height: 40),
                              SizedBox(height: 8),
                              Center(
                                child: CircularProgressIndicator(
                                  color: Colors.black26,
                                ),
                              ),
                              SizedBox(height: 8),
                            ],
                          );
                        }
                        return const Divider(height: 40);
                      }

                      const int baseCount = 5;
                      final int featureCount = isWishlist
                          ? 0
                          : _availableFeatures.length;
                      const int featureStart = baseCount;
                      if (index >= featureStart &&
                          index < featureStart + featureCount) {
                        final feat = _availableFeatures[index - featureStart];
                        if (feat is! Map) return const SizedBox.shrink();
                        final String fid = feat['id']?.toString() ?? "";
                        final String fname = feat['name']?.toString() ?? "";
                        if (fid.isEmpty || fname.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final dynamic rawValues = feat['values'];
                        final Map<String, dynamic> values = (rawValues is Map)
                            ? Map<String, dynamic>.from(rawValues)
                            : {};
                        final bool isLoaded =
                            values.isNotEmpty ||
                            _featureValueTextById.containsKey(fid);
                        if (!isLoaded) {
                          _ensureFeatureValuesLoaded(
                            fid,
                            modalSetter: setModalState,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fname, style: _boldSubMenuStyle),
                              const SizedBox(height: 8),
                              const LinearProgressIndicator(
                                color: Colors.black26,
                                minHeight: 2,
                              ),
                              const Divider(height: 40),
                            ],
                          );
                        }
                        final availableSet =
                            _availableFeatureValuesInCategory[fid];
                        final filteredEntries = values.entries.where((e) {
                          if (availableSet == null || availableSet.isEmpty) {
                            return true;
                          }
                          return availableSet.contains(
                            _normalizeComparable(e.value.toString()),
                          );
                        }).toList();
                        if (filteredEntries.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fname, style: _boldSubMenuStyle),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: filteredEntries.map((e) {
                                final String vid = e.key;
                                final String vname = e.value.toString();
                                final bool isSelected =
                                    localFeatures[fid]?.contains(vid) ?? false;
                                return FilterChip(
                                  label: Text(
                                    vname,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                      fontSize: 13,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      if (selected) {
                                        localFeatures
                                            .putIfAbsent(fid, () => [])
                                            .add(vid);
                                      } else {
                                        localFeatures[fid]?.remove(vid);
                                      }
                                    });
                                  },
                                  selectedColor: Colors.black,
                                  checkmarkColor: Colors.white,
                                  backgroundColor: Colors.grey.shade100,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                );
                              }).toList(),
                            ),
                            const Divider(height: 40),
                          ],
                        );
                      }

                      final bool showStocks =
                          !isWishlist && _availableStocks.isNotEmpty;
                      final int stockHeaderStart = featureStart + featureCount;
                      if (showStocks && index == stockHeaderStart) {
                        return const Text(
                          "Наличие в магазинах",
                          style: _boldSubMenuStyle,
                        );
                      }
                      if (showStocks && index == stockHeaderStart + 1) {
                        return const SizedBox(height: 10);
                      }
                      if (showStocks) {
                        final int stockStart = stockHeaderStart + 2;
                        final int stockIndex = index - stockStart;
                        if (stockIndex >= 0 &&
                            stockIndex < _availableStocks.length) {
                          final stock = _availableStocks[stockIndex];
                          final String sid = stock['id'].toString();
                          final String sname = stock['name'] ?? "";
                          final bool isSelected = localStocks.contains(sid);
                          return CheckboxListTile(
                            title: Text(sname, style: _subMenuStyle),
                            value: isSelected,
                            activeColor: Colors.black,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  localStocks.add(sid);
                                } else {
                                  localStocks.remove(sid);
                                }
                              });
                            },
                          );
                        }
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),

                // Кнопки
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              localPrice = const RangeValues(0, 30000);
                              localFeatures.clear();
                              localStocks.clear();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text(
                            "Сбросить",
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (isWishlist) {
                              setState(() {
                                _currentPriceRange = localPrice;
                              });
                            } else {
                              setState(() {
                                _currentPriceRange = localPrice;
                                _selectedFeatures = localFeatures;
                                _selectedStocks = localStocks;
                              });
                            }
                            _applyAllFilters();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text(
                            "Показать результаты",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _applyAllFilters() async {
    if (_isNativeCategoryPage) {
      _resetNativeCategoryScroll();
    }
    if (_nativeCategory == "wishlist") {
      final int requestId = ++_wishlistFilterSeq;
      if (!_isLocalFilterLoading) {
        setState(() {
          _isLocalFilterLoading = true;
        });
      }
      final originalList = _getOriginalNativeList();
      final minPrice = _currentPriceRange.start;
      final maxPrice = _currentPriceRange.end;
      const int isolateThreshold = 120;
      if (originalList.length < isolateThreshold) {
        final filtered = originalList
            .where((item) {
              if (item is! Map) return false;
              final price = _parsePriceValue(
                item['raw_price'] ?? item['price'],
              );
              return price >= minPrice && price <= maxPrice;
            })
            .toList(growable: false);
        if (!mounted || requestId != _wishlistFilterSeq) return;
        setState(() {
          _setActiveNativeList(filtered);
          _isLocalFilterLoading = false;
        });
        return;
      }
      final payload = {
        "products": originalList,
        "minPrice": minPrice,
        "maxPrice": maxPrice,
        "mode": "parse",
      };
      final result = await compute(_filterProductsByPrice, payload).catchError((
        _,
      ) {
        return <dynamic>[];
      });
      if (!mounted || requestId != _wishlistFilterSeq) return;
      final filtered = List<dynamic>.from(result);
      setState(() {
        _setActiveNativeList(filtered);
        _isLocalFilterLoading = false;
      });
      return;
    }
    List<MapEntry<String, String>> params = [];

    // Цена
    params.add(
      MapEntry('price_min', _currentPriceRange.start.round().toString()),
    );
    params.add(
      MapEntry('price_max', _currentPriceRange.end.round().toString()),
    );

    // Характеристики
    _selectedFeatures.forEach((fid, vids) {
      if (vids.isNotEmpty) {
        // API Webasyst часто принимает параметры в виде features[id]=value1,value2 или несколько раз
        // Согласно ТЗ: features[material]=ID_VALUE
        // Если выбрано несколько, обычно это массив или через запятую.
        // Попробуем через запятую или уточним. ТЗ говорит features[material]=ID_VALUE.
        final code = _featureCodeById[fid];
        final key = (code != null && code.isNotEmpty)
            ? 'features[$code]'
            : 'features[$fid]';
        for (final vid in vids) {
          params.add(MapEntry(key, vid));
        }
      }
    });

    // Склады
    if (_selectedStocks.isNotEmpty) {
      params.add(MapEntry('stock_id', _selectedStocks.join(',')));
    }

    final customId = _nativeCustomCategoryIdByKey[_nativeCategory];
    if (customId != null && customId.isNotEmpty) {
      _nativeFilterParams[_nativeCategory] = params;
      _fetchNativeCategory(
        key: _nativeCategory,
        categoryId: customId,
        customParams: params,
        reset: true,
      );
      return;
    }
    switch (_nativeCategory) {
      case "belt":
        _nativeFilterParams["belt"] = params;
        _fetchBeltBags(customParams: params);
        break;
      case "shoulder":
        _nativeFilterParams["shoulder"] = params;
        _fetchShoulderBags(customParams: params);
        break;
      case "tablet":
        _nativeFilterParams["tablet"] = params;
        _fetchTabletBags(customParams: params);
        break;
      case "business":
        _nativeFilterParams["business"] = params;
        _fetchBusinessBags(customParams: params);
        break;
      case "women":
        _nativeFilterParams["women"] = params;
        _fetchWomenBags(customParams: params);
        break;
      case "travel":
        _nativeFilterParams["travel"] = params;
        _fetchTravelBags(customParams: params);
        break;
      case "backpacks":
        _nativeFilterParams["backpacks"] = params;
        _fetchBackpacks(customParams: params);
        break;
      case "belts":
        _nativeFilterParams["belts"] = params;
        _fetchBelts(customParams: params);
        break;
      case "wallets":
        _nativeFilterParams["wallets"] = params;
        _fetchWallets(customParams: params);
        break;
      case "accessories":
        _nativeFilterParams["accessories"] = params;
        _fetchAccessories(customParams: params);
        break;
      default:
        _nativeFilterParams["men"] = params;
        _fetchMenBags(customParams: params);
    }
  }

  void _showSearchMenu(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search',
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOutQuad),
              ),
          child: child,
        );
      },
      pageBuilder: (context, _, __) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 5, 10, 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Поиск", style: _modalHeaderStyle),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.all(25.0),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Поиск',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _navigateToSimple(
                        "Поиск",
                        "/search/?query=${Uri.encodeComponent(value.trim())}",
                      );
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactsMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Contacts',
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOutQuad),
              ),
          child: child,
        );
      },
      pageBuilder: (context, _, __) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 5, 10, 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Контакты", style: _modalHeaderStyle),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(25),
                  children: [
                    _contactBox(
                      "8-999-082-57-07",
                      "Отдел продаж",
                      () => _launchUrl("tel:89990825707"),
                    ),
                    const SizedBox(height: 15),
                    _contactBox(
                      "hb-market@mail.ru",
                      "Почта",
                      () => _launchUrl("mailto:hb-market@mail.ru"),
                    ),
                    const SizedBox(height: 25),
                    _buildSocialRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCustomMenu() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOutQuad),
              ),
          child: child,
        );
      },
      pageBuilder: (context, _, __) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Drawer(
              width: MediaQuery.of(context).size.width,
              backgroundColor: Colors.white,
              elevation: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(25, 5, 10, 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Image.asset('assets/images/logo.png', height: 28),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: Colors.grey.shade200),
                    Expanded(
                      child: _isMenuLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.black,
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: (() {
                                final int categoryCount = _apiCategories.length;
                                const int menuCount = 8;
                                const int staticCount = 14;
                                return categoryCount + menuCount + staticCount;
                              })(),
                              itemBuilder: (context, index) {
                                int cursor = 0;

                                if (index == cursor) {
                                  return const SizedBox(height: 10);
                                }
                                cursor++;

                                final int categoryCount = _apiCategories.length;
                                if (index >= cursor &&
                                    index < cursor + categoryCount) {
                                  final cat = _apiCategories[index - cursor];
                                  return _buildCategoryItemDynamic(
                                    cat,
                                    setDialogState,
                                  );
                                }
                                cursor += categoryCount;

                                if (index == cursor) {
                                  return const SizedBox(height: 15);
                                }
                                cursor++;
                                if (index == cursor) {
                                  return Container(
                                    height: 1,
                                    color: Colors.black87,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                  );
                                }
                                cursor++;
                                if (index == cursor) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      "Персонализация",
                                      textAlign: TextAlign.center,
                                      style: _boldMenuStyle,
                                    ),
                                  );
                                }
                                cursor++;
                                if (index == cursor) {
                                  return Container(
                                    height: 1,
                                    color: Colors.black87,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                  );
                                }
                                cursor++;
                                if (index == cursor) {
                                  return const SizedBox(height: 10);
                                }
                                cursor++;

                                const menuItems = [
                                  {
                                    "title": "О компании",
                                    "url": "/o-kompanii/",
                                  },
                                  {
                                    "title": "АДРЕСА | КОНТАТЫ",
                                    "url": "/adryesa--kontakty/",
                                  },
                                  {"title": "Гарантия", "url": "/garantiya/"},
                                  {
                                    "title": "Политика конфиденциальности",
                                    "url": "/politika-konfidentsialnosti/",
                                  },
                                  {
                                    "title": "Доставка и оплата",
                                    "url": "/dostavka-oplata/",
                                  },
                                  {
                                    "title": "Система лояльности",
                                    "url": "/novaya-bonusnaya-sistyema/",
                                  },
                                  {
                                    "title": "Отзывы и предложения",
                                    "url": "/otzyvy/",
                                  },
                                  {
                                    "title": "Персонализация и тиснение вещей",
                                    "url":
                                        "/personalizatsiya-i-tesnenie-veshchey/",
                                  },
                                ];
                                if (index >= cursor &&
                                    index < cursor + menuItems.length) {
                                  final item = menuItems[index - cursor];
                                  return _menuRow(item["title"]!, item["url"]!);
                                }
                                cursor += menuItems.length;

                                if (index == cursor) {
                                  return const SizedBox(height: 20);
                                }
                                cursor++;
                                if (index == cursor) {
                                  return Divider(
                                    color: Colors.grey.shade100,
                                    thickness: 8,
                                  );
                                }
                                cursor++;
                                if (index == cursor) {
                                  return _profileRow(
                                    Icons.person_outline,
                                    "Личный кабинет",
                                    "/my/",
                                  );
                                }
                                cursor++;
                                if (index == cursor) {
                                  return ValueListenableBuilder<int>(
                                    valueListenable: _cartCountNotifier,
                                    builder: (context, count, _) {
                                      final badge = count > 0
                                          ? count.toString()
                                          : "";
                                      return _profileRow(
                                        Icons.shopping_cart_outlined,
                                        "Корзина",
                                        "/cart/",
                                        badge: badge,
                                      );
                                    },
                                  );
                                }
                                cursor++;
                                if (index == cursor) {
                                  return ValueListenableBuilder<int>(
                                    valueListenable: _compareCountNotifier,
                                    builder: (context, count, _) {
                                      final badge = count > 0
                                          ? count.toString()
                                          : "";
                                      return _profileRow(
                                        Icons.bar_chart_outlined,
                                        "Сравнение",
                                        "/compare/",
                                        badge: badge,
                                      );
                                    },
                                  );
                                }
                                cursor++;
                                if (index == cursor) {
                                  return ValueListenableBuilder<int>(
                                    valueListenable: _wishCountNotifier,
                                    builder: (context, count, _) {
                                      final badge = count > 0
                                          ? count.toString()
                                          : "";
                                      return _profileRow(
                                        Icons.favorite_border,
                                        "Избранное",
                                        "/search/?wishlist=true",
                                        badge: badge,
                                      );
                                    },
                                  );
                                }
                                cursor++;
                                if (index == cursor) {
                                  return Divider(
                                    color: Colors.grey.shade100,
                                    thickness: 8,
                                  );
                                }
                                cursor++;
                                if (index == cursor) {
                                  return _buildSimpleContacts();
                                }
                                cursor++;
                                if (index == cursor) {
                                  return const SizedBox(height: 30);
                                }

                                return const SizedBox.shrink();
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryItemDynamic(dynamic cat, StateSetter setDialogState) {
    var rawChildren = cat['categories'] ?? cat['children'];
    List<dynamic> children = (rawChildren is List)
        ? rawChildren.where((sub) => sub['status'].toString() != "0").toList()
        : [];
    String catId = cat['id'].toString();
    bool isExpanded = _expandedCategoryId == catId;

    return Column(
      children: [
        _menuRow(
          cat['name'].toString(),
          "",
          hasChildren: children.isNotEmpty,
          isExpanded: isExpanded,
          onTap: () {
            if (children.isNotEmpty) {
              setDialogState(
                () => _expandedCategoryId = isExpanded ? null : catId,
              );
            } else {
              _navigateToApiCategory(cat);
            }
          },
          onExpand: () => setDialogState(
            () => _expandedCategoryId = isExpanded ? null : catId,
          ),
        ),
        if (isExpanded)
          Column(
            children: [
              _menuRow(
                "Все товары",
                "",
                isSub: true,
                isBold: true,
                onTap: () => _navigateToApiCategory(cat),
              ),
              ...children.map(
                (sub) => _menuRow(
                  sub['name'].toString(),
                  "",
                  isSub: true,
                  onTap: () => _navigateToApiCategory(sub),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _contactBox(String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _boldMenuStyle),
            Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleContacts() {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _launchUrl("tel:89990825707"),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "8-999-082-57-07",
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  "Отдел продаж",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: () => _launchUrl("mailto:hb-market@mail.ru"),
            child: const Text("hb-market@mail.ru", style: _menuStyle),
          ),
          const SizedBox(height: 20),
          _buildSocialRow(),
        ],
      ),
    );
  }

  Widget _buildSocialRow() {
    return Row(
      children: [
        _socialIcon(
          'assets/images/tg.png',
          "https://t.me/Operator_Hozyain_Barin",
        ),
        const SizedBox(width: 15),
        _socialIcon('assets/images/wa.png', "https://wa.me/79990825707"),
        const SizedBox(width: 15),
        _socialIcon(
          'assets/images/max.png',
          "https://max.ru/u/f9LHodD0cOIrSTmGrBVHPgQ3z8FXRNwfC0TYdZhrtz5a1-zLDmEcEiIQMfc",
        ),
      ],
    );
  }

  Widget _socialIcon(String asset, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Image.asset(asset, width: 35),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

enum _AuthStep { phone, code, register }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeFocus = FocusNode();
  bool _isSettingPhoneText = false;
  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  _AuthStep _step = _AuthStep.phone;
  bool _consent = false;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _isRegistering = false;
  String? _authError;
  String? _pendingContactId;
  Timer? _codeTimer;
  int _codeSecondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_ensurePhonePrefix);
    if (_phoneController.text.isEmpty) {
      _phoneController.text = '+7 ';
      _phoneController.selection = TextSelection.fromPosition(
        TextPosition(offset: _phoneController.text.length),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_ensurePhonePrefix);
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _codeFocus.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  String _normalizePhone(String input) => input.replaceAll(RegExp(r'\D'), '');

  String _normalizePhoneForAuth(String input) {
    var digits = _normalizePhone(input);
    if (digits.isEmpty) return "";
    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    } else if (digits.length == 10) {
      digits = '7$digits';
    } else if (digits.length > 11) {
      digits = '7${digits.substring(digits.length - 10)}';
    }
    if (digits.length == 11 && digits.startsWith('7') && digits[1] == '7') {
      digits = '7${digits.substring(digits.length - 10)}';
    }
    return digits;
  }

  void _ensurePhonePrefix() {
    if (_isSettingPhoneText) return;
    final text = _phoneController.text;
    if (!text.startsWith('+7')) {
      _isSettingPhoneText = true;
      _phoneController.text = '+7 ';
      _phoneController.selection = TextSelection.fromPosition(
        TextPosition(offset: _phoneController.text.length),
      );
      _isSettingPhoneText = false;
      return;
    }
    final selection = _phoneController.selection;
    if (selection.start < 3 || selection.end < 3) {
      _isSettingPhoneText = true;
      final newText = text.isEmpty ? '+7 ' : text;
      _phoneController.text = newText;
      _phoneController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
      _isSettingPhoneText = false;
    }
  }

  void _startCodeTimer() {
    _codeTimer?.cancel();
    _codeSecondsLeft = 60;
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_codeSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _codeSecondsLeft = 0);
      } else {
        setState(() => _codeSecondsLeft -= 1);
      }
    });
  }

  void _onCodeChanged(String value) {
    if (value.length >= 4) {
      _codeTimer?.cancel();
      _codeSecondsLeft = 0;
    }
    setState(() {});
  }

  void _focusCodeInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_codeFocus);
    });
  }

  Widget _buildCodeInput() {
    final code = _codeController.text;
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(_codeFocus),
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            Positioned.fill(
              child: TextField(
                focusNode: _codeFocus,
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: _onCodeChanged,
                cursorColor: Colors.transparent,
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (index) {
                final char = index < code.length ? code[index] : '';
                return SizedBox(
                  width: 42,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        char,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(height: 1, color: Colors.black54),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSmsCode() async {
    final phone = _normalizePhoneForAuth(_phoneController.text);
    if (phone.isEmpty) {
      setState(() => _authError = "Введите номер телефона");
      return;
    }
    if (!_consent) {
      setState(() => _authError = "Подтвердите согласие");
      return;
    }
    setState(() {
      _authError = null;
      _isSendingCode = true;
    });
    try {
      final dio = _getAuthDio();
      final response = await dio.post(
        '/native/auth_sms.php',
        data: {'action': 'send_code', 'phone': phone},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = _parseAuthResponse(response.data);
      if (data?['status'] == 'ok') {
        if (!mounted) return;
        _codeController.clear();
        _startCodeTimer();
        if (mounted) {
          setState(() {
            _step = _AuthStep.code;
          });
          _focusCodeInput();
        }
      } else {
        setState(() => _authError = "Не удалось отправить код");
      }
    } catch (_) {
      if (mounted) setState(() => _authError = "Ошибка сети");
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  String _extractName(Map<String, dynamic>? data) {
    if (data == null) return "";
    String pick(Map<String, dynamic> map) {
      final candidates = [
        map['name'],
        map['contact_name'],
        map['fullname'],
        map['fio'],
        map['customer_name'],
        map['customer'],
        map['display_name'],
      ];
      for (final c in candidates) {
        final value = c?.toString().trim() ?? "";
        if (value.isNotEmpty) return value;
      }
      final last = map['last_name'] ?? map['lastname'] ?? map['surname'];
      final first = map['first_name'] ?? map['firstname'];
      final middle =
          map['middle_name'] ?? map['patronymic'] ?? map['second_name'];
      final parts = <String>[];
      if ((last ?? "").toString().trim().isNotEmpty) {
        parts.add(last.toString().trim());
      }
      if ((first ?? "").toString().trim().isNotEmpty) {
        parts.add(first.toString().trim());
      }
      if ((middle ?? "").toString().trim().isNotEmpty) {
        parts.add(middle.toString().trim());
      }
      return parts.join(' ').trim();
    }

    final direct = pick(data);
    if (direct.isNotEmpty) return direct;
    final nested =
        data['contact'] ?? data['user'] ?? data['profile'] ?? data['customer'];
    if (nested is Map) {
      final nestedMap = Map<String, dynamic>.from(nested);
      return pick(nestedMap);
    }
    if (nested is List && nested.isNotEmpty && nested.first is Map) {
      final nestedMap = Map<String, dynamic>.from(nested.first as Map);
      return pick(nestedMap);
    }
    return "";
  }

  bool _isValidName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (lower == "клиент" || lower == "client") return false;
    if (RegExp(r'\d').hasMatch(trimmed)) return false;
    return true;
  }

  String _normalizePhotoUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith("http://") || value.startsWith("https://")) {
      return value;
    }
    if (value.startsWith("//")) return "https:$value";
    if (value.startsWith("/")) return "https://hozyain-barin.ru$value";
    return "https://hozyain-barin.ru/$value";
  }

  Future<Map<String, dynamic>?> _fetchCustomerInfoById(String contactId) async {
    if (contactId.isEmpty) return null;
    try {
      final dio = _getAuthDio();
      final response = await dio.get(
        '/api.php/shop.customer.search',
        queryParameters: {
          'hash': 'id/$contactId',
          'access_token': _shopApiToken,
        },
      );
      dynamic decoded = response.data;
      if (decoded is String) decoded = json.decode(decoded);
      dynamic data = decoded;
      if (decoded is Map) {
        if (decoded['data'] != null) data = decoded['data'];
        if (decoded['contacts'] != null) data = decoded['contacts'];
        if (decoded['customers'] != null) data = decoded['customers'];
      }
      Map? contact;
      if (data is List && data.isNotEmpty && data.first is Map) {
        contact = data.first as Map;
      } else if (data is Map) {
        contact = data;
      }
      if (contact == null) return null;
      final contactMap = Map<String, dynamic>.from(contact);
      final name = _extractName(contactMap);
      final photoRaw =
          contactMap['photo_url'] ??
          contactMap['photo_url_200'] ??
          contactMap['photo_url_96'] ??
          contactMap['photo_url_40'] ??
          contactMap['photo'] ??
          contactMap['userpic'] ??
          contactMap['userpic_url'];
      var photo = photoRaw != null
          ? _normalizePhotoUrl(photoRaw.toString())
          : "";
      if (photo.isNotEmpty && _isDefaultUserpic(photo)) {
        photo = "";
      }
      return {
        'id':
            contactMap['id']?.toString() ??
            contactMap['contact_id']?.toString() ??
            "",
        if (name.isNotEmpty) 'name': name,
        if (photo.isNotEmpty) 'photo_url': photo,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchCustomerInfoByPhone(
    String phoneDigits,
  ) async {
    if (phoneDigits.isEmpty) return null;
    try {
      final dio = _getAuthDio();
      final response = await dio.get(
        '/api.php/shop.customer.search',
        queryParameters: {
          'hash': 'phone/$phoneDigits',
          'access_token': _shopApiToken,
        },
      );
      dynamic decoded = response.data;
      if (decoded is String) decoded = json.decode(decoded);
      dynamic data = decoded;
      if (decoded is Map) {
        if (decoded['data'] != null) data = decoded['data'];
        if (decoded['contacts'] != null) data = decoded['contacts'];
        if (decoded['customers'] != null) data = decoded['customers'];
      }
      if (data is List && data.isNotEmpty && data.first is Map) {
        final map = Map<String, dynamic>.from(data.first as Map);
        final name = _extractName(map);
        final photoRaw =
            map['photo_url'] ??
            map['photo_url_200'] ??
            map['photo_url_96'] ??
            map['photo_url_40'] ??
            map['photo'] ??
            map['userpic'] ??
            map['userpic_url'];
        var photo = photoRaw != null
            ? _normalizePhotoUrl(photoRaw.toString())
            : "";
        if (photo.isNotEmpty && _isDefaultUserpic(photo)) photo = "";
        return {
          'id': map['id']?.toString() ?? map['contact_id']?.toString() ?? "",
          if (name.isNotEmpty) 'name': name,
          if (photo.isNotEmpty) 'photo_url': photo,
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _verifySmsCode() async {
    final phone = _normalizePhoneForAuth(_phoneController.text);
    final code = _codeController.text.trim();
    if (phone.isEmpty || code.isEmpty) {
      setState(() => _authError = "Введите телефон и код");
      return;
    }
    setState(() {
      _authError = null;
      _isVerifyingCode = true;
    });
    try {
      final dio = _getAuthDio();
      final response = await dio.post(
        '/native/auth_sms.php',
        data: {'action': 'verify_code', 'phone': phone, 'code': code},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = _parseAuthResponse(response.data);
      final status = data?['status']?.toString().toLowerCase();
      final contactId = data?['contact_id']?.toString();
      final photo =
          (data?['photo'] ??
                  data?['photo_url'] ??
                  data?['avatar'] ??
                  data?['image'] ??
                  data?['userpic'])
              ?.toString();
      final isNew =
          data?['is_new'] == true ||
          data?['is_new_user'] == true ||
          data?['is_new']?.toString() == '1' ||
          data?['is_new_user']?.toString() == '1';
      if (status == 'ok') {
        if (!mounted) return;
        _authPhone = phone;
        if (photo != null && photo.isNotEmpty) {
          final normalized = photo.startsWith('http')
              ? photo
              : (photo.startsWith('/')
                    ? 'https://hozyain-barin.ru$photo'
                    : 'https://hozyain-barin.ru/$photo');
          if (!_isDefaultUserpic(normalized)) {
            _authPhotoUrl = normalized;
          }
        }
        final nameFromAuth = _extractName(data);
        final customerInfo = (contactId != null && contactId.isNotEmpty)
            ? await _fetchCustomerInfoById(contactId)
            : await _fetchCustomerInfoByPhone(phone);
        final fetchedName = customerInfo?['name']?.toString().trim() ?? "";
        final fetchedPhoto =
            customerInfo?['photo_url']?.toString().trim() ?? "";
        final fetchedId = customerInfo?['id']?.toString().trim() ?? "";
        if (fetchedPhoto.isNotEmpty && !_isDefaultUserpic(fetchedPhoto)) {
          _authPhotoUrl = fetchedPhoto;
        }
        final effectiveName = fetchedName.isNotEmpty
            ? fetchedName
            : nameFromAuth;
        if (!mounted) return;
        if (isNew == true) {
          _pendingContactId = (contactId != null && contactId.isNotEmpty)
              ? contactId
              : fetchedId;
          _authContactId = null;
          _authUserName = null;
          if (_isValidName(effectiveName)) {
            _nameController.text = effectiveName;
          } else {
            _nameController.clear();
          }
          setState(() => _step = _AuthStep.register);
        } else {
          _authContactId = (contactId != null && contactId.isNotEmpty)
              ? contactId
              : fetchedId;
          _authUserName = effectiveName.isNotEmpty
              ? effectiveName
              : (_authUserName ?? "Пользователь");
          Navigator.pop(context, true);
        }
      } else {
        _codeController.clear();
        final serverMessage = data?['message']?.toString().trim();
        setState(
          () => _authError = (serverMessage != null && serverMessage.isNotEmpty)
              ? serverMessage
              : "Неверный код",
        );
        _codeFocus.requestFocus();
      }
    } catch (_) {
      if (mounted) setState(() => _authError = "Ошибка сети");
    } finally {
      if (mounted) setState(() => _isVerifyingCode = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _authError = "Введите имя");
      return;
    }
    final phone = _normalizePhoneForAuth(_phoneController.text);
    if (phone.isEmpty) {
      setState(() => _authError = "Введите телефон");
      return;
    }
    setState(() {
      _authError = null;
      _isRegistering = true;
    });
    try {
      final dio = _getAuthDio();
      final response = await dio.post(
        '/native/auth_sms.php',
        data: {'action': 'register_with_name', 'phone': phone, 'name': name},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = _parseAuthResponse(response.data);
      if (data?['status'] == 'ok') {
        final registeredId = data?['contact_id']?.toString();
        _authContactId = (registeredId != null && registeredId.isNotEmpty)
            ? registeredId
            : _pendingContactId;
        _authUserName = name;
        _authPhone = phone;
        if (_authContactId == null || _authContactId!.isEmpty) {
          setState(() => _authError = "Не удалось завершить регистрацию");
          return;
        }
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        setState(() => _authError = "Не удалось сохранить имя");
      }
    } catch (_) {
      if (mounted) setState(() => _authError = "Ошибка сети");
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: Colors.grey.shade400),
    );
    final inputDecoration = InputDecoration(
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: Colors.black),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
    final title = _step == _AuthStep.register ? "Мои данные" : "Авторизация";
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            if (_step == _AuthStep.phone) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [_phoneMask],
                decoration: inputDecoration.copyWith(
                  labelText: "Телефон",
                  prefixIcon: const Icon(
                    Icons.phone,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Пожалуйста, введите свой номер телефона.\nМы отправим Вам код с помощью SMS",
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consent,
                    onChanged: (value) =>
                        setState(() => _consent = value ?? false),
                    activeColor: Colors.black,
                  ),
                  const Expanded(
                    child: Text(
                      "Нажимая кнопку, Вы соглашаетесь с Правилами и политикой конфиденциальности Компании.",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSendingCode || !_consent)
                      ? null
                      : _sendSmsCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _consent
                        ? Colors.black
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: _isSendingCode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Получить код",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
            if (_step == _AuthStep.code) ...[
              TextField(
                controller: _phoneController,
                readOnly: true,
                inputFormatters: [_phoneMask],
                decoration: inputDecoration.copyWith(
                  labelText: "Телефон",
                  prefixIcon: const Icon(
                    Icons.phone,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Вам выслан код в SMS - сообщении.\nВведите его в поле ниже.",
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Center(child: SizedBox(width: 200, child: _buildCodeInput())),
              const SizedBox(height: 22),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifyingCode
                      ? null
                      : (_codeController.text.length == 4
                            ? _verifySmsCode
                            : (_codeSecondsLeft == 0 ? _sendSmsCode : null)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (_codeController.text.length == 4 ||
                            _codeSecondsLeft == 0)
                        ? Colors.black
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifyingCode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _codeController.text.length == 4
                              ? "Подтвердить"
                              : (_codeSecondsLeft == 0
                                    ? "Отправить код повторно"
                                    : "$_codeSecondsLeft"),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
            if (_step == _AuthStep.register) ...[
              TextField(
                controller: _nameController,
                decoration: inputDecoration.copyWith(labelText: "Имя"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                readOnly: true,
                inputFormatters: [_phoneMask],
                decoration: inputDecoration.copyWith(labelText: "Телефон"),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRegistering ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: _isRegistering
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Сохранить",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
            if (_authError != null) ...[
              const SizedBox(height: 10),
              Text(
                _authError!,
                style: const TextStyle(fontSize: 13, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final double total;
  final VoidCallback? onOrderSuccess;
  const CheckoutPage({
    super.key,
    required this.items,
    required this.total,
    this.onOrderSuccess,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _addressController = TextEditingController();
  int _deliveryMethod = 1; // 0 - доставка, 1 - самовывоз
  int _paymentMethod = 0; // 0 - онлайн, 1 - при получении
  Map<String, dynamic>? _selectedPickupPoint;
  Map<String, dynamic>? _selectedDeliveryData;
  String? _selectedDeliveryAddress;
  String? _selectedDeliveryApartment;
  String? _selectedDeliveryDate;
  String? _selectedDeliveryTime;
  bool _isSubmittingOrder = false;
  String? _orderNumber;
  String? _orderError;

  String _buildDeliveryShortAddress({
    required String fullAddress,
    required String apartment,
  }) {
    final parts = fullAddress
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return apartment.isNotEmpty ? 'кв. $apartment' : '';
    }

    final streetRegex = RegExp(
      r'(улица|ул\.?|проспект|пр-кт|переулок|пер\.?|бульвар|б-р|шоссе|наб\.?|набережная|проезд|пр-д|площадь|пл\.?|аллея|линия)',
      caseSensitive: false,
      unicode: true,
    );
    final cityRegex = RegExp(
      r'(город|г\.?|пос[её]лок|пгт|село|деревня)',
      caseSensitive: false,
      unicode: true,
    );

    String? street;
    for (final part in parts.reversed) {
      if (streetRegex.hasMatch(part)) {
        street = part;
        break;
      }
    }
    var streetIndex = street != null ? parts.lastIndexOf(street) : -1;

    String? city;
    for (final part in parts) {
      if (cityRegex.hasMatch(part)) {
        city = part;
        break;
      }
    }
    if ((city == null || city.isEmpty) && streetIndex > 0) {
      city = parts[streetIndex - 1];
    }
    if (city == null || city.isEmpty) {
      city = parts.length >= 3 ? parts[parts.length - 3] : parts.first;
    }

    if (street == null || street.isEmpty) {
      street = parts.length >= 2 ? parts[parts.length - 2] : parts.last;
      streetIndex = parts.lastIndexOf(street);
      if (streetIndex == 0 && parts.length > 1) {
        street = parts[1];
      }
    }

    final resultParts = <String>[];
    if (city.isNotEmpty) resultParts.add(city);
    if (street.isNotEmpty && street != city) resultParts.add(street);
    if (apartment.isNotEmpty) resultParts.add('кв. $apartment');
    return resultParts.join(', ');
  }

  static final RegExp _pickupAvailabilityHighlightRegex = RegExp(
    r'(сегодня|завтра|\d{1,2}\s*(?:-|–|—)\s*\d{1,2}\s*[а-яё]+|\d{1,2}\s*[а-яё]+)',
    caseSensitive: false,
    unicode: true,
  );

  TextSpan _buildPickupAvailabilitySpan(
    String text, {
    required TextStyle baseStyle,
    required TextStyle accentStyle,
  }) {
    final value = text.trim();
    if (value.isEmpty) return TextSpan(text: '', style: baseStyle);
    final matches = _pickupAvailabilityHighlightRegex
        .allMatches(value)
        .toList();
    if (matches.isEmpty) return TextSpan(text: value, style: baseStyle);

    final children = <TextSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        children.add(
          TextSpan(
            text: value.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }
      children.add(
        TextSpan(
          text: value.substring(match.start, match.end),
          style: accentStyle,
        ),
      );
      cursor = match.end;
    }
    if (cursor < value.length) {
      children.add(TextSpan(text: value.substring(cursor), style: baseStyle));
    }
    return TextSpan(children: children);
  }

  Future<void> _submitOrder() async {
    if (!_isAuthorized) {
      setState(() => _orderError = "Войдите по номеру телефона");
      return;
    }
    if (widget.items.isEmpty) {
      setState(() => _orderError = "Корзина пуста");
      return;
    }
    setState(() {
      _orderError = null;
      _isSubmittingOrder = true;
    });
    try {
      final dio = _getAuthDio();
      final response = await dio.post(
        '/native/create_order.php',
        data: {
          'items': widget.items,
          'total': widget.total,
          if (_selectedPickupPoint != null)
            'pickup_point': _selectedPickupPoint,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = _parseAuthResponse(response.data);
      final status = data?['status']?.toString();
      final number =
          data?['order_number']?.toString() ??
          data?['order_id']?.toString() ??
          data?['id']?.toString();
      if (status == 'ok') {
        if (mounted) {
          widget.onOrderSuccess?.call();
          setState(() => _orderNumber = number ?? "—");
        }
      } else {
        setState(() => _orderError = "Не удалось оформить заказ");
      }
    } catch (_) {
      if (mounted) setState(() => _orderError = "Ошибка сети");
    } finally {
      if (mounted) setState(() => _isSubmittingOrder = false);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Future<void> _openAuthPage() async {
    final result = await Navigator.push<bool>(
      context,
      _adaptivePageRoute(builder: (_) => const AuthPage()),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _openPickupPointsPage() async {
    String? productId;
    for (final item in widget.items) {
      final id = item['id']?.toString().trim();
      if (id != null && id.isNotEmpty) {
        productId = id;
        break;
      }
    }
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      _adaptivePageRoute(
        builder: (_) => DeliveryOrPickupWrapperPage(
          initialPickup: true,
          selectedPoint: _selectedPickupPoint,
          productId: productId,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedPickupPoint = {
        ...selected,
        'stock_id':
            selected['stock_id']?.toString() ?? selected['id']?.toString(),
      };
      _deliveryMethod = 1;
    });
  }

  Future<void> _openDeliveryAddressPage({bool openSheetOnStart = false}) async {
    String? productId;
    for (final item in widget.items) {
      final id = item['id']?.toString().trim();
      if (id != null && id.isNotEmpty) {
        productId = id;
        break;
      }
    }
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      _adaptivePageRoute(
        builder: (_) => DeliveryOrPickupWrapperPage(
          initialPickup: false,
          selectedPoint: _selectedPickupPoint,
          productId: productId,
          initialDeliveryData: _selectedDeliveryData,
          openDeliverySheetOnStart: openSheetOnStart,
        ),
      ),
    );
    if (!mounted || result == null) return;
    final resultType = result['result_type']?.toString();
    if (resultType == 'delivery') {
      setState(() {
        _selectedDeliveryData = Map<String, dynamic>.from(result);
        _selectedDeliveryAddress = result['address']?.toString().trim();
        _selectedDeliveryApartment = result['apartment']?.toString().trim();
        _selectedDeliveryDate = result['date']?.toString().trim();
        _selectedDeliveryTime = result['time']?.toString().trim();
        _deliveryMethod = 0;
      });
      return;
    }
    setState(() {
      _selectedPickupPoint = {
        ...result,
        'stock_id': result['stock_id']?.toString() ?? result['id']?.toString(),
      };
      _deliveryMethod = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_orderNumber != null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text(
            "Заказ оформлен",
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          surfaceTintColor: Colors.white,
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 46),
                const SizedBox(height: 10),
                const Text(
                  "Спасибо за заказ!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  "Номер заказа: $_orderNumber",
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text("Вернуться"),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final selectedDeliveryAddress = (_selectedDeliveryAddress ?? '').trim();
    final selectedDeliveryApartment = (_selectedDeliveryApartment ?? '').trim();
    final selectedDeliveryDate = (_selectedDeliveryDate ?? '').trim();
    final selectedDeliveryTime = (_selectedDeliveryTime ?? '').trim();
    final selectedDeliverySummary = _buildDeliveryShortAddress(
      fullAddress: selectedDeliveryAddress,
      apartment: selectedDeliveryApartment,
    );
    final selectedPickupName = (_selectedPickupPoint?['name']?.toString() ?? '')
        .trim();
    final selectedPickupAddress =
        (_selectedPickupPoint?['address']?.toString() ?? '').trim();
    final selectedPickupWorktime =
        ((_selectedPickupPoint?['worktime'] ??
                        _selectedPickupPoint?['work_time'])
                    ?.toString() ??
                '')
            .trim();
    final selectedPickupEta = (_selectedPickupPoint?['eta']?.toString() ?? '')
        .trim();
    final selectedPickupIsAvailableRaw = _selectedPickupPoint?['is_available'];
    final selectedPickupIsAvailable =
        selectedPickupIsAvailableRaw == true ||
        selectedPickupIsAvailableRaw == 1 ||
        selectedPickupIsAvailableRaw == '1' ||
        selectedPickupIsAvailableRaw?.toString().toLowerCase() == 'true';
    final selectedPickupAvailability = selectedPickupIsAvailable
        ? 'В наличии сегодня'
        : selectedPickupEta;
    const pickupAvailabilityBaseStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF8A8F98),
      height: 1.2,
    );
    const pickupAvailabilityAccentStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: Color(0xFF63B45D),
      height: 1.2,
    );
    final pickupAvailabilitySpan = selectedPickupAvailability.isEmpty
        ? null
        : (selectedPickupIsAvailable
              ? const TextSpan(
                  children: [
                    TextSpan(
                      text: 'В наличии ',
                      style: pickupAvailabilityBaseStyle,
                    ),
                    TextSpan(
                      text: 'сегодня',
                      style: pickupAvailabilityAccentStyle,
                    ),
                  ],
                )
              : _buildPickupAvailabilitySpan(
                  selectedPickupAvailability,
                  baseStyle: pickupAvailabilityBaseStyle,
                  accentStyle: pickupAvailabilityAccentStyle,
                ));
    final hasSelectedPickup =
        _selectedPickupPoint != null &&
        (selectedPickupName.isNotEmpty || selectedPickupAddress.isNotEmpty);
    final hasSelectedDelivery = selectedDeliverySummary.isNotEmpty;
    final deliveryDateTimeLabel = <String>[
      if (selectedDeliveryDate.isNotEmpty) selectedDeliveryDate,
      if (selectedDeliveryTime.isNotEmpty) selectedDeliveryTime,
    ].join(', ');
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text(
                "Оформление заказа",
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(5, 12, 5, 20),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Контактная информация",
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (_isAuthorized)
                        TextButton(
                          onPressed: _openAuthPage,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                          child: const Text("Изменить"),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!_isAuthorized) ...[
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openAuthPage,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEDEDED),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                        ),
                        label: const Text(
                          "Заполнить данные",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage:
                              (_authPhotoUrl != null &&
                                  _authPhotoUrl!.isNotEmpty)
                              ? NetworkImage(_authPhotoUrl!)
                              : null,
                          child:
                              (_authPhotoUrl == null || _authPhotoUrl!.isEmpty)
                              ? const Icon(Icons.person, color: Colors.black54)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _authUserName?.isNotEmpty == true
                                    ? _authUserName!
                                    : "Пользователь",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatPhoneMasked(_authPhone ?? ""),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _section("Способ получения", [
              Container(
                height: 34,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _deliveryMethod = 1),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _deliveryMethod == 1
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: _deliveryMethod == 1
                                ? const [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: const Text(
                            "Самовывоз",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _deliveryMethod = 0),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _deliveryMethod == 0
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: _deliveryMethod == 0
                                ? const [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: const Text(
                            "Доставка",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_deliveryMethod == 1) ...[
                if (!hasSelectedPickup)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/gps-map.jpg',
                            fit: BoxFit.cover,
                          ),
                          const Positioned.fill(
                            child: ColoredBox(color: Color(0x08000000)),
                          ),
                          Center(
                            child: SizedBox(
                              height: 40,
                              width: 270,
                              child: ElevatedButton.icon(
                                onPressed: _openPickupPointsPage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEDEDED),
                                  foregroundColor: Colors.black87,
                                  side: const BorderSide(
                                    color: Color(0xFFD5D8DD),
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 1,
                                ),
                                icon: const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  "Выбрать пункт самовывоза",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Material(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE3E4E8)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Transform.translate(
                                      offset: const Offset(-3, 0),
                                      child: const Padding(
                                        padding: EdgeInsets.only(top: 1),
                                        child: Icon(
                                          Icons.location_on_outlined,
                                          size: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedPickupName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (selectedPickupAddress.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedPickupAddress,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF4C5159),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                                if (selectedPickupWorktime.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedPickupWorktime,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF8A8F98),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                                if (pickupAvailabilitySpan != null) ...[
                                  const SizedBox(height: 4),
                                  Text.rich(
                                    pickupAvailabilitySpan,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(height: 1, color: const Color(0xFFE3E4E8)),
                          Container(
                            color: const Color(0xFFEDEDED),
                            child: SizedBox(
                              height: 46,
                              child: InkWell(
                                onTap: _openPickupPointsPage,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Изменить пункт самовывоза",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 22,
                                        color: Colors.black38,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                if (!hasSelectedDelivery)
                  SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openDeliveryAddressPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEDEDED),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.location_on_outlined, size: 18),
                      label: const Text(
                        "Указать данные доставки",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  )
                else ...[
                  Material(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE3E4E8)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Transform.translate(
                                      offset: const Offset(-1, 0),
                                      child: const Padding(
                                        padding: EdgeInsets.only(top: 1),
                                        child: Icon(
                                          Icons.location_on_outlined,
                                          size: 18,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedDeliverySummary,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black87,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (deliveryDateTimeLabel.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_outlined,
                                        size: 16,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          deliveryDateTimeLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black87,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(height: 1, color: const Color(0xFFE3E4E8)),
                          Container(
                            color: const Color(0xFFEDEDED),
                            child: SizedBox(
                              height: 46,
                              child: InkWell(
                                onTap: () => _openDeliveryAddressPage(
                                  openSheetOnStart: true,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Изменить данные доставки",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 22,
                                        color: Colors.black38,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ]),
            _section("Способ оплаты", [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _paymentMethod == 0
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: const Text("Онлайн"),
                onTap: () => setState(() => _paymentMethod = 0),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _paymentMethod == 1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: const Text("При получении"),
                onTap: () => setState(() => _paymentMethod = 1),
              ),
            ]),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmittingOrder ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmittingOrder
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Подтвердить заказ",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            if (_orderError != null) ...[
              const SizedBox(height: 8),
              Text(
                _orderError!,
                style: const TextStyle(fontSize: 13, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DeliveryOrPickupWrapperPage extends StatefulWidget {
  final bool initialPickup;
  final Map<String, dynamic>? selectedPoint;
  final String? productId;
  final Map<String, dynamic>? initialDeliveryData;
  final bool openDeliverySheetOnStart;

  const DeliveryOrPickupWrapperPage({
    super.key,
    required this.initialPickup,
    this.selectedPoint,
    this.productId,
    this.initialDeliveryData,
    this.openDeliverySheetOnStart = false,
  });

  @override
  State<DeliveryOrPickupWrapperPage> createState() =>
      _DeliveryOrPickupWrapperPageState();
}

class _DeliveryOrPickupWrapperPageState
    extends State<DeliveryOrPickupWrapperPage> {
  late bool _isPickup;

  @override
  void initState() {
    super.initState();
    _isPickup = widget.initialPickup;
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _isPickup ? 0 : 1,
      children: [
        PickupPointsPage(
          initialDeliveryMethod: 1,
          selectedPoint: widget.selectedPoint,
          productId: widget.productId,
          onSwitchToDelivery: () => setState(() => _isPickup = false),
        ),
        DeliveryAddressPage(
          onSwitchToSamovyvoz: () => setState(() => _isPickup = true),
          initialDeliveryData: widget.initialDeliveryData,
          openSheetOnStart: widget.openDeliverySheetOnStart,
        ),
      ],
    );
  }
}

class PickupPointsPage extends StatefulWidget {
  final int initialDeliveryMethod;
  final Map<String, dynamic>? selectedPoint;
  final String? productId;
  final VoidCallback? onSwitchToDelivery;

  const PickupPointsPage({
    super.key,
    required this.initialDeliveryMethod,
    this.selectedPoint,
    this.productId,
    this.onSwitchToDelivery,
  });

  @override
  State<PickupPointsPage> createState() => _PickupPointsPageState();
}

class DeliveryAddressPage extends StatefulWidget {
  final VoidCallback? onSwitchToSamovyvoz;
  final Map<String, dynamic>? initialDeliveryData;
  final bool openSheetOnStart;

  const DeliveryAddressPage({
    super.key,
    this.onSwitchToSamovyvoz,
    this.initialDeliveryData,
    this.openSheetOnStart = false,
  });

  @override
  State<DeliveryAddressPage> createState() => _DeliveryAddressPageState();
}

class _GeocodeLookupResult {
  final Point point;
  final bool isPrecise;

  const _GeocodeLookupResult({required this.point, required this.isPrecise});
}

class _DeliveryAddressPageState extends State<DeliveryAddressPage> {
  static const double _deliverySheetDismissDragThreshold = 72;
  static const double _deliveryAddressSelectedZoom = 17.6;
  static const double _deliveryMarkerShiftBySheetFactor = 0.38;
  static const Duration _deliverySheetAnimationDuration = Duration(
    milliseconds: 140,
  );
  static const Curve _deliverySheetAnimationCurve = Curves.easeOutCubic;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _searchScrollController = ScrollController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  YandexMapController? _mapController;
  List<Map<String, dynamic>> _suggestions = [];
  bool _suggestionsLoading = false;
  String? _suggestionsMessage;
  Timer? _suggestDebounce;
  int _suggestRequestId = 0;
  bool _isGeocoding = false;
  Point? _selectedDeliveryPoint;
  bool _deliverySheetVisible = false;
  double? _deliverySheetSwipeStartY;
  int? _deliverySheetSwipeStartMs;
  double _deliverySheetDragOffset = 0;
  bool _isDeliverySheetDragging = false;
  final bool _renderDeliverySheetOnRoot = true;
  Uint8List? _deliveryPinBytes;
  bool _isPrivateHouse = false;
  bool _needLift = false;
  int _liftFloor = 1;
  bool _hasCargoLiftForOrder = false;
  String _deliveryDate = '';
  String _deliveryTime = '';
  int _suggestSelectionGeocodeSeq = 0;

  static bool _toBoolFlag(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true' || normalized == 'yes';
    }
    return false;
  }

  static int _toIntOrDefault(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  Point? _pointFromRaw(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final latRaw = map['lat'] ?? map['latitude'];
    final lngRaw = map['lng'] ?? map['lon'] ?? map['longitude'];
    final lat = latRaw is num
        ? latRaw.toDouble()
        : double.tryParse(latRaw?.toString() ?? '');
    final lng = lngRaw is num
        ? lngRaw.toDouble()
        : double.tryParse(lngRaw?.toString() ?? '');
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return Point(latitude: lat, longitude: lng);
  }

  void _restoreInitialDeliveryData() {
    final data = widget.initialDeliveryData;
    if (data == null || data.isEmpty) return;

    final initialAddress = (data['address']?.toString() ?? '').trim();
    if (initialAddress.isNotEmpty) {
      _searchController.value = TextEditingValue(
        text: initialAddress,
        selection: TextSelection.collapsed(offset: initialAddress.length),
      );
    }
    _apartmentController.text = (data['apartment']?.toString() ?? '').trim();
    _commentController.text = (data['comment']?.toString() ?? '').trim();
    _deliveryDate = (data['date']?.toString() ?? '').trim();
    _deliveryTime = (data['time']?.toString() ?? '').trim();
    _selectedDeliveryPoint = _pointFromRaw(data['point']);
    _isPrivateHouse = _toBoolFlag(data['is_private_house']);
    _needLift = _toBoolFlag(data['need_lift']);
    _liftFloor = _toIntOrDefault(data['lift_floor'], 1).clamp(1, 25).toInt();
    _hasCargoLiftForOrder = _toBoolFlag(data['has_cargo_lift']);

    if (_isPrivateHouse) {
      _needLift = false;
      _liftFloor = 1;
      _hasCargoLiftForOrder = false;
    }
    if (widget.openSheetOnStart &&
        (_selectedDeliveryPoint != null || initialAddress.isNotEmpty)) {
      _deliverySheetVisible = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _restoreInitialDeliveryData();
    _searchController.addListener(_onSearchTextChanged);
    _loadDeliveryPinIcon();
  }

  void _onDeliverySheetPointerDown(PointerDownEvent event) {
    _deliverySheetSwipeStartY = event.position.dy;
    _deliverySheetSwipeStartMs = DateTime.now().millisecondsSinceEpoch;
  }

  bool get _isDeliverySheetAtTop => true;

  void _onDeliverySheetPointerMove(
    PointerMoveEvent event,
    double maxSheetHeight,
  ) {
    final startY = _deliverySheetSwipeStartY;
    if (startY == null) return;
    final deltaY = event.position.dy - startY;
    final canTrackDrag = _isDeliverySheetAtTop || _isDeliverySheetDragging;
    if (!canTrackDrag) return;
    final nextOffset = deltaY <= 0
        ? 0.0
        : (deltaY * 0.92).clamp(0.0, maxSheetHeight);
    if ((nextOffset - _deliverySheetDragOffset).abs() < 0.5) return;
    if (!mounted) return;
    setState(() {
      _deliverySheetDragOffset = nextOffset;
      _isDeliverySheetDragging = true;
    });
  }

  void _onDeliverySheetPointerUp(PointerUpEvent event, double maxSheetHeight) {
    final startY = _deliverySheetSwipeStartY;
    final startMs = _deliverySheetSwipeStartMs;
    _deliverySheetSwipeStartY = null;
    _deliverySheetSwipeStartMs = null;
    if (startY == null) return;
    final deltaY = event.position.dy - startY;
    final elapsedMs = startMs == null
        ? 0
        : DateTime.now().millisecondsSinceEpoch - startMs;
    final velocityY = elapsedMs > 0 ? (deltaY / elapsedMs) * 1000 : 0.0;
    final dismissByOffset =
        _deliverySheetDragOffset >= maxSheetHeight * 0.22 ||
        deltaY > _deliverySheetDismissDragThreshold;
    final dismissByVelocity = velocityY > 950;
    final shouldDismiss =
        _isDeliverySheetAtTop &&
        deltaY > 0 &&
        (dismissByOffset || dismissByVelocity);
    if (!mounted) return;
    if (shouldDismiss) {
      _dismissDeliverySheet();
      return;
    }
    setState(() {
      _isDeliverySheetDragging = false;
      _deliverySheetDragOffset = 0;
    });
  }

  void _onDeliverySheetPointerCancel(PointerCancelEvent event) {
    _deliverySheetSwipeStartY = null;
    _deliverySheetSwipeStartMs = null;
    if (!mounted) return;
    if (!_isDeliverySheetDragging && _deliverySheetDragOffset == 0) return;
    setState(() {
      _isDeliverySheetDragging = false;
      _deliverySheetDragOffset = 0;
    });
  }

  void _showDeliverySheet() {
    if (!mounted) return;
    setState(() {
      _deliverySheetVisible = true;
      _deliverySheetDragOffset = 0;
      _isDeliverySheetDragging = false;
    });
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _setSearchTextAndCursorToEnd(String value) {
    _searchController.value = _searchController.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
    if (!_searchFocusNode.hasFocus) _searchFocusNode.requestFocus();
    _ensureSearchTextEndVisible();
  }

  void _ensureSearchTextEndVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final text = _searchController.text;
      _searchController.selection = TextSelection.collapsed(
        offset: text.length,
      );
      if (!_searchFocusNode.hasFocus) _searchFocusNode.requestFocus();
      if (_searchScrollController.hasClients) {
        final maxScroll = _searchScrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _searchScrollController.jumpTo(maxScroll);
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_searchScrollController.hasClients) return;
        final maxScroll = _searchScrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _searchScrollController.jumpTo(maxScroll);
        }
      });
    });
  }

  Future<void> _onDeliveryPointSelected(Point point) async {
    _showDeliverySheet();
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    await _moveCameraToDeliveryPointVisible(point);
    final address = await _reverseGeocode(point);
    if (mounted && address != null) {
      setState(() => _searchController.text = address);
    }
  }

  double _deliverySheetTargetHeight() {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    return (mediaQuery.size.height - mediaQuery.padding.top - keyboardInset - 8)
        .clamp(180.0, mediaQuery.size.height)
        .toDouble();
  }

  Point _deliveryCameraTargetWithSheetOffset(Point point, double zoom) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = _deliverySheetTargetHeight();
    final shiftPx = (sheetHeight * _deliveryMarkerShiftBySheetFactor)
        .clamp(110.0, mediaQuery.size.height * 0.34)
        .toDouble();
    final latitudeRad = point.latitude * math.pi / 180.0;
    final cosLatitude = math.cos(latitudeRad).abs().clamp(0.01, 1.0).toDouble();
    final metersPerPixel = 156543.03392 * cosLatitude / math.pow(2.0, zoom);
    final metersShift = metersPerPixel * shiftPx;
    final latitudeShift = (metersShift / 6378137.0) * (180.0 / math.pi);
    final shiftedLatitude = (point.latitude - latitudeShift)
        .clamp(-85.0, 85.0)
        .toDouble();
    return Point(latitude: shiftedLatitude, longitude: point.longitude);
  }

  Future<void> _moveCameraToDeliveryPointVisible(Point point) async {
    final controller = _mapController;
    if (controller == null) return;
    final target = _deliveryCameraTargetWithSheetOffset(
      point,
      _deliveryAddressSelectedZoom,
    );
    try {
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: _deliveryAddressSelectedZoom),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.linear,
          duration: 0.3,
        ),
      );
    } catch (_) {}
  }

  void _dismissDeliverySheet() {
    if (!mounted) return;
    _dismissKeyboard();
    setState(() {
      _deliverySheetVisible = false;
      _deliverySheetDragOffset = 0;
      _isDeliverySheetDragging = false;
      _deliverySheetSwipeStartY = null;
      _deliverySheetSwipeStartMs = null;
    });
  }

  Widget _buildDeliverySheetPositioned({
    required EdgeInsets padding,
    required double keyboardInset,
    required double deliverySheetMaxHeight,
    required double deliverySheetDragFraction,
    required double deliverySheetOpacity,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: keyboardInset,
      child: IgnorePointer(
        ignoring: !_deliverySheetVisible,
        child: AnimatedSlide(
          offset: _deliverySheetVisible
              ? Offset(0, deliverySheetDragFraction)
              : const Offset(0, 1),
          duration: _isDeliverySheetDragging
              ? Duration.zero
              : _deliverySheetAnimationDuration,
          curve: _deliverySheetAnimationCurve,
          child: AnimatedOpacity(
            opacity: deliverySheetOpacity,
            duration: _isDeliverySheetDragging
                ? Duration.zero
                : _deliverySheetAnimationDuration,
            curve: _deliverySheetAnimationCurve,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onDeliverySheetPointerDown,
              onPointerMove: (event) =>
                  _onDeliverySheetPointerMove(event, deliverySheetMaxHeight),
              onPointerUp: (event) =>
                  _onDeliverySheetPointerUp(event, deliverySheetMaxHeight),
              onPointerCancel: _onDeliverySheetPointerCancel,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: deliverySheetMaxHeight,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissKeyboard,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        10 + padding.bottom,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 10),
                            child: Center(
                              child: Container(
                                width: 34,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(5, 0, 5, 10),
                            child: Text(
                              _searchController.text.isEmpty
                                  ? "Укажите адрес доставки"
                                  : _searchController.text,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: TextField(
                                    controller: _apartmentController,
                                    onTapOutside: (_) => _dismissKeyboard(),
                                    cursorColor: Colors.black,
                                    decoration: InputDecoration(
                                      hintText: "№ квартиры",
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 15,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade700,
                                          width: 1.2,
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 11,
                                          ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => setState(() {
                                      _isPrivateHouse = !_isPrivateHouse;
                                      if (_isPrivateHouse) {
                                        _needLift = false;
                                        _liftFloor = 1;
                                        _hasCargoLiftForOrder = false;
                                      }
                                    }),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F2F6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: _isPrivateHouse,
                                            onChanged: (v) => setState(() {
                                              _isPrivateHouse = v ?? false;
                                              if (_isPrivateHouse) {
                                                _needLift = false;
                                                _liftFloor = 1;
                                                _hasCargoLiftForOrder = false;
                                              }
                                            }),
                                            activeColor: Colors.black,
                                            checkColor: Colors.white,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                            side: BorderSide(
                                              color: Colors.grey.shade700,
                                              width: 1.2,
                                            ),
                                          ),
                                          const Expanded(
                                            child: Text(
                                              "Частный дом",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_isPrivateHouse) ...[
                            const SizedBox(height: 8),
                            if (!_needLift)
                              SizedBox(
                                height: 40,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(() => _needLift = true),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F2F6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _needLift,
                                          onChanged: (v) => setState(
                                            () => _needLift = v ?? false,
                                          ),
                                          activeColor: Colors.black,
                                          checkColor: Colors.white,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                          side: BorderSide(
                                            color: Colors.grey.shade700,
                                            width: 1.2,
                                          ),
                                        ),
                                        const Expanded(
                                          child: Text(
                                            "Нужен подъем на этаж",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else ...[
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _needLift,
                                      onChanged: (v) => setState(() {
                                        _needLift = v ?? false;
                                        if (!_needLift) {
                                          _liftFloor = 1;
                                          _hasCargoLiftForOrder = false;
                                        }
                                      }),
                                      activeColor: Colors.black,
                                      checkColor: Colors.white,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      side: BorderSide(
                                        color: Colors.grey.shade700,
                                        width: 1.2,
                                      ),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        "Нужен подъем на этаж",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    PopupMenuButton<int>(
                                      initialValue: _liftFloor,
                                      onSelected: (value) {
                                        if (!mounted) return;
                                        setState(() => _liftFloor = value);
                                      },
                                      itemBuilder: (context) =>
                                          List.generate(25, (index) {
                                            final floor = index + 1;
                                            return PopupMenuItem<int>(
                                              value: floor,
                                              child: Text('$floor'),
                                            );
                                          }),
                                      offset: const Offset(0, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      color: Colors.white,
                                      child: Container(
                                        width: 76,
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '$_liftFloor',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const Spacer(),
                                            Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: Colors.grey.shade500,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(
                                    () => _hasCargoLiftForOrder =
                                        !_hasCargoLiftForOrder,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F2F6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _hasCargoLiftForOrder,
                                          onChanged: (v) => setState(
                                            () => _hasCargoLiftForOrder =
                                                v ?? false,
                                          ),
                                          activeColor: Colors.black,
                                          checkColor: Colors.white,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                          side: BorderSide(
                                            color: Colors.grey.shade700,
                                            width: 1.2,
                                          ),
                                        ),
                                        const Expanded(
                                          child: Text(
                                            "Есть лифт, вмещающий весь заказ",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 6),
                          const Text(
                            "Выберите дату и время доставки",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 60),
                                        ),
                                        builder: (context, child) {
                                          final base = Theme.of(context);
                                          return Theme(
                                            data: base.copyWith(
                                              colorScheme: base.colorScheme
                                                  .copyWith(
                                                    primary: Colors.black,
                                                    onPrimary: Colors.white,
                                                    onSurface: Colors.black87,
                                                  ),
                                              textButtonTheme:
                                                  TextButtonThemeData(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.black,
                                                    ),
                                                  ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (d != null) {
                                        setState(
                                          () => _deliveryDate =
                                              '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
                                        );
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: "Дата",
                                        labelStyle: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.black87,
                                            width: 1.2,
                                          ),
                                        ),
                                        isDense: false,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                      ),
                                      child: Text(
                                        _deliveryDate.isEmpty
                                            ? "Выбрать"
                                            : _deliveryDate,
                                        style: TextStyle(
                                          color: _deliveryDate.isEmpty
                                              ? Colors.grey
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: InkWell(
                                    onTap: () async {
                                      final t = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                        builder: (context, child) {
                                          final base = Theme.of(context);
                                          const inactiveSurface = Color(
                                            0xFFF2F2F6,
                                          );
                                          return Theme(
                                            data: base.copyWith(
                                              colorScheme: base.colorScheme
                                                  .copyWith(
                                                    primary: Colors.black,
                                                    onPrimary: Colors.white,
                                                    secondary: Colors.black,
                                                    onSecondary: Colors.white,
                                                    tertiary: Colors.black,
                                                    onTertiary: Colors.white,
                                                    surface: Colors.white,
                                                    onSurface: Colors.black87,
                                                  ),
                                              textButtonTheme:
                                                  TextButtonThemeData(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.black,
                                                    ),
                                                  ),
                                              timePickerTheme: base
                                                  .timePickerTheme
                                                  .copyWith(
                                                    backgroundColor:
                                                        Colors.white,
                                                    hourMinuteColor:
                                                        inactiveSurface,
                                                    dialHandColor: Colors.black,
                                                    dialBackgroundColor:
                                                        inactiveSurface,
                                                    hourMinuteTextColor:
                                                        Colors.black87,
                                                    dayPeriodColor:
                                                        inactiveSurface,
                                                    dayPeriodTextColor:
                                                        Colors.black87,
                                                    entryModeIconColor:
                                                        Colors.black,
                                                  ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (t != null) {
                                        setState(
                                          () => _deliveryTime =
                                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                                        );
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: "Время",
                                        labelStyle: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.black87,
                                            width: 1.2,
                                          ),
                                        ),
                                        isDense: false,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                      ),
                                      child: Text(
                                        _deliveryTime.isEmpty
                                            ? "Выбрать"
                                            : _deliveryTime,
                                        style: TextStyle(
                                          color: _deliveryTime.isEmpty
                                              ? Colors.grey
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _commentController,
                            onTapOutside: (_) => _dismissKeyboard(),
                            cursorColor: Colors.black,
                            decoration: InputDecoration(
                              labelText: "Комментарий",
                              labelStyle: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Colors.black87,
                                  width: 1.2,
                                ),
                              ),
                              alignLabelWithHint: true,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            minLines: 2,
                            maxLines: null,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context, {
                                  'result_type': 'delivery',
                                  'address': _searchController.text.trim(),
                                  'date': _deliveryDate.trim(),
                                  'time': _deliveryTime.trim(),
                                  'apartment': _apartmentController.text.trim(),
                                  'comment': _commentController.text.trim(),
                                  'is_private_house': _isPrivateHouse,
                                  'need_lift': _needLift,
                                  'lift_floor': _liftFloor,
                                  'has_cargo_lift': _hasCargoLiftForOrder,
                                  if (_selectedDeliveryPoint != null)
                                    'point': {
                                      'lat': _selectedDeliveryPoint!.latitude,
                                      'lng': _selectedDeliveryPoint!.longitude,
                                    },
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text("Подтвердить"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadDeliveryPinIcon() async {
    const candidates = <String>[
      _deliveryAddressPinAssetPath,
      _shopPinAssetPath,
      _userPinAssetPath,
    ];
    for (final assetPath in candidates) {
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        if (bytes.isNotEmpty && mounted) {
          setState(() => _deliveryPinBytes = bytes);
          return;
        }
      } catch (_) {
        // Try next candidate asset.
      }
    }
  }

  void _onSearchTextChanged() {
    if (!mounted) return;
    setState(() {});
    if (_yandexSuggestApiKey.isEmpty) return;
    final query = _searchController.text.trim();
    if (query.length < 2) {
      _suggestDebounce?.cancel();
      setState(() {
        _suggestions = [];
        _suggestionsMessage = null;
        _suggestionsLoading = false;
      });
      return;
    }
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 280), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;
    final requestId = ++_suggestRequestId;
    setState(() {
      _suggestionsLoading = true;
      _suggestionsMessage = null;
    });
    try {
      // Сначала пробуем v1/suggest (ключ «API Геосаджеста») — стабильный формат с results[].title.text и uri
      final v1Uri = Uri.parse(
        'https://suggest-maps.yandex.ru/v1/suggest'
        '?apikey=$_yandexSuggestApiKey'
        '&text=${Uri.encodeComponent(query)}'
        '&lang=ru_RU'
        '&results=7'
        '&print_address=1'
        '&attrs=uri',
      );
      var response = await _httpGetYandex(v1Uri);
      var list = <Map<String, dynamic>>[];
      if (response.statusCode == 403) {
        // При 403 пробуем suggest-geo (ключ «JavaScript API и HTTP Геокодер»)
        final geoUri = Uri.parse(
          'https://suggest-maps.yandex.ru/suggest-geo'
          '?v=5'
          '&lang=ru_RU'
          '&search_type=tp'
          '&part=${Uri.encodeComponent(query)}'
          '&apikey=$_yandexSuggestApiKey',
        );
        response = await _httpGetYandex(geoUri);
        if (!mounted || requestId != _suggestRequestId) return;
        if (response.statusCode == 403) {
          String msg =
              'Подсказки недоступны. Проверьте ключ API в кабинете Яндекса.';
          try {
            final err = json.decode(response.body) as Map<String, dynamic>?;
            final detail =
                err?['message'] as String? ?? err?['error'] as String?;
            if (detail != null && detail.isNotEmpty) msg = detail;
            if (kDebugMode) debugPrint('Yandex Suggest 403: ${response.body}');
          } catch (_) {
            if (kDebugMode) {
              debugPrint('Yandex Suggest 403 body: ${response.body}');
            }
          }
          setState(() {
            _suggestions = [];
            _suggestionsLoading = false;
            _suggestionsMessage = msg;
          });
          return;
        }
      }
      if (!mounted || requestId != _suggestRequestId) return;
      if (response.statusCode != 200) {
        setState(() {
          _suggestions = [];
          _suggestionsLoading = false;
          _suggestionsMessage = 'Ошибка загрузки (${response.statusCode}).';
        });
        return;
      }
      list = _parseSuggestResponse(response.body);
      if (list.isEmpty && kDebugMode) {
        final preview = response.body.length > 400
            ? '${response.body.substring(0, 400)}...'
            : response.body;
        debugPrint('Yandex Suggest empty parse, response: $preview');
      }
      if (!mounted || requestId != _suggestRequestId) return;
      setState(() {
        _suggestions = list;
        _suggestionsLoading = false;
        _suggestionsMessage = list.isEmpty ? 'Ничего не найдено' : null;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Yandex Suggest error: $e');
        debugPrint(st.toString());
      }
      if (mounted && requestId == _suggestRequestId) {
        setState(() {
          _suggestions = [];
          _suggestionsLoading = false;
          _suggestionsMessage = 'Ошибка загрузки. Проверьте интернет.';
        });
      }
    }
  }

  /// Парсит ответ suggest-geo или v1/suggest.
  List<Map<String, dynamic>> _parseSuggestResponse(String body) {
    final list = <Map<String, dynamic>>[];
    try {
      final data = json.decode(body);
      // v1/suggest: { "results": [ { "title": { "text": "..." }, "subtitle": { "text": "..." }, "uri": "..." } ] }
      final map = data is Map<String, dynamic> ? data : null;
      final results =
          map?['results'] as List<dynamic>? ?? map?['items'] as List<dynamic>?;
      if (results != null) {
        for (final r in results) {
          if (r is! Map<String, dynamic>) continue;
          final uriStr = r['uri'] as String?;
          final address = r['address'];
          final formattedAddress = address is Map
              ? address['formatted_address'] as String?
              : null;
          final title = r['title'];
          String? titleText = formattedAddress?.trim();
          if (titleText == null || titleText.isEmpty) {
            if (title is Map && title['text'] != null) {
              titleText = title['text'] as String?;
            } else {
              titleText =
                  r['value'] as String? ??
                  r['displayName'] as String? ??
                  r['title'] as String?;
            }
          }
          final subtitle =
              (r['subtitle'] is Map && (r['subtitle'] as Map)['text'] != null)
              ? (r['subtitle'] as Map)['text'] as String
              : null;
          if (titleText != null && titleText.isNotEmpty) {
            list.add({'title': titleText, 'subtitle': subtitle, 'uri': uriStr});
          }
        }
        if (list.isNotEmpty) return list;
      }
      // suggest-geo: массив [ запрос, [ { displayName, value } или { title, ... } ] ] или просто массив объектов
      if (data is List) {
        List<dynamic> items = data;
        if (items.length >= 2 && items[1] is List) {
          items = items[1] as List<dynamic>;
        }
        for (final r in items) {
          if (r is String && r.isNotEmpty) {
            list.add({'title': r, 'subtitle': null, 'uri': null});
            continue;
          }
          if (r is Map<String, dynamic>) {
            final displayName = r['displayName'] as String?;
            final value = r['value'] as String? ?? displayName;
            final titleStr = r['title'] is String
                ? r['title'] as String?
                : null;
            final name =
                value ??
                titleStr ??
                r['name'] as String? ??
                r['text'] as String?;
            if (name != null && name.isNotEmpty) {
              list.add({
                'title': name,
                'subtitle': displayName != name
                    ? displayName
                    : (r['subtitle'] as String?),
                'uri': r['uri'] as String?,
              });
            }
          }
        }
      }
    } catch (_) {}
    return list;
  }

  Future<void> _onSuggestionSelected(Map<String, dynamic> suggestion) async {
    final uriStr = suggestion['uri'] as String?;
    final title = suggestion['title'] as String? ?? '';
    final normalizedTitle = title.trim().replaceAll(RegExp(r'[\s,]+$'), '');
    if (normalizedTitle.isEmpty) return;
    _suggestDebounce?.cancel();
    final selectionSeq = ++_suggestSelectionGeocodeSeq;
    var displayText = normalizedTitle;
    _setSearchTextAndCursorToEnd(displayText);
    if (!mounted) return;
    setState(() {
      _suggestions = [];
      _suggestionsMessage = null;
      _suggestionsLoading = false;
      _isGeocoding = false;
    });

    var lookup = await _geocodeAddressWithMeta(
      uriStr: uriStr,
      addressText: normalizedTitle,
    );
    if (lookup == null && uriStr != null) {
      lookup = await _geocodeAddressWithMeta(
        uriStr: null,
        addressText: normalizedTitle,
      );
    }

    if (!mounted || selectionSeq != _suggestSelectionGeocodeSeq) return;

    if (lookup == null || !lookup.isPrecise) {
      final withComma = '$normalizedTitle, ';
      if (displayText != withComma) {
        displayText = withComma;
        _setSearchTextAndCursorToEnd(displayText);
      }
      setState(() {
        _selectedDeliveryPoint = null;
        _deliverySheetVisible = false;
        _deliverySheetDragOffset = 0;
        _isDeliverySheetDragging = false;
      });
      _suggestDebounce = Timer(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        final query = _searchController.text.trim();
        if (query.length >= 2) {
          _fetchSuggestions(query);
        }
      });
      return;
    }

    final targetPoint = lookup.point;
    _dismissKeyboard();
    setState(() {
      _selectedDeliveryPoint = targetPoint;
    });
    _showDeliverySheet();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await _moveCameraToDeliveryPointVisible(targetPoint);
  }

  List<MapObject> _buildDeliveryMapObjects() {
    if (_selectedDeliveryPoint == null || _deliveryPinBytes == null) {
      return const [];
    }
    return [
      PlacemarkMapObject(
        mapId: const MapObjectId('delivery_address'),
        point: _selectedDeliveryPoint!,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromBytes(_deliveryPinBytes!),
            anchor: const Offset(0.5, 1.0),
            scale: 0.9,
          ),
        ),
        opacity: _mapPlacemarkOpacity,
        zIndex: 1000,
      ),
    ];
  }

  Point? _parsePointFromGeoObject(Map<String, dynamic> geo) {
    final posStr = geo['Point']?['pos'] as String?;
    if (posStr == null) return null;
    final parts = posStr.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final lon = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lon == null || lat == null) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return Point(latitude: lat, longitude: lon);
  }

  /// Геокодирование: возвращает точку и признак "точного" адреса (дом/точное совпадение).
  Future<_GeocodeLookupResult?> _geocodeAddressWithMeta({
    String? uriStr,
    required String addressText,
  }) async {
    try {
      final uri = Uri.parse(
        uriStr != null
            ? 'https://geocode-maps.yandex.ru/1.x/'
                  '?apikey=$_yandexSuggestApiKey'
                  '&uri=${Uri.encodeComponent(uriStr)}'
                  '&lang=ru_RU'
                  '&format=json'
            : 'https://geocode-maps.yandex.ru/1.x/'
                  '?apikey=$_yandexSuggestApiKey'
                  '&geocode=${Uri.encodeComponent(addressText)}'
                  '&lang=ru_RU'
                  '&format=json',
      );
      final response = await _httpGetYandex(uri);
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>?;
      final collection = data?['response']?['GeoObjectCollection'];
      final members = collection?['featureMember'] as List<dynamic>?;
      if (members == null || members.isEmpty) return null;
      Map<String, dynamic>? fallback;
      Map<String, dynamic>? precise;
      for (final m in members) {
        if (m is! Map) continue;
        final geo = m['GeoObject'];
        if (geo is! Map<String, dynamic>) continue;
        fallback ??= geo;
        final meta = geo['metaDataProperty']?['GeocoderMetaData'];
        final kind = meta is Map ? meta['kind'] as String? : null;
        final precision = meta is Map ? meta['precision'] as String? : null;
        if (kind == 'house' || precision == 'exact') {
          precise = geo;
          break;
        }
      }
      final selectedGeo = precise ?? fallback;
      if (selectedGeo == null) return null;
      final point = _parsePointFromGeoObject(selectedGeo);
      if (point == null) return null;
      return _GeocodeLookupResult(point: point, isPrecise: precise != null);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchScrollController.dispose();
    _apartmentController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<String?> _reverseGeocode(Point point) async {
    try {
      final uri = Uri.parse(
        'https://geocode-maps.yandex.ru/1.x/'
        '?apikey=$_yandexSuggestApiKey'
        '&geocode=${point.longitude},${point.latitude}'
        '&lang=ru_RU'
        '&format=json',
      );
      final response = await _httpGetYandex(uri);
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>?;
      final members =
          data?['response']?['GeoObjectCollection']?['featureMember']
              as List<dynamic>?;
      if (members == null || members.isEmpty) return null;
      final meta =
          members.first['GeoObject']?['metaDataProperty']?['GeocoderMetaData'];
      final addr = meta?['Address'];
      final formatted =
          addr?['formatted'] as String? ?? meta?['text'] as String?;
      return formatted?.trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final deliverySheetMaxHeight =
        (mediaQuery.size.height - padding.top - keyboardInset - 8)
            .clamp(180.0, mediaQuery.size.height)
            .toDouble();
    final double deliverySheetDragFraction =
        (deliverySheetMaxHeight <= 0
                ? 0.0
                : _deliverySheetDragOffset / deliverySheetMaxHeight)
            .clamp(0.0, 0.95)
            .toDouble();
    final double deliverySheetOpacity = _deliverySheetVisible
        ? (1 - deliverySheetDragFraction * 0.15).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.black,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    "Детали доставки",
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 8, 5, 10),
                child: SizedBox(
                  height: 34,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final indicatorWidth = (constraints.maxWidth - 4) / 2;
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F6),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              left: 2 + indicatorWidth,
                              top: 2,
                              bottom: 2,
                              width: indicatorWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      if (widget.onSwitchToSamovyvoz != null) {
                                        widget.onSwitchToSamovyvoz!();
                                      } else {
                                        Navigator.pushReplacement(
                                          context,
                                          _adaptivePageRoute(
                                            builder: (_) =>
                                                const PickupPointsPage(
                                                  initialDeliveryMethod: 1,
                                                  selectedPoint: null,
                                                  productId: null,
                                                ),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Center(
                                      child: Text(
                                        "Самовывоз",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {},
                                    child: const Center(
                                      child: Text(
                                        "Доставка",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: YandexMap(
                        tiltGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        mode2DEnabled: true,
                        onMapCreated: (controller) async {
                          _mapController = controller;
                          var target = const Point(
                            latitude: 43.1150678,
                            longitude: 131.8855768,
                          );
                          var zoom = 12.0;
                          if (_selectedDeliveryPoint != null) {
                            zoom = _deliveryAddressSelectedZoom;
                            target =
                                (_deliverySheetVisible ||
                                    widget.openSheetOnStart)
                                ? _deliveryCameraTargetWithSheetOffset(
                                    _selectedDeliveryPoint!,
                                    zoom,
                                  )
                                : _selectedDeliveryPoint!;
                          }
                          await controller.moveCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(target: target, zoom: zoom),
                            ),
                            animation: const MapAnimation(
                              type: MapAnimationType.linear,
                              duration: 0.3,
                            ),
                          );
                        },
                        onMapTap: (Point point) async {
                          setState(() {
                            _selectedDeliveryPoint = point;
                          });
                          await _onDeliveryPointSelected(point);
                        },
                        mapObjects: _buildDeliveryMapObjects(),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 8,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        elevation: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                scrollController: _searchScrollController,
                                textAlignVertical: TextAlignVertical.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Найти на карте",
                                  hintStyle: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black38,
                                  ),
                                  isDense: true,
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 22,
                                    color: Colors.black38,
                                  ),
                                  suffixIcon:
                                      _searchController.text.trim().isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 20,
                                            color: Colors.black54,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _suggestions = [];
                                              _suggestionsMessage = null;
                                            });
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 40,
                                            minHeight: 40,
                                          ),
                                        ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            if (_isGeocoding)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(18),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Ищем на карте...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (!_isGeocoding &&
                                _searchFocusNode.hasFocus &&
                                (_suggestions.isNotEmpty ||
                                    _suggestionsLoading ||
                                    _suggestionsMessage != null)) ...[
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 260,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(18),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: _suggestionsLoading
                                    ? const Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      )
                                    : _suggestionsMessage != null
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Center(
                                          child: Text(
                                            _suggestionsMessage!,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                          left: 4,
                                          right: 4,
                                          top: 4,
                                        ),
                                        shrinkWrap: true,
                                        physics: const ClampingScrollPhysics(),
                                        itemCount: _suggestions.length,
                                        itemBuilder: (context, index) {
                                          final s = _suggestions[index];
                                          final title =
                                              s['title'] as String? ?? '';
                                          final subtitle =
                                              s['subtitle'] as String?;
                                          return Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () =>
                                                  _onSuggestionSelected(s),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 48,
                                                    ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        title,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          color: Colors.black87,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      if (subtitle != null &&
                                                          subtitle
                                                              .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          subtitle,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_selectedDeliveryPoint != null &&
                        !_renderDeliverySheetOnRoot)
                      _buildDeliverySheetPositioned(
                        padding: padding,
                        keyboardInset: keyboardInset,
                        deliverySheetMaxHeight: deliverySheetMaxHeight,
                        deliverySheetDragFraction: deliverySheetDragFraction,
                        deliverySheetOpacity: deliverySheetOpacity,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_selectedDeliveryPoint != null && _renderDeliverySheetOnRoot) ...[
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_deliverySheetVisible,
              child: AnimatedOpacity(
                opacity: _deliverySheetVisible ? 1 : 0,
                duration: _deliverySheetAnimationDuration,
                curve: _deliverySheetAnimationCurve,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismissDeliverySheet,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.14),
                  ),
                ),
              ),
            ),
          ),
          _buildDeliverySheetPositioned(
            padding: padding,
            keyboardInset: keyboardInset,
            deliverySheetMaxHeight: deliverySheetMaxHeight,
            deliverySheetDragFraction: deliverySheetDragFraction,
            deliverySheetOpacity: deliverySheetOpacity,
          ),
        ],
      ],
    );
  }
}

class PickupPoint {
  final String id;
  final String stockId;
  final String name;
  final String address;
  final String workTime;
  final String eta;
  final bool isAvailable;
  final int count;
  final double? lat;
  final double? lng;
  final int? utcOffsetMinutes;

  const PickupPoint({
    required this.id,
    required this.stockId,
    required this.name,
    required this.address,
    required this.workTime,
    required this.eta,
    required this.isAvailable,
    required this.count,
    required this.lat,
    required this.lng,
    required this.utcOffsetMinutes,
  });

  factory PickupPoint.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? json['stock_id'];
    final id = idRaw?.toString().trim() ?? '';
    final stockIdRaw = json['stock_id']?.toString().trim();
    final workTimeRaw = (json['work_time'] ?? '').toString();
    return PickupPoint(
      id: id,
      stockId: stockIdRaw?.isNotEmpty == true ? stockIdRaw! : id,
      name: json['name']?.toString() ?? 'Пункт выдачи',
      address: json['address']?.toString() ?? '',
      workTime: workTimeRaw.isNotEmpty
          ? workTimeRaw
          : json['worktime']?.toString() ?? '',
      eta: json['eta']?.toString() ?? '',
      isAvailable: _toBoolValue(json['is_available']),
      count: _toIntValue(json['count']),
      lat: _toDoubleValue(json['lat']),
      lng: _toDoubleValue(json['lng']),
      utcOffsetMinutes: _parseUtcOffsetMinutes(json),
    );
  }

  bool get hasValidCoordinates => lat != null && lng != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stock_id': stockId,
      'name': name,
      'address': address,
      'worktime': workTime,
      'work_time': workTime,
      'eta': eta,
      'is_available': isAvailable,
      'count': count,
      'lat': lat,
      'lng': lng,
      'utc_offset': utcOffsetMinutes,
      'utc_offset_minutes': utcOffsetMinutes,
    };
  }

  static int? _parseUtcOffsetMinutes(Map<String, dynamic> json) {
    final raw = json['utc_offset'] ?? json['utc_offset_minutes'];
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static double? _toDoubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int _toIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _toBoolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true' || normalized == 'yes';
    }
    return false;
  }
}

class _PickupPointsPageState extends State<PickupPointsPage>
    with WidgetsBindingObserver {
  static const String _pointsUrl = '/native/get_points.php';
  static const double _sheetInitialChildSize = _sheetMinChildSize;
  static const double _sheetMinChildSize = 0.17;
  static const double _sheetMaxChildSize = 1.0;
  static const double _sheetTopFlatExtent = _sheetMaxChildSize - 0.002;
  static const Duration _sheetSnapDuration = Duration(milliseconds: 140);
  static const double _focusStoreZoom = 16.2;
  static const double _focusUserZoom = 16.0;
  static const double _initialMapZoom = 14.6;
  static const Color _pickupBorderColor = Color(0xFFE3E4E8);
  static const Color _pickupAddressColor = Color(0xFF4C5159);
  static const Color _pickupWorktimeColor = Color(0xFF8A8F98);
  static const Color _pickupAccentColor = Color(0xFF63B45D);
  static const BorderRadius _pickupCardRadius = BorderRadius.all(
    Radius.circular(14),
  );
  static const Point _defaultMapCenter = Point(
    latitude: 55.751244,
    longitude: 37.618423,
  );
  static final RegExp _etaHighlightRegex = RegExp(
    r'(сегодня|завтра|\d{1,2}\s*(?:-|–|—)\s*\d{1,2}\s*[а-яё]+|\d{1,2}\s*[а-яё]+)',
    caseSensitive: false,
    unicode: true,
  );
  static final RegExp _workTimeIntervalRegex = RegExp(
    r'(\d{1,2})\s*:\s*(\d{2})\s*(?:-|–|—|до)\s*(\d{1,2})\s*:\s*(\d{2})',
    caseSensitive: false,
    unicode: true,
  );

  YandexMapController? _mapController;
  late int _deliveryMethod;
  String _query = '';
  Map<String, dynamic>? _selectedPoint;
  String? _focusedPointId;
  Duration? _serverUtcDrift;
  bool _isCheckingLocationPermission = true;
  bool _canShowMap = !Platform.isAndroid;
  PermissionStatus? _locationPermissionStatus;
  ServiceStatus? _locationServiceStatus;
  bool _didRequestLocationPermission = false;
  bool _isResolvingUserLocation = false;
  bool _isPrewarmingUserLocation = false;
  bool _didPrewarmUserLocation = false;
  bool _didInitialLocationAttempt = false;
  bool _didCenterToUser = false;
  bool _didInitialMapCameraSetup = false;
  bool _isLoadingPoints = true;
  bool _isMapPausedBySheet = false;
  final ValueNotifier<bool> _isMapPausedBySheetNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> _isSheetTopFlatNotifier = ValueNotifier<bool>(
    false,
  );
  bool _isUserLayerVisible = false;
  String _pickupFilter = 'all'; // all | today | preorder
  Point? _userLocationPoint;
  Uint8List? _userPinBytes;
  Uint8List? _shopSinglePinBytes;
  Uint8List? _shopManyBaseBytes;
  final Map<int, Uint8List> _shopMarkerBytesByCount = {};
  int _mapObjectsBuildSeq = 0;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _points = [];
  List<MapObject> _pickupMapObjects = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deliveryMethod = widget.initialDeliveryMethod;
    _selectedPoint = widget.selectedPoint;
    _rebuildMapObjects();
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) _expandSheetToTop();
    });
    _loadPickupPoints();
    _ensureMapLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheetController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _isMapPausedBySheetNotifier.dispose();
    _isSheetTopFlatNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        !_hasLocationPermission) {
      unawaited(_ensureMapLocationPermission());
    }
  }

  Future<Map<String, dynamic>?> _invokeIosLocationPermissionMethod(
    String method,
  ) async {
    if (!Platform.isIOS) return null;
    try {
      final response = await _iosLocationPermissionChannel
          .invokeMethod<dynamic>(method);
      if (response is Map) {
        return response.map((key, value) => MapEntry(key.toString(), value));
      }
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    return null;
  }

  PermissionStatus _permissionStatusFromIosNative(String? status) {
    switch (status) {
      case 'authorizedAlways':
      case 'authorizedWhenInUse':
        return PermissionStatus.granted;
      case 'restricted':
        return PermissionStatus.restricted;
      case 'denied':
        // Keep denied for iOS to avoid forcing Settings too early.
        return PermissionStatus.denied;
      case 'notDetermined':
      default:
        return PermissionStatus.denied;
    }
  }

  ServiceStatus _serviceStatusFromIosNative(dynamic servicesEnabledRaw) {
    return servicesEnabledRaw == false
        ? ServiceStatus.disabled
        : ServiceStatus.enabled;
  }

  Future<void> _ensureMapLocationPermission({
    bool triggeredByUser = false,
  }) async {
    final permission = Platform.isIOS
        ? Permission.locationWhenInUse
        : Permission.location;

    final hadRequestedBeforeTap = _didRequestLocationPermission;
    ServiceStatus? serviceStatus;
    PermissionStatus status = PermissionStatus.denied;

    // On iOS, always use permission_handler for the actual request.
    // This ensures requestWhenInUseAuthorization() is called and the system
    // dialog appears, which is required for the Location option to show
    // in Settings > [App].
    if (Platform.isIOS) {
      final nativeStatus = await _invokeIosLocationPermissionMethod('status');
      if (nativeStatus != null) {
        status = _permissionStatusFromIosNative(
          nativeStatus['status']?.toString(),
        );
        serviceStatus = _serviceStatusFromIosNative(
          nativeStatus['servicesEnabled'],
        );
      }
    }

    // Use permission_handler for status when native unavailable, and always
    // for the request on iOS (more reliable than custom bridge).
    if (!Platform.isIOS || serviceStatus == null) {
      try {
        serviceStatus = await permission.serviceStatus;
      } catch (_) {}
      status = await permission.status;
    }

    // Request when not granted. On map open we request if notDetermined so
    // the iOS prompt appears and the Location setting becomes available.
    final shouldRequestPermission =
        !status.isGranted &&
        (triggeredByUser ||
            (!Platform.isIOS || !_didRequestLocationPermission));
    if (shouldRequestPermission) {
      _didRequestLocationPermission = true;
      try {
        status = await permission.request();
      } catch (_) {}
      try {
        serviceStatus = await permission.serviceStatus;
      } catch (_) {}
    }

    var granted = status.isGranted;

    if (!granted && triggeredByUser) {
      // If user already denied iOS prompt, send them to system settings.
      final shouldOpenSettings =
          serviceStatus == ServiceStatus.disabled ||
          status.isPermanentlyDenied ||
          status.isRestricted ||
          (Platform.isIOS && status.isDenied && hadRequestedBeforeTap);
      if (shouldOpenSettings) {
        final opened = await _openLocationSettings();
        if (opened) {
          await Future.delayed(const Duration(milliseconds: 250));
          status = await permission.status;
          try {
            serviceStatus = await permission.serviceStatus;
          } catch (_) {}
          granted = status.isGranted;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _locationPermissionStatus = status;
      _locationServiceStatus = serviceStatus;
      // On iOS keep map visible even without permission; permission affects
      // only user-location centering and sorting by nearest point.
      _canShowMap = Platform.isIOS ? true : granted;
      _isCheckingLocationPermission = false;
      if (!granted) {
        _didCenterToUser = false;
      }
    });
    if (granted) {
      unawaited(_enableUserLocationLayerAndCenter());
    }
  }

  bool get _hasLocationPermission =>
      _locationPermissionStatus?.isGranted == true;

  bool get _isLocationServiceDisabled =>
      _locationServiceStatus == ServiceStatus.disabled;

  bool get _needsLocationSettingsOpen {
    if (_isLocationServiceDisabled) return true;
    final status = _locationPermissionStatus;
    if (status == null) return false;
    if (status.isPermanentlyDenied || status.isRestricted) return true;
    return Platform.isIOS && status.isDenied && _didRequestLocationPermission;
  }

  String get _locationPermissionHintText {
    if (_isLocationServiceDisabled) {
      return "Службы геолокации iPhone выключены. Включите их в настройках: "
          "Конфиденциальность и безопасность -> Службы геолокации.";
    }
    if (_needsLocationSettingsOpen) {
      return "Геолокация выключена. Разрешите доступ в настройках iPhone.";
    }
    return "Разрешите геолокацию, чтобы карта определила ближайший пункт.";
  }

  String get _locationActionButtonText {
    if (_isLocationServiceDisabled) {
      return "Открыть геолокацию iPhone";
    }
    return _needsLocationSettingsOpen
        ? "Открыть настройки"
        : "Разрешить геолокацию";
  }

  Future<bool> _openLocationSettings() async {
    if (Platform.isIOS) {
      const iosLocationSettingsUris = <String>[
        'App-Prefs:root=Privacy&path=LOCATION',
        'App-prefs:root=Privacy&path=LOCATION',
        'App-Prefs:Privacy&path=LOCATION',
        'App-prefs:Privacy&path=LOCATION',
        'prefs:root=Privacy&path=LOCATION',
      ];
      for (final value in iosLocationSettingsUris) {
        final uri = Uri.parse(value);
        if (await canLaunchUrl(uri)) {
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (opened) return true;
        }
      }
    }
    return openAppSettings();
  }

  Future<void> _setUserLayerVisibility(bool visible) async {
    final controller = _mapController;
    if (controller == null || _isUserLayerVisible == visible) return;
    try {
      await controller.toggleUserLayer(
        visible: visible,
        headingEnabled: false,
        autoZoomEnabled: false,
      );
      _isUserLayerVisible = visible;
    } catch (_) {}
  }

  bool _computeMapPauseBySheetExtent(double extent) {
    const activeMinExtent = _sheetMinChildSize;
    const pauseExtent = activeMinExtent + 0.015;
    const resumeExtent = activeMinExtent + 0.005;
    var shouldPause = _isMapPausedBySheet;
    if (extent >= pauseExtent) {
      shouldPause = true;
    } else if (extent <= resumeExtent) {
      shouldPause = false;
    }
    return shouldPause;
  }

  bool get _isFocusedPointMode => _focusedPointId?.isNotEmpty == true;

  Point _toPoint(Map<String, dynamic>? point) {
    final lat = (point?['lat'] as num?)?.toDouble() ?? 55.751244;
    final lng = (point?['lng'] as num?)?.toDouble() ?? 37.618423;
    return Point(latitude: lat, longitude: lng);
  }

  Point get _mapCenter => _selectedPoint != null
      ? _toPoint(_selectedPoint!)
      : (_points.isNotEmpty ? _toPoint(_points.first) : _defaultMapCenter);

  void _selectPoint(Map<String, dynamic> point) {
    setState(() {
      _selectedPoint = {
        ...point,
        'stock_id': point['stock_id']?.toString() ?? point['id']?.toString(),
      };
    });
    _rebuildMapObjects();
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _toPoint(point), zoom: _focusStoreZoom),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.8,
      ),
    );
  }

  Future<void> _rebuildMapObjects() async {
    final buildSeq = ++_mapObjectsBuildSeq;
    final pointsSnapshot = List<Map<String, dynamic>>.from(_points);
    final userPoint = _userLocationPoint;
    final markerBytes = await _getShopMarkerBytes(1);

    if (userPoint != null) {
      _userPinBytes ??= await _buildUserPinBytes();
    }

    if (!mounted || buildSeq != _mapObjectsBuildSeq) return;

    final placemarks = <PlacemarkMapObject>[];
    for (final point in pointsSnapshot) {
      final pointId = point['id']?.toString();
      final markerSuffix = pointId ?? '${point['lat']}_${point['lng']}';
      final markerId = 'pickup_$markerSuffix';
      placemarks.add(
        PlacemarkMapObject(
          mapId: MapObjectId(markerId),
          point: _toPoint(point),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(markerBytes),
              anchor: const Offset(0.5, 0.5),
              scale: 0.88,
            ),
          ),
          opacity: _mapPlacemarkOpacity,
          onTap: (_, __) => _showPointDetails(point),
          consumeTapEvents: true,
        ),
      );
    }

    final objects = <MapObject>[];
    if (placemarks.isNotEmpty) {
      objects.add(
        ClusterizedPlacemarkCollection(
          mapId: const MapObjectId('pickup_clusters'),
          placemarks: placemarks,
          radius: 62,
          minZoom: 15,
          zIndex: 200,
          onClusterAdded: _onShopClusterAdded,
          onClusterTap: _onShopClusterTap,
        ),
      );
    }

    if (userPoint != null && _userPinBytes != null) {
      objects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('user_static_marker'),
          point: userPoint,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(_userPinBytes!),
              anchor: const Offset(0.5, 0.5),
              scale: 0.88,
            ),
          ),
          opacity: _mapPlacemarkOpacity,
          zIndex: 1000,
        ),
      );
    }

    if (!mounted || buildSeq != _mapObjectsBuildSeq) return;
    setState(() {
      _pickupMapObjects = objects;
    });
  }

  Future<Cluster?> _onShopClusterAdded(
    ClusterizedPlacemarkCollection _,
    Cluster cluster,
  ) async {
    final total = math.max(1, cluster.size);
    final markerBytes = await _getShopMarkerBytes(total);
    return cluster.copyWith(
      appearance: cluster.appearance.copyWith(
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromBytes(markerBytes),
            anchor: const Offset(0.5, 0.5),
            scale: 0.82,
          ),
        ),
        consumeTapEvents: true,
        opacity: _mapPlacemarkOpacity,
        zIndex: 500,
      ),
    );
  }

  void _onShopClusterTap(ClusterizedPlacemarkCollection _, Cluster cluster) {
    () async {
      final controller = _mapController;
      if (controller == null) return;
      final current = await controller.getCameraPosition();
      final nextZoom = math.min(
        math.max(current.zoom + 2.6, _focusStoreZoom - 0.4),
        19.0,
      );
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: cluster.appearance.point, zoom: nextZoom),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.35,
        ),
      );
    }();
  }

  void _showPointDetails(Map<String, dynamic> point) {
    final pointId = point['id']?.toString();
    if (pointId == null || pointId.isEmpty) return;
    setState(() => _focusedPointId = pointId);
    _isMapPausedBySheet = false;
    _isMapPausedBySheetNotifier.value = false;
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _toPoint(point), zoom: _focusStoreZoom),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.8,
      ),
    );
  }

  void _submitSelectedPoint(Map<String, dynamic> point) {
    _selectPoint(point);
    Navigator.pop(context, {
      ...point,
      'stock_id': point['stock_id']?.toString() ?? point['id']?.toString(),
    });
  }

  void _clearFocusedPointMode() {
    if (_focusedPointId == null) return;
    setState(() => _focusedPointId = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_expandSheetToTop());
    });
  }

  Future<void> _openNavigationAppChooser(Map<String, dynamic> point) async {
    final lat = _toDouble(point['lat']);
    final lng = _toDouble(point['lng']);
    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Не удалось определить координаты пункта"),
        ),
      );
      return;
    }

    final encodedLat = lat.toStringAsFixed(6);
    final encodedLng = lng.toStringAsFixed(6);

    final appleMapsUri = Uri.parse(
      'http://maps.apple.com/?daddr=$encodedLat,$encodedLng&dirflg=d',
    );
    final googleMapsAppUri = Uri.parse(
      'comgooglemaps://?daddr=$encodedLat,$encodedLng&directionsmode=driving',
    );
    final yandexMapsAppUri = Uri.parse(
      'yandexmaps://maps.yandex.ru/?rtext=~$encodedLat,$encodedLng&rtt=auto',
    );
    final googleMapsWebUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$encodedLat,$encodedLng&travelmode=driving',
    );
    final yandexMapsWebUri = Uri.parse(
      'https://yandex.ru/maps/?rtext=~$encodedLat,$encodedLng&rtt=auto',
    );

    final options = <Map<String, dynamic>>[];

    if (Platform.isIOS && await canLaunchUrl(appleMapsUri)) {
      options.add({
        'title': 'Apple Maps',
        'subtitle': 'Открыть маршрут в Apple Maps',
        'uri': appleMapsUri,
      });
    }
    if (await canLaunchUrl(googleMapsAppUri)) {
      options.add({
        'title': 'Google Maps',
        'subtitle': 'Открыть маршрут в Google Maps',
        'uri': googleMapsAppUri,
      });
    }
    if (await canLaunchUrl(yandexMapsAppUri)) {
      options.add({
        'title': 'Яндекс Карты',
        'subtitle': 'Открыть маршрут в Яндекс Картах',
        'uri': yandexMapsAppUri,
      });
    }
    if (await canLaunchUrl(googleMapsWebUri)) {
      options.add({
        'title': 'Google Maps (web)',
        'subtitle': 'Открыть маршрут в браузере',
        'uri': googleMapsWebUri,
      });
    }
    if (await canLaunchUrl(yandexMapsWebUri)) {
      options.add({
        'title': 'Яндекс Карты (web)',
        'subtitle': 'Открыть маршрут в браузере',
        'uri': yandexMapsWebUri,
      });
    }

    if (!mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Не найдено приложение для построения маршрута"),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      "Построить маршрут",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ...options.map((option) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const Icon(
                      Icons.navigation_outlined,
                      color: Colors.black87,
                    ),
                    title: Text(
                      option['title'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      option['subtitle'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final uri = option['uri'] as Uri;
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _toRadians(double value) => value * math.pi / 180.0;

  double _distanceKm(Point a, Point b) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final hav =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
    return earthRadiusKm * c;
  }

  void _sortPointsByPriority(List<Map<String, dynamic>> points) {
    final user = _userLocationPoint;
    points.sort((a, b) {
      final aAvailable = a['is_available'] == true ? 0 : 1;
      final bAvailable = b['is_available'] == true ? 0 : 1;
      if (aAvailable != bAvailable) return aAvailable - bAvailable;

      if (user != null) {
        final da = _distanceKm(user, _toPoint(a));
        final db = _distanceKm(user, _toPoint(b));
        final distanceCompare = da.compareTo(db);
        if (distanceCompare != 0) return distanceCompare;
      }

      final aName = a['name']?.toString() ?? '';
      final bName = b['name']?.toString() ?? '';
      return aName.compareTo(bName);
    });
  }

  void _resortPoints() {
    if (!_sheetController.isAttached) return;
    if (_sheetController.size > _sheetMinChildSize + 0.02) return;
    final sorted = List<Map<String, dynamic>>.from(_points);
    _sortPointsByPriority(sorted);
    _points = sorted;
  }

  Future<void> _expandSheetToTop() async {
    if (!_sheetController.isAttached) return;
    if (_sheetController.size >= (_sheetMaxChildSize - 0.002)) return;
    await _sheetController.animateTo(
      _sheetMaxChildSize,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
  }

  List<Map<String, dynamic>> _resolveVisiblePoints(
    List<Map<String, dynamic>> filteredPoints,
  ) {
    final focusedId = _focusedPointId;
    if (focusedId == null || focusedId.isEmpty) return filteredPoints;
    final selectedFromFiltered = filteredPoints
        .where((point) => point['id']?.toString() == focusedId)
        .toList();
    if (selectedFromFiltered.isNotEmpty) return selectedFromFiltered;
    final selectedFromAll = _points
        .where((point) => point['id']?.toString() == focusedId)
        .toList();
    if (selectedFromAll.isNotEmpty) return selectedFromAll;
    return filteredPoints;
  }

  Future<Uint8List?> _loadMarkerAssetBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {}
    return null;
  }

  Future<Uint8List> _buildUserPinBytes() async {
    if (_userPinBytes != null) return _userPinBytes!;
    final assetBytes = await _loadMarkerAssetBytes(_userPinAssetPath);
    if (assetBytes != null) {
      _userPinBytes = assetBytes;
      return assetBytes;
    }
    return _buildFallbackUserPinBytes();
  }

  Future<Uint8List> _buildFallbackUserPinBytes() async {
    const size = 74;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.22);
    final outerPaint = Paint()..color = Colors.white;
    final innerPaint = Paint()..color = const Color(0xFF1F78FF);

    canvas.drawCircle(Offset(center.dx, center.dy + 1.3), 19.8, shadowPaint);
    canvas.drawCircle(center, 19.0, outerPaint);
    canvas.drawCircle(center, 14.2, innerPaint);

    final image = await recorder.endRecording().toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    _userPinBytes = bytes;
    return bytes;
  }

  Future<Uint8List> _getShopSingleMarkerBytes() async {
    if (_shopSinglePinBytes != null) return _shopSinglePinBytes!;
    final assetBytes = await _loadMarkerAssetBytes(_shopPinAssetPath);
    if (assetBytes != null) {
      _shopSinglePinBytes = assetBytes;
      return assetBytes;
    }
    _shopSinglePinBytes = await _buildFallbackShopMarkerBytes();
    return _shopSinglePinBytes!;
  }

  Future<Uint8List> _getShopMarkerBytes(int count) async {
    final normalized = math.max(1, count);
    if (normalized <= 1) return _getShopSingleMarkerBytes();

    final cacheKey = normalized > 999 ? 999 : normalized;
    final cached = _shopMarkerBytesByCount[cacheKey];
    if (cached != null) return cached;

    final bytes = await _buildManyShopMarkerBytes(cacheKey);
    _shopMarkerBytesByCount[cacheKey] = bytes;
    return bytes;
  }

  Future<Uint8List> _buildManyShopMarkerBytes(int count) async {
    _shopManyBaseBytes ??= await _loadMarkerAssetBytes(_shopManyPinAssetPath);
    final base = _shopManyBaseBytes;
    if (base == null) {
      return _buildFallbackShopMarkerBytes(count: count);
    }

    final label = count > 999 ? '999+' : count.toString();
    final baseImage = await _decodeUiImage(base);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(baseImage, Offset.zero, Paint());

    final w = baseImage.width.toDouble();
    final h = baseImage.height.toDouble();
    final fontSize = w * 0.28 + 2;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: const Color(0xFF111111),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    )..layout(maxWidth: w * 0.8);
    textPainter.paint(
      canvas,
      Offset(
        (w - textPainter.width) / 2,
        (h - textPainter.height) / 2 - (h * 0.06) - 4,
      ),
    );

    final image = await recorder.endRecording().toImage(
      baseImage.width,
      baseImage.height,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<ui.Image> _decodeUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<Uint8List> _buildFallbackShopMarkerBytes({int count = 1}) async {
    final safeCount = math.max(1, count);
    const size = 116;
    const radius = 38.5;
    const strokeWidth = 7.2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    final fillPaint = Paint()..color = const Color(0xFF08090B);
    final strokePaint = Paint()
      ..color = const Color(0xFFBA7240)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    if (safeCount > 1) {
      final label = safeCount > 999 ? '999+' : safeCount.toString();
      const fontSize = 30.0;
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Color(0xFF111111),
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx - (textPainter.width / 2),
          center.dy - (textPainter.height / 2) - 8,
        ),
      );
    }

    final image = await recorder.endRecording().toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Map<String, dynamic>? _normalizePickupPoint(dynamic raw) {
    if (raw is! Map) return null;
    final point = PickupPoint.fromJson(Map<String, dynamic>.from(raw));
    if (point.id.isEmpty || !point.hasValidCoordinates) return null;
    return point.toMap();
  }

  Duration? _parseServerUtcDrift(Response<dynamic> response) {
    final header = response.headers.value('date');
    if (header == null || header.trim().isEmpty) return null;
    try {
      final serverUtc = HttpDate.parse(header).toUtc();
      final deviceUtc = DateTime.now().toUtc();
      final drift = serverUtc.difference(deviceUtc);
      if (drift.inHours.abs() > 48) return null;
      return drift;
    } catch (_) {
      return null;
    }
  }

  DateTime _effectiveUtcNow() {
    final drift = _serverUtcDrift;
    if (drift == null) return DateTime.now().toUtc();
    return DateTime.now().toUtc().add(drift);
  }

  int? _pointUtcOffsetMinutes(Map<String, dynamic>? point) {
    final raw = point?['utc_offset'] ?? point?['utc_offset_minutes'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  String _formatDurationRu(Duration duration) {
    var totalMinutes = (duration.inSeconds / 60).ceil();
    if (totalMinutes <= 0) totalMinutes = 1;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutesм.';
    if (minutes == 0) return '$hoursч.';
    return '$hoursч. $minutesм.';
  }

  String _formatWorkScheduleBase(String schedule) {
    final text = schedule.trim();
    if (text.isEmpty) return '';
    final interval = _workTimeIntervalRegex.firstMatch(text);
    if (interval == null) return text;
    final startHour = (int.tryParse(interval.group(1) ?? '') ?? 0)
        .toString()
        .padLeft(2, '0');
    final startMinute = (int.tryParse(interval.group(2) ?? '') ?? 0)
        .toString()
        .padLeft(2, '0');
    final endHour = (int.tryParse(interval.group(3) ?? '') ?? 0)
        .toString()
        .padLeft(2, '0');
    final endMinute = (int.tryParse(interval.group(4) ?? '') ?? 0)
        .toString()
        .padLeft(2, '0');
    return 'Ежедневно $startHour:$startMinute-$endHour:$endMinute';
  }

  String getWorkStatus(String schedule, {Map<String, dynamic>? point}) {
    final text = schedule.trim();
    if (text.isEmpty) return '';

    final interval = _workTimeIntervalRegex.firstMatch(text);
    if (interval == null) return '';

    final openHour = int.tryParse(interval.group(1) ?? '');
    final openMinute = int.tryParse(interval.group(2) ?? '');
    final closeHour = int.tryParse(interval.group(3) ?? '');
    final closeMinute = int.tryParse(interval.group(4) ?? '');

    final hasInvalidTime =
        openHour == null ||
        openMinute == null ||
        closeHour == null ||
        closeMinute == null ||
        openHour < 0 ||
        openHour > 23 ||
        closeHour < 0 ||
        closeHour > 23 ||
        openMinute < 0 ||
        openMinute > 59 ||
        closeMinute < 0 ||
        closeMinute > 59;
    if (hasInvalidTime) return '';

    final utcOffsetMinutes = _pointUtcOffsetMinutes(point);
    if (utcOffsetMinutes == null) return '';
    final pointNow = _effectiveUtcNow().add(
      Duration(minutes: utcOffsetMinutes),
    );

    final intervals = <({DateTime open, DateTime close})>[];
    for (var dayShift = -1; dayShift <= 2; dayShift++) {
      final day = pointNow.add(Duration(days: dayShift));
      var open = DateTime.utc(
        day.year,
        day.month,
        day.day,
        openHour,
        openMinute,
      );
      var close = DateTime.utc(
        day.year,
        day.month,
        day.day,
        closeHour,
        closeMinute,
      );
      if (!close.isAfter(open)) {
        close = close.add(const Duration(days: 1));
      }
      intervals.add((open: open, close: close));
    }

    for (final interval in intervals) {
      if (!pointNow.isBefore(interval.open) &&
          pointNow.isBefore(interval.close)) {
        final left = interval.close.difference(pointNow);
        return 'до закрытия ${_formatDurationRu(left)}';
      }
    }

    DateTime? nextOpen;
    for (final interval in intervals) {
      if (interval.open.isAfter(pointNow)) {
        nextOpen = nextOpen == null || interval.open.isBefore(nextOpen)
            ? interval.open
            : nextOpen;
      }
    }
    if (nextOpen == null) {
      return 'Закрыто';
    }
    final tillOpen = nextOpen.difference(pointNow);
    return 'до открытия ${_formatDurationRu(tillOpen)}';
  }

  Future<void> _loadPickupPoints() async {
    setState(() => _isLoadingPoints = true);
    try {
      final dio = _getAuthDio();
      final productId = widget.productId?.trim();
      final path = (productId != null && productId.isNotEmpty)
          ? '$_pointsUrl?product_id=${Uri.encodeQueryComponent(productId)}'
          : _pointsUrl;
      final response = await dio.get(path);
      final drift = _parseServerUtcDrift(response);
      if (drift != null) {
        _serverUtcDrift = drift;
      }
      final data = _parseAuthResponse(response.data);
      final status = data?['status']?.toString().toLowerCase();
      final rawPoints = data?['points'];
      if (status == 'ok' && rawPoints is List) {
        final parsed = rawPoints
            .map(_normalizePickupPoint)
            .whereType<Map<String, dynamic>>()
            .toList();
        _sortPointsByPriority(parsed);
        if (!mounted) return;
        setState(() {
          _points = parsed;
          final selectedId = _selectedPoint?['id']?.toString();
          if (selectedId != null && selectedId.isNotEmpty) {
            final same = parsed
                .where((p) => p['id']?.toString() == selectedId)
                .toList();
            _selectedPoint = same.isNotEmpty ? same.first : null;
          }
        });
        _rebuildMapObjects();
      }
    } catch (_) {
      if (mounted) setState(() => _points = []);
    } finally {
      if (mounted) setState(() => _isLoadingPoints = false);
    }
  }

  Future<void> _enableUserLocationLayerAndCenter() async {
    final controller = _mapController;
    if (!_hasLocationPermission ||
        controller == null ||
        _isResolvingUserLocation ||
        _didCenterToUser) {
      return;
    }
    _didInitialLocationAttempt = true;
    _isResolvingUserLocation = true;
    try {
      await controller.toggleUserLayer(
        visible: true,
        headingEnabled: false,
        autoZoomEnabled: false,
      );
      _isUserLayerVisible = true;

      // Wait a bit for native layer to get first GPS fix.
      var movedToUser = false;
      for (var i = 0; i < 8; i++) {
        final camera = await controller.getUserCameraPosition();
        if (camera != null) {
          _userPinBytes ??= await _buildUserPinBytes();
          if (mounted) {
            setState(() {
              _userLocationPoint = camera.target;
              _resortPoints();
            });
            _rebuildMapObjects();
          }
          // Wait briefly so tiles/layer are ready before the first animated move.
          await Future.delayed(const Duration(milliseconds: 280));
          await controller.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: camera.target, zoom: _focusUserZoom),
            ),
            animation: const MapAnimation(
              type: MapAnimationType.smooth,
              duration: 1.1,
            ),
          );
          await _setUserLayerVisibility(false);
          movedToUser = true;
          _didCenterToUser = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 450));
      }
      if (!movedToUser && _selectedPoint == null) {
        await controller.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _mapCenter, zoom: _initialMapZoom),
          ),
          animation: const MapAnimation(
            type: MapAnimationType.smooth,
            duration: 0.9,
          ),
        );
      }
      if (_isUserLayerVisible) {
        await _setUserLayerVisibility(false);
      }
      _didPrewarmUserLocation = true;
    } catch (_) {
      // Keep pickup map usable even if user location is temporarily unavailable.
    } finally {
      _isResolvingUserLocation = false;
    }
  }

  Future<void> _prewarmUserLocationLayer() async {
    final controller = _mapController;
    if (!_hasLocationPermission ||
        controller == null ||
        _isResolvingUserLocation ||
        _isPrewarmingUserLocation ||
        _didPrewarmUserLocation) {
      return;
    }
    _isPrewarmingUserLocation = true;
    try {
      await controller.toggleUserLayer(
        visible: true,
        headingEnabled: false,
        autoZoomEnabled: false,
      );
      _isUserLayerVisible = true;
      for (var i = 0; i < 5; i++) {
        final camera = await controller.getUserCameraPosition();
        if (camera != null) {
          _userPinBytes ??= await _buildUserPinBytes();
          if (mounted) {
            setState(() {
              _userLocationPoint = camera.target;
              _resortPoints();
            });
            _rebuildMapObjects();
          }
          break;
        }
        await Future.delayed(const Duration(milliseconds: 280));
      }
      if (_isUserLayerVisible) {
        await _setUserLayerVisibility(false);
      }
      _didPrewarmUserLocation = true;
    } catch (_) {
      if (_isUserLayerVisible) {
        await _setUserLayerVisibility(false);
      }
    } finally {
      _isPrewarmingUserLocation = false;
    }
  }

  List<Map<String, dynamic>> get _filteredPoints {
    final q = _query.trim().toLowerCase();
    Iterable<Map<String, dynamic>> result = _points;

    if (_pickupFilter == 'today') {
      result = result.where((point) => point['is_available'] == true);
    } else if (_pickupFilter == 'preorder') {
      result = result.where((point) => point['is_available'] != true);
    }

    if (q.isEmpty) return result.toList();
    return result.where((point) {
      final name = point['name']?.toString().toLowerCase() ?? '';
      final address = point['address']?.toString().toLowerCase() ?? '';
      return name.contains(q) || address.contains(q);
    }).toList();
  }

  TextSpan _buildEtaSpan(
    String eta, {
    required TextStyle baseStyle,
    required TextStyle accentStyle,
  }) {
    final text = eta.trim();
    if (text.isEmpty) return TextSpan(text: '', style: baseStyle);

    final matches = _etaHighlightRegex.allMatches(text).toList();
    if (matches.isEmpty) return TextSpan(text: text, style: baseStyle);

    final children = <TextSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        children.add(
          TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
        );
      }
      children.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: accentStyle,
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return TextSpan(children: children);
  }

  Widget _buildPickupPointCard(Map<String, dynamic> point, bool isSelected) {
    final worktime = point['worktime']?.toString().trim() ?? '';
    final workScheduleBase = _formatWorkScheduleBase(worktime);
    final workStatus = getWorkStatus(worktime, point: point);
    final hasWorkInfo = workScheduleBase.isNotEmpty;
    final eta = point['eta']?.toString().trim() ?? '';
    final isAvailable = point['is_available'] == true;
    final showFocusedClose =
        _isFocusedPointMode &&
        point['id']?.toString().isNotEmpty == true &&
        point['id']?.toString() == _focusedPointId;
    const availabilityBaseStyle = TextStyle(
      fontSize: 15,
      color: _pickupWorktimeColor,
      fontWeight: FontWeight.w500,
    );
    const availabilityAccentStyle = TextStyle(
      fontSize: 15,
      color: _pickupAccentColor,
      fontWeight: FontWeight.w700,
    );
    final availabilitySpan = isAvailable
        ? const TextSpan(
            children: [
              TextSpan(text: 'В наличии ', style: availabilityBaseStyle),
              TextSpan(text: 'сегодня', style: availabilityAccentStyle),
            ],
          )
        : (eta.isNotEmpty
              ? _buildEtaSpan(
                  eta,
                  baseStyle: availabilityBaseStyle,
                  accentStyle: availabilityAccentStyle,
                )
              : const TextSpan(
                  text: 'Под заказ',
                  style: availabilityBaseStyle,
                ));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPointDetails(point),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: _pickupCardRadius,
          border: Border.all(color: _pickupBorderColor, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(-3, 0),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.location_on_outlined, size: 19),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(-3, 0),
                        child: Text(
                          point['name']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Transform.translate(
                        offset: const Offset(-25, 0),
                        child: Text(
                          point['address']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: _pickupAddressColor,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (hasWorkInfo && !showFocusedClose) ...[
                        const SizedBox(height: 5),
                        Transform.translate(
                          offset: const Offset(-25, 0),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: workScheduleBase,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _pickupWorktimeColor,
                                    fontWeight: FontWeight.w400,
                                    height: 1.1,
                                  ),
                                ),
                                if (workStatus.isNotEmpty)
                                  TextSpan(
                                    text: ' - $workStatus',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _pickupWorktimeColor,
                                      fontWeight: FontWeight.w400,
                                      height: 1.1,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showFocusedClose) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _clearFocusedPointMode,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E1E6)),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (hasWorkInfo && showFocusedClose) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 25),
                child: Transform.translate(
                  offset: const Offset(-25, 0),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: workScheduleBase,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _pickupWorktimeColor,
                            fontWeight: FontWeight.w400,
                            height: 1.1,
                          ),
                        ),
                        if (workStatus.isNotEmpty)
                          TextSpan(
                            text: ' - $workStatus',
                            style: const TextStyle(
                              fontSize: 13,
                              color: _pickupWorktimeColor,
                              fontWeight: FontWeight.w400,
                              height: 1.1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: RichText(text: availabilitySpan)),
                const SizedBox(width: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => _openNavigationAppChooser(point),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F8),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: const Color(0xFFE0E1E6)),
                    ),
                    child: const Icon(
                      Icons.navigation_outlined,
                      size: 18,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 34,
                  child: OutlinedButton(
                    onPressed: () => _submitSelectedPoint(point),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isSelected
                            ? Colors.black
                            : const Color(0xFFD4D6DC),
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      foregroundColor: Colors.black,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isSelected ? 'Выбрано' : 'Выбрать',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = _filteredPoints;
    final visiblePoints = _resolveVisiblePoints(points);
    final isFocusedPointMode = _isFocusedPointMode;
    final selectedId = _selectedPoint?['id']?.toString();
    final focusedPoint = isFocusedPointMode && visiblePoints.isNotEmpty
        ? visiblePoints.first
        : null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text(
                "Выбрать пункт самовывоза",
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 8, 5, 10),
            child: SizedBox(
              height: 34,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isPickup = _deliveryMethod == 1;
                  final indicatorWidth = (constraints.maxWidth - 4) / 2;
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          left: isPickup ? 2 : 2 + indicatorWidth,
                          top: 2,
                          bottom: 2,
                          width: indicatorWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () =>
                                    setState(() => _deliveryMethod = 1),
                                child: Center(
                                  child: Text(
                                    "Самовывоз",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isPickup
                                          ? Colors.black
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  if (widget.onSwitchToDelivery != null) {
                                    widget.onSwitchToDelivery!();
                                  } else {
                                    await Navigator.pushReplacement(
                                      context,
                                      _adaptivePageRoute(
                                        builder: (_) =>
                                            const DeliveryAddressPage(),
                                      ),
                                    );
                                  }
                                },
                                child: Center(
                                  child: Text(
                                    "Доставка",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: !isPickup
                                          ? Colors.black
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _isCheckingLocationPermission
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : (_canShowMap
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  YandexMap(
                                    tiltGesturesEnabled: false,
                                    rotateGesturesEnabled: false,
                                    zoomGesturesEnabled: true,
                                    scrollGesturesEnabled: true,
                                    mode2DEnabled: true,
                                    onMapCreated: (controller) async {
                                      _mapController = controller;
                                      if (_didInitialMapCameraSetup) return;
                                      _didInitialMapCameraSetup = true;
                                      if (_hasLocationPermission &&
                                          !_didInitialLocationAttempt) {
                                        await Future.delayed(
                                          const Duration(milliseconds: 220),
                                        );
                                        await _enableUserLocationLayerAndCenter();
                                        if (_didCenterToUser) {
                                          return;
                                        }
                                      }
                                      if (_selectedPoint != null) {
                                        await Future.delayed(
                                          const Duration(milliseconds: 180),
                                        );
                                        await controller.moveCamera(
                                          CameraUpdate.newCameraPosition(
                                            CameraPosition(
                                              target: _mapCenter,
                                              zoom: _initialMapZoom,
                                            ),
                                          ),
                                          animation: const MapAnimation(
                                            type: MapAnimationType.smooth,
                                            duration: 0.9,
                                          ),
                                        );
                                        if (_hasLocationPermission) {
                                          unawaited(() async {
                                            await Future.delayed(
                                              const Duration(milliseconds: 180),
                                            );
                                            await _prewarmUserLocationLayer();
                                          }());
                                        }
                                      } else {
                                        if (_userLocationPoint != null) {
                                          await controller.moveCamera(
                                            CameraUpdate.newCameraPosition(
                                              CameraPosition(
                                                target: _userLocationPoint!,
                                                zoom: _focusUserZoom,
                                              ),
                                            ),
                                            animation: const MapAnimation(
                                              type: MapAnimationType.smooth,
                                              duration: 0.7,
                                            ),
                                          );
                                        } else {
                                          await controller.moveCamera(
                                            CameraUpdate.newCameraPosition(
                                              CameraPosition(
                                                target: _mapCenter,
                                                zoom: _initialMapZoom,
                                              ),
                                            ),
                                            animation: const MapAnimation(
                                              type: MapAnimationType.smooth,
                                              duration: 0.7,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    mapObjects: _pickupMapObjects,
                                  ),
                                  ValueListenableBuilder<bool>(
                                    valueListenable:
                                        _isMapPausedBySheetNotifier,
                                    builder: (context, paused, _) {
                                      if (!paused) {
                                        return const SizedBox.shrink();
                                      }
                                      return const AbsorbPointer(
                                        absorbing: true,
                                        child: SizedBox.expand(),
                                      );
                                    },
                                  ),
                                  if (!_hasLocationPermission)
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      top: 12,
                                      child: Material(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        elevation: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            10,
                                            12,
                                            10,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _locationPermissionHintText,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                height: 34,
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      _ensureMapLocationPermission(
                                                        triggeredByUser: true,
                                                      ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.black,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            9,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _locationActionButtonText,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    14,
                                    14,
                                    14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "Для отображения карты дайте доступ к геолокации",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 38,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _ensureMapLocationPermission(
                                                triggeredByUser: true,
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            _locationActionButtonText,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                ),
                if (!isFocusedPointMode)
                  NotificationListener<DraggableScrollableNotification>(
                    onNotification: (notification) {
                      if (notification.depth != 0) return false;
                      final nextMapPause = _computeMapPauseBySheetExtent(
                        notification.extent,
                      );
                      if (nextMapPause != _isMapPausedBySheet) {
                        _isMapPausedBySheet = nextMapPause;
                        _isMapPausedBySheetNotifier.value = nextMapPause;
                      }
                      final shouldFlattenTop =
                          notification.extent >= _sheetTopFlatExtent;
                      if (shouldFlattenTop != _isSheetTopFlatNotifier.value) {
                        _isSheetTopFlatNotifier.value = shouldFlattenTop;
                      }
                      return false;
                    },
                    child: DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: _sheetInitialChildSize,
                      minChildSize: _sheetMinChildSize,
                      maxChildSize: _sheetMaxChildSize,
                      snap: true,
                      snapSizes: const [_sheetMinChildSize, _sheetMaxChildSize],
                      snapAnimationDuration: _sheetSnapDuration,
                      builder: (context, scrollController) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: _isSheetTopFlatNotifier,
                          builder: (context, isTopFlat, _) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 90),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: isTopFlat
                                    ? BorderRadius.zero
                                    : const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                boxShadow: isTopFlat
                                    ? const []
                                    : const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: Offset(0, -2),
                                        ),
                                      ],
                              ),
                              child: Stack(
                                children: [
                                  CustomScrollView(
                                    controller: scrollController,
                                    cacheExtent: 560,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics(),
                                        ),
                                    slivers: [
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                            bottom: 10,
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 34,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade400,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (!isFocusedPointMode)
                                        SliverPersistentHeader(
                                          pinned: true,
                                          delegate: _PinnedSheetHeaderDelegate(
                                            height: 46,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    5,
                                                    0,
                                                    5,
                                                    10,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: SizedBox(
                                                      height: 36,
                                                      child: TextField(
                                                        controller:
                                                            _searchController,
                                                        focusNode:
                                                            _searchFocusNode,
                                                        onTap:
                                                            _expandSheetToTop,
                                                        onChanged: (value) {
                                                          setState(
                                                            () =>
                                                                _query = value,
                                                          );
                                                          if (value
                                                              .trim()
                                                              .isNotEmpty) {
                                                            _expandSheetToTop();
                                                          }
                                                        },
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                        textAlignVertical:
                                                            TextAlignVertical
                                                                .center,
                                                        decoration: InputDecoration(
                                                          hintText: "Поиск",
                                                          hintStyle:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                          prefixIcon:
                                                              const Icon(
                                                                Icons.search,
                                                                size: 18,
                                                                color: Colors
                                                                    .black45,
                                                              ),
                                                          prefixIconConstraints:
                                                              const BoxConstraints(
                                                                minWidth: 34,
                                                                minHeight: 34,
                                                              ),
                                                          suffixIcon:
                                                              _query
                                                                  .trim()
                                                                  .isEmpty
                                                              ? null
                                                              : IconButton(
                                                                  onPressed: () {
                                                                    _searchController
                                                                        .clear();
                                                                    setState(
                                                                      () =>
                                                                          _query =
                                                                              '',
                                                                    );
                                                                  },
                                                                  icon: const Icon(
                                                                    Icons
                                                                        .cancel,
                                                                    size: 18,
                                                                    color: Colors
                                                                        .black38,
                                                                  ),
                                                                ),
                                                          filled: true,
                                                          fillColor:
                                                              const Color(
                                                                0xFFF2F2F6,
                                                              ),
                                                          contentPadding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 0,
                                                              ),
                                                          border: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  18,
                                                                ),
                                                            borderSide:
                                                                BorderSide.none,
                                                          ),
                                                          enabledBorder:
                                                              OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      18,
                                                                    ),
                                                                borderSide:
                                                                    BorderSide
                                                                        .none,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  TextButton(
                                                    onPressed: () {
                                                      _searchController.clear();
                                                      _searchFocusNode
                                                          .unfocus();
                                                      setState(
                                                        () => _query = '',
                                                      );
                                                    },
                                                    style: TextButton.styleFrom(
                                                      minimumSize: const Size(
                                                        0,
                                                        36,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 2,
                                                          ),
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                    child: const Text(
                                                      "Отмена",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Color(
                                                          0xFF606067,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (!isFocusedPointMode)
                                        SliverPersistentHeader(
                                          pinned: true,
                                          delegate: _PinnedSheetHeaderDelegate(
                                            height: 38,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    5,
                                                    0,
                                                    5,
                                                    10,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: SizedBox(
                                                      height: 28,
                                                      child: OutlinedButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            _pickupFilter =
                                                                _pickupFilter ==
                                                                    'today'
                                                                ? 'all'
                                                                : 'today';
                                                          });
                                                        },
                                                        style: OutlinedButton.styleFrom(
                                                          backgroundColor:
                                                              _pickupFilter ==
                                                                  'today'
                                                              ? Colors.black
                                                              : Colors.white,
                                                          foregroundColor:
                                                              _pickupFilter ==
                                                                  'today'
                                                              ? Colors.white
                                                              : Colors.black87,
                                                          side: BorderSide(
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                          ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                              ),
                                                          tapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                        ),
                                                        child: const Text(
                                                          "Забрать сегодня",
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: SizedBox(
                                                      height: 28,
                                                      child: OutlinedButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            _pickupFilter =
                                                                _pickupFilter ==
                                                                    'preorder'
                                                                ? 'all'
                                                                : 'preorder';
                                                          });
                                                        },
                                                        style: OutlinedButton.styleFrom(
                                                          backgroundColor:
                                                              _pickupFilter ==
                                                                  'preorder'
                                                              ? Colors.black
                                                              : Colors.white,
                                                          foregroundColor:
                                                              _pickupFilter ==
                                                                  'preorder'
                                                              ? Colors.white
                                                              : Colors.black87,
                                                          side: BorderSide(
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                          ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                              ),
                                                          tapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                        ),
                                                        child: const Text(
                                                          "Под заказ",
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (_isLoadingPoints &&
                                          visiblePoints.isEmpty)
                                        const SliverToBoxAdapter(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 36,
                                            ),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        )
                                      else if (visiblePoints.isEmpty)
                                        SliverToBoxAdapter(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 36,
                                            ),
                                            child: Center(
                                              child: Text(
                                                "Ничего не найдено",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        SliverPadding(
                                          padding: const EdgeInsets.fromLTRB(
                                            5,
                                            4,
                                            5,
                                            12,
                                          ),
                                          sliver: SliverList(
                                            delegate: SliverChildBuilderDelegate(
                                              (context, index) {
                                                final point =
                                                    visiblePoints[index];
                                                final id = point['id']
                                                    ?.toString();
                                                final isSelected =
                                                    id == selectedId;
                                                return Padding(
                                                  key: ValueKey<String>(
                                                    id ?? 'point_$index',
                                                  ),
                                                  padding: EdgeInsets.only(
                                                    bottom:
                                                        index ==
                                                            visiblePoints
                                                                    .length -
                                                                1
                                                        ? 0
                                                        : 10,
                                                  ),
                                                  child: _buildPickupPointCard(
                                                    point,
                                                    isSelected,
                                                  ),
                                                );
                                              },
                                              childCount: visiblePoints.length,
                                              addAutomaticKeepAlives: false,
                                              addRepaintBoundaries: true,
                                              addSemanticIndexes: false,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                if (focusedPoint != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      left: false,
                      right: false,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(5, 13, 5, 13),
                          child: _buildPickupPointCard(
                            focusedPoint,
                            focusedPoint['id']?.toString() == selectedId,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedSheetHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _PinnedSheetHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: Colors.white, child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedSheetHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool isNew;
  final void Function(Map<String, dynamic> product) onFavoriteTap;
  final void Function(Map<String, dynamic> product) onCompareTap;
  final VoidCallback onAddToCart;
  final ValueListenable<int>? cartListenable;
  final bool Function(String id)? isInCartResolver;
  final VoidCallback onShare;
  final void Function(Map<String, dynamic> product)? onOpenProduct;
  final ValueListenable<int>? Function(String id)? resolveFavoriteListenable;
  final ValueListenable<int>? Function(String id)? resolveCompareListenable;
  final ValueListenable<int>? Function(String id)? resolveGalleryListenable;
  final bool Function(String id)? isFavoriteResolver;
  final bool Function(String id)? isCompareResolver;
  final List<String> Function(Map<String, dynamic> product) resolveImages;
  final Future<List<String>> Function(String productId)? fetchImagesById;
  final Future<Map<String, dynamic>?> Function(String productId)?
  fetchProductById;
  final String Function(Map<String, dynamic> product) resolveArticle;
  final int Function(Map<String, dynamic> product) resolveStockCount;
  final List<dynamic> availableFeatures;
  final Map<String, String> featureCodeById;
  final Map<String, Map<String, String>> featureValueTextById;
  final List<dynamic> availableStocks;
  final Map<String, int>? Function(String id)? resolveStockMap;
  final Future<List<Map<String, dynamic>>> Function(String productId)?
  fetchReviewsById;
  final Future<Map<String, dynamic>?> Function(String contactId)?
  fetchCustomerById;
  final Future<bool> Function({
    required String productId,
    required String name,
    required String title,
    required String text,
    required int rate,
    required List<XFile> photos,
  })?
  submitReview;
  final Widget? bottomBar;
  final bool showStockSheetOnLoad;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.isNew,
    required this.onFavoriteTap,
    required this.onCompareTap,
    required this.onAddToCart,
    this.cartListenable,
    this.isInCartResolver,
    required this.onShare,
    this.onOpenProduct,
    required this.resolveImages,
    this.fetchImagesById,
    this.fetchProductById,
    required this.resolveArticle,
    required this.resolveStockCount,
    required this.availableFeatures,
    required this.featureCodeById,
    required this.featureValueTextById,
    required this.availableStocks,
    this.resolveStockMap,
    this.fetchReviewsById,
    this.fetchCustomerById,
    this.submitReview,
    this.bottomBar,
    this.resolveFavoriteListenable,
    this.resolveCompareListenable,
    this.resolveGalleryListenable,
    this.isFavoriteResolver,
    this.isCompareResolver,
    this.showStockSheetOnLoad = false,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final PageController _pageController = PageController();
  int _currentImage = 0;
  List<String> _images = [];
  List<String> _previewImages = [];
  bool _isUpsellLoading = false;
  List<Map<String, dynamic>> _upsellItems = [];
  static String? _groupsCacheRaw;
  static Future<String?>? _groupsCacheRawFuture;
  static final Map<String, List<Map<String, dynamic>>> _groupsByProductIdCache =
      {};
  static final Map<String, Map<String, dynamic>> _productInfoCache = {};
  static final Map<String, Future<Map<String, dynamic>?>> _productInfoInFlight =
      {};
  static final Map<String, List<Map<String, dynamic>>> _productReviewsCache =
      {};
  static final Map<String, Future<List<Map<String, dynamic>>>>
  _productReviewsInFlight = {};
  static final Map<String, Map<String, dynamic>> _customerInfoCache = {};
  static final Map<String, Future<Map<String, dynamic>?>>
  _customerInfoInFlight = {};
  static Map<String, dynamic>? _storesHierarchyCache;
  static Future<Map<String, dynamic>?>? _storesHierarchyInFlight;
  static const Duration _groupsCacheTtl = Duration(hours: 12);
  static Future<File>? _groupsCacheFileFuture;
  late Map<String, dynamic> _currentProduct;
  String _currentProductId = "";
  ValueListenable<int>? _favoriteListenable;
  ValueListenable<int>? _compareListenable;
  ValueListenable<int>? _galleryListenable;
  int _detailTabIndex = 0;
  bool _isProductInfoLoading = false;
  bool _isReviewsLoading = false;
  List<Map<String, dynamic>> _reviews = [];
  double _reviewsAverage = 0.0;
  int _reviewsCount = 0;
  Map<int, int> _reviewsByRating = {};
  int _reviewsRatedCount = 0;
  String _reviewsFilter = "all";
  bool _reviewsOnlyWithPhotos = false;
  bool _isDescriptionExpanded = false;
  static const double _descriptionFontSize = 14;
  static const int _descriptionMaxLines = 8;

  @override
  void initState() {
    super.initState();
    _currentProduct = Map<String, dynamic>.from(widget.product);
    _currentProductId = _currentProduct['id']?.toString() ?? "";
    _favoriteListenable = widget.resolveFavoriteListenable?.call(
      _currentProductId,
    );
    _compareListenable = widget.resolveCompareListenable?.call(
      _currentProductId,
    );
    _galleryListenable = widget.resolveGalleryListenable?.call(
      _currentProductId,
    );
    _previewImages = _normalizeImages(
      widget.resolveImages(_currentProduct),
      toLarge: false,
    );
    _images = _previewImages;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _precacheAround(_currentImage),
    );
    if (_currentProductId.isNotEmpty) {
      _loadFullImages(_currentProductId);
      _loadUpselling(product: _currentProduct);
      _loadCurrentProductInfo();
      _loadProductReviews(_currentProductId);
    }
    _ensureStoresHierarchy();
    if (widget.showStockSheetOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showStockAvailabilitySheet();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _normalizeImages(List<String> raw, {required bool toLarge}) {
    final result = <String>[];
    for (final url in raw) {
      final v = url.trim();
      if (v.isEmpty) continue;
      result.add(toLarge ? _toLargeImageUrl(v) : v);
    }
    return result;
  }

  String _toLargeImageUrl(String url) {
    return url.replaceAll(RegExp(r'\.\d+x\d+\.'), '.0x700.');
  }

  Future<void> _loadFullImages(String productId) async {
    final loader = widget.fetchImagesById;
    if (loader == null) return;
    final fetched = await loader(productId);
    if (!mounted || fetched.isEmpty) return;
    final normalized = _normalizeImages(fetched, toLarge: true);
    setState(() {
      _images = normalized;
      if (_previewImages.isEmpty) {
        _previewImages = _normalizeImages(fetched, toLarge: false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _precacheAround(_currentImage),
    );
  }

  void _precacheAround(int index) {
    if (!mounted || _images.isEmpty) return;
    final int start = (index - 2).clamp(0, _images.length - 1);
    final int end = (index + 2).clamp(0, _images.length - 1);
    for (int i = start; i <= end; i++) {
      precacheImage(CachedNetworkImageProvider(_images[i]), context);
    }
  }

  double _parseUpsellPrice(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value
          .replaceAll(RegExp(r'[^0-9.,]'), '')
          .replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  String _formatUpsellPrice(dynamic value, String currency) {
    final amount = _parseUpsellPrice(value);
    if (amount <= 0) return value?.toString() ?? "";
    final formatted = _formatPriceForIsolate(amount);
    if (currency == "RUB") return "$formatted ₽";
    if (currency.isNotEmpty) return "$formatted $currency";
    return formatted;
  }

  String _normalizeUpsellThumbUrl(String url) {
    if (url.isEmpty) return url;
    return url.replaceAll(RegExp(r'\.\d+x\d+\.'), '.0x400.');
  }

  String _normalizeUpsellPreviewUrl(String url) {
    if (url.isEmpty) return url;
    return url.replaceAll(RegExp(r'\.\d+x\d+\.'), '.0x400.');
  }

  static Future<void> prefetchGroupsCache() async {
    await _ensureGroupsCacheRaw();
  }

  static Future<File> _groupsCacheFile() async {
    _groupsCacheFileFuture ??= () async {
      final dir = Directory('${Directory.systemTemp.path}/hozyain_barin_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return File('${dir.path}/groups_cache.json');
    }();
    return _groupsCacheFileFuture!;
  }

  static Future<String?> _readGroupsCacheFromDisk() async {
    try {
      final file = await _groupsCacheFile();
      if (!await file.exists()) return null;
      final stat = await file.stat();
      final age = DateTime.now().difference(stat.modified);
      if (age > _groupsCacheTtl) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeGroupsCacheToDisk(String raw) async {
    try {
      final file = await _groupsCacheFile();
      await file.writeAsString(raw, flush: true);
    } catch (_) {
      // Ignore disk cache errors.
    }
  }

  static Future<String?> _ensureGroupsCacheRaw() async {
    final cached = _groupsCacheRaw;
    if (cached != null && cached.isNotEmpty) return cached;
    final disk = await _readGroupsCacheFromDisk();
    if (disk != null && disk.isNotEmpty) {
      _groupsCacheRaw = disk;
      return disk;
    }
    _groupsCacheRawFuture ??= _fetchGroupsCacheRaw();
    final raw = await _groupsCacheRawFuture!;
    _groupsCacheRawFuture = null;
    if (raw != null && raw.isNotEmpty) {
      _groupsCacheRaw = raw;
    }
    return _groupsCacheRaw;
  }

  static Future<String?> _fetchGroupsCacheRaw() async {
    try {
      final uri = Uri.parse(
        'https://hozyain-barin.ru/native/groups_cache.json',
      );
      final response = await _httpGet(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0',
        },
      );
      if (response.statusCode != 200) return null;
      final raw = utf8.decode(response.bodyBytes);
      if (raw.isNotEmpty) {
        _groupsCacheRaw = raw;
      }
      await _writeGroupsCacheToDisk(raw);
      return raw;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _fetchStoresHierarchy() async {
    try {
      final uri = Uri.parse(
        'https://hozyain-barin.ru/native/stores_hierarchy.json',
      );
      final response = await _httpGet(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0',
        },
      );
      if (response.statusCode != 200) return null;
      final raw = utf8.decode(response.bodyBytes);
      final decoded = json.decode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _ensureStoresHierarchy() async {
    final cached = _storesHierarchyCache;
    if (cached != null) return cached;
    _storesHierarchyInFlight ??= _fetchStoresHierarchy();
    final result = await _storesHierarchyInFlight!;
    _storesHierarchyInFlight = null;
    if (result != null) {
      _storesHierarchyCache = result;
    }
    return _storesHierarchyCache;
  }

  List<Map<String, dynamic>> _findGroupItemsByProductIdFromRaw(
    String raw,
    String productId,
  ) {
    if (raw.isEmpty || productId.isEmpty) return const <Map<String, dynamic>>[];
    final escapedId = RegExp.escape(productId);
    final isNumericId = RegExp(r'^\d+$').hasMatch(productId);
    final idPattern = isNumericId
        ? RegExp('"id"\\s*:\\s*(?:"$escapedId"|$escapedId(?!\\d))')
        : RegExp('"id"\\s*:\\s*"$escapedId"');
    final idMatch = idPattern.firstMatch(raw);
    if (idMatch == null) return const <Map<String, dynamic>>[];
    final before = raw.substring(0, idMatch.start);
    final groupPattern = RegExp('"([^"]+)"\\s*:\\s*\\[');
    RegExpMatch? lastGroup;
    for (final match in groupPattern.allMatches(before)) {
      lastGroup = match;
    }
    if (lastGroup == null) return const <Map<String, dynamic>>[];
    final startIndex = lastGroup.end - 1;
    int depth = 0;
    bool inString = false;
    bool escape = false;
    int endIndex = -1;
    for (int i = startIndex; i < raw.length; i++) {
      final ch = raw[i];
      if (inString) {
        if (escape) {
          escape = false;
        } else if (ch == '\\') {
          escape = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '[') {
        depth++;
      } else if (ch == ']') {
        depth--;
        if (depth == 0) {
          endIndex = i;
          break;
        }
      }
    }
    if (endIndex == -1) return const <Map<String, dynamic>>[];
    final slice = raw.substring(startIndex, endIndex + 1);
    try {
      final decoded = json.decode(slice);
      if (decoded is! List) return const <Map<String, dynamic>>[];
      final list = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map) {
          list.add(Map<String, dynamic>.from(item));
        }
      }
      return list;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> _getProductInfoCached(String productId) async {
    if (productId.isEmpty) return null;
    final cached = _productInfoCache[productId];
    if (cached != null) return cached;
    final existing = _productInfoInFlight[productId];
    if (existing != null) return existing;
    final fetcher = widget.fetchProductById;
    if (fetcher == null) return null;
    final future = fetcher(productId)
        .then((value) {
          if (value != null) {
            _productInfoCache[productId] = value;
          }
          return value;
        })
        .whenComplete(() {
          _productInfoInFlight.remove(productId);
        });
    _productInfoInFlight[productId] = future;
    return future;
  }

  void _prefetchUpsellProductInfo(List<Map<String, dynamic>> items) {
    if (items.isEmpty || widget.fetchProductById == null) return;
    final ids = <String>[];
    for (final item in items) {
      final id = item['id']?.toString() ?? "";
      if (id.isEmpty) continue;
      if (_productInfoCache.containsKey(id)) continue;
      ids.add(id);
    }
    if (ids.isEmpty) return;
    const int maxConcurrent = 3;
    () async {
      int cursor = 0;
      Future<void> worker() async {
        while (true) {
          if (cursor >= ids.length) return;
          final id = ids[cursor++];
          await _getProductInfoCached(id);
        }
      }

      final int workers = ids.length < maxConcurrent
          ? ids.length
          : maxConcurrent;
      await Future.wait(List.generate(workers, (_) => worker()));
    }();
  }

  Future<void> _loadUpselling({
    Map<String, dynamic>? product,
    bool force = false,
  }) async {
    if (_isUpsellLoading && !force) return;
    setState(() => _isUpsellLoading = true);
    final target = product ?? _currentProduct;
    final productId = target['id']?.toString() ?? _currentProductId;
    try {
      if (productId.isEmpty) {
        if (mounted) setState(() => _upsellItems = []);
        return;
      }
      final cachedItems = _groupsByProductIdCache[productId];
      if (cachedItems != null) {
        if (mounted) setState(() => _upsellItems = cachedItems);
        return;
      }
      final raw = await _ensureGroupsCacheRaw();
      if (raw == null || raw.isEmpty) {
        if (mounted) setState(() => _upsellItems = []);
        return;
      }
      var rawList = _findGroupItemsByProductIdFromRaw(raw, productId);
      if (rawList.isEmpty) {
        final refreshed = await _fetchGroupsCacheRaw();
        if (refreshed != null && refreshed.isNotEmpty) {
          rawList = _findGroupItemsByProductIdFromRaw(refreshed, productId);
        }
      }
      if (rawList.isEmpty) {
        if (mounted) setState(() => _upsellItems = []);
        return;
      }
      final nextItems = <Map<String, dynamic>>[];
      for (final item in rawList) {
        final id = item['id']?.toString() ?? "";
        if (id.isEmpty) continue;
        final name = item['name']?.toString() ?? "";
        final currency = item['currency']?.toString() ?? "RUB";
        final priceText = _formatUpsellPrice(item['price'], currency);
        final rawImageUrl = item['image_url']?.toString() ?? "";
        final thumbUrl = _normalizeUpsellThumbUrl(rawImageUrl);
        final previewUrl = _normalizeUpsellPreviewUrl(rawImageUrl);
        final imageUrl = previewUrl.isNotEmpty ? previewUrl : thumbUrl;
        final frontendUrl = item['frontend_url']?.toString() ?? "";
        nextItems.add({
          "id": id,
          "name": name,
          "price": priceText,
          "image_url": imageUrl,
          if (thumbUrl.isNotEmpty) "thumb_url": thumbUrl,
          if (imageUrl.isNotEmpty) "images": [imageUrl],
          if (imageUrl.isNotEmpty) "image": imageUrl,
          if (frontendUrl.isNotEmpty) "frontend_url": frontendUrl,
        });
      }
      if (mounted) {
        for (final item in nextItems) {
          final id = item['id']?.toString() ?? "";
          if (id.isNotEmpty) {
            _groupsByProductIdCache[id] = nextItems;
          }
        }
        setState(() => _upsellItems = nextItems);
      }
      _prefetchUpsellProductInfo(nextItems);
    } catch (e, st) {
      debugPrint("Upselling load error: $e");
      if (kDebugMode) debugPrint("$st");
    } finally {
      if (mounted) setState(() => _isUpsellLoading = false);
    }
  }

  void _applyProduct(Map<String, dynamic> product, {bool resetImages = true}) {
    final previousId = _currentProductId;
    _currentProduct = Map<String, dynamic>.from(product);
    _currentProductId = _currentProduct['id']?.toString() ?? "";
    if (previousId != _currentProductId) {
      _isDescriptionExpanded = false;
      _reviews = [];
      _reviewsAverage = 0.0;
      _reviewsCount = 0;
      _reviewsByRating = {};
      _reviewsRatedCount = 0;
      _reviewsFilter = "all";
      _reviewsOnlyWithPhotos = false;
      _isReviewsLoading = false;
    }
    _favoriteListenable = widget.resolveFavoriteListenable?.call(
      _currentProductId,
    );
    _compareListenable = widget.resolveCompareListenable?.call(
      _currentProductId,
    );
    _galleryListenable = widget.resolveGalleryListenable?.call(
      _currentProductId,
    );
    if (resetImages) {
      _currentImage = 0;
      _previewImages = _normalizeImages(
        widget.resolveImages(_currentProduct),
        toLarge: false,
      );
      _images = _previewImages;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  Future<void> _switchToProduct(Map<String, dynamic> product) async {
    final id = product['id']?.toString() ?? "";
    if (id.isEmpty || id == _currentProductId) return;
    final cached = _productInfoCache[id];
    final quick = <String, dynamic>{
      "id": id,
      "name": product['name'] ?? "",
      "price": product['price'] ?? "",
      "old_price": "",
      "discount": "",
      "benefit": "",
    };
    final imageUrl = _normalizeUpsellPreviewUrl(
      product['image_url']?.toString() ?? "",
    );
    if (imageUrl.isNotEmpty) {
      quick["image"] = imageUrl;
      quick["image_url"] = imageUrl;
      quick["images"] = [imageUrl];
    }
    setState(() {
      _applyProduct(cached ?? quick, resetImages: true);
      _upsellItems = [];
      _isUpsellLoading = true;
      _isProductInfoLoading = true;
      _isReviewsLoading = true;
    });
    _loadUpselling(product: _currentProduct, force: true);
    _loadProductReviews(id);
    final full = await _getProductInfoCached(id);
    if (!mounted || _currentProductId != id) return;
    if (full != null) {
      final merged = Map<String, dynamic>.from(_currentProduct)..addAll(full);
      setState(() {
        _applyProduct(merged, resetImages: true);
        _isProductInfoLoading = false;
      });
      _loadUpselling(product: _currentProduct, force: true);
    } else {
      setState(() => _isProductInfoLoading = false);
    }
    if (widget.fetchImagesById != null) {
      _loadFullImages(id);
    }
  }

  List<Map<String, dynamic>> _buildUpsellThumbs() {
    if (_upsellItems.isEmpty) return const <Map<String, dynamic>>[];
    return List<Map<String, dynamic>>.from(_upsellItems);
  }

  Widget _buildUpsellPhoto(
    Map<String, dynamic> product, {
    required bool isActive,
    required double width,
    required double height,
  }) {
    final imageUrl =
        (product['thumb_url'] ?? product['image_url'])?.toString() ?? "";
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final int cacheWidth = (width * dpr).round().clamp(1, 2000);
    final int cacheHeight = (height * dpr).round().clamp(1, 2000);
    return GestureDetector(
      onTap: isActive ? null : () => _switchToProduct(product),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? Colors.black : Colors.transparent,
            width: isActive ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            width: width,
            height: height,
            child: imageUrl.isEmpty
                ? Container(color: Colors.grey.shade100)
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: cacheWidth,
                    memCacheHeight: cacheHeight,
                    fadeInDuration: const Duration(milliseconds: 160),
                    fadeOutDuration: const Duration(milliseconds: 120),
                    placeholder: (_, __) =>
                        Container(color: Colors.grey.shade100),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpsellSection() {
    if (_upsellItems.isEmpty) return const SizedBox.shrink();
    final colorName = _resolveColorName(_currentProduct);
    return Column(
      children: [
        const SizedBox(height: 6),
        _buildUpsellPhotosBlock(colorName: colorName),
      ],
    );
  }

  Widget _buildUpsellPhotosBlock({String? colorName}) {
    if (_upsellItems.isEmpty) return const SizedBox.shrink();
    final thumbs = _buildUpsellThumbs();
    final int count = thumbs.length;
    final String colorText = _capitalizeFirst(colorName ?? "");
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  const double gap = 6;
                  const double aspect = 86 / 64;
                  final double maxWidth = constraints.maxWidth;
                  final double thumbWidth = ((maxWidth - gap * 4) / 5).clamp(
                    40.0,
                    64.0,
                  );
                  final double thumbHeight = thumbWidth * aspect;
                  return SizedBox(
                    height: thumbHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: count,
                      separatorBuilder: (_, __) => const SizedBox(width: gap),
                      itemBuilder: (context, index) {
                        final item = thumbs[index];
                        final isActive =
                            item['id']?.toString() == _currentProductId;
                        return _buildUpsellPhoto(
                          item,
                          isActive: isActive,
                          width: thumbWidth,
                          height: thumbHeight,
                        );
                      },
                    ),
                  );
                },
              ),
              if (colorText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Цвет: ",
                        style: _subMenuStyle.copyWith(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      TextSpan(
                        text: colorText,
                        style: _subMenuStyle.copyWith(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(
    String text,
    Color color, {
    Color textColor = Colors.black,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: _subMenuStyle.copyWith(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildIndicator(int count) {
    if (count <= 1) return const SizedBox.shrink();
    final active = _currentImage.clamp(0, count - 1);
    int startIndex = active - 2;
    int endIndex = active + 2;
    if (startIndex < 0) startIndex = 0;
    if (endIndex > count - 1) endIndex = count - 1;
    final visibleCount = endIndex - startIndex + 1;
    const int maxDots = 5;
    const double activeSize = 8;
    const double nearSize = 6;
    const double farSize = 4;
    const double step = 12;
    const double totalWidth = (maxDots - 1) * step + activeSize;
    final double offset = ((maxDots - visibleCount) * step) / 2;
    return Center(
      child: SizedBox(
        width: totalWidth,
        height: activeSize,
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: List.generate(visibleCount, (i) {
            final index = startIndex + i;
            final distance = (index - active).abs();
            double size;
            double opacity;
            if (distance == 0) {
              size = activeSize;
              opacity = 1.0;
            } else if (distance == 1) {
              size = nearSize;
              opacity = 0.7;
            } else {
              size = farSize;
              opacity = 0.45;
            }
            final centerX = offset + i * step + activeSize / 2;
            final left = centerX - size / 2;
            final top = (activeSize - size) / 2;
            return AnimatedPositioned(
              key: ValueKey<int>(index),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: left,
              top: top,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Center(
          child: Icon(
            icon,
            size: 22,
            color: active ? Colors.black : Colors.black26,
          ),
        ),
      ),
    );
  }

  Future<void> _loadCurrentProductInfo() async {
    if (_currentProductId.isEmpty || widget.fetchProductById == null) return;
    final targetId = _currentProductId;
    if (mounted) {
      setState(() => _isProductInfoLoading = true);
    } else {
      _isProductInfoLoading = true;
    }
    final full = await _getProductInfoCached(targetId);
    if (!mounted || _currentProductId != targetId) return;
    if (full != null) {
      final merged = Map<String, dynamic>.from(_currentProduct)..addAll(full);
      setState(() {
        _applyProduct(merged, resetImages: false);
        _isProductInfoLoading = false;
      });
      return;
    }
    setState(() => _isProductInfoLoading = false);
  }

  Future<List<Map<String, dynamic>>> _getProductReviewsCached(
    String productId,
  ) async {
    if (productId.isEmpty) return const <Map<String, dynamic>>[];
    final cached = _productReviewsCache[productId];
    if (cached != null) return cached;
    final existing = _productReviewsInFlight[productId];
    if (existing != null) return existing;
    final fetcher = widget.fetchReviewsById;
    if (fetcher == null) return const <Map<String, dynamic>>[];
    final future = fetcher(productId)
        .then((value) {
          _productReviewsCache[productId] = value;
          return value;
        })
        .catchError((_) {
          return const <Map<String, dynamic>>[];
        })
        .whenComplete(() {
          _productReviewsInFlight.remove(productId);
        });
    _productReviewsInFlight[productId] = future;
    return future;
  }

  Future<Map<String, dynamic>?> _getCustomerInfoCached(String contactId) async {
    if (contactId.isEmpty) return null;
    final cached = _customerInfoCache[contactId];
    if (cached != null) return cached;
    final existing = _customerInfoInFlight[contactId];
    if (existing != null) return existing;
    final fetcher = widget.fetchCustomerById;
    if (fetcher == null) return null;
    final future = fetcher(contactId)
        .then((value) {
          if (value != null) {
            _customerInfoCache[contactId] = value;
          }
          return value;
        })
        .catchError((_) {
          return null;
        })
        .whenComplete(() {
          _customerInfoInFlight.remove(contactId);
        });
    _customerInfoInFlight[contactId] = future;
    return future;
  }

  double _parseReviewRating(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.replaceAll(",", ".")) ?? 0.0;
    return 0.0;
  }

  DateTime? _parseReviewDateTime(String raw) {
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll("T", " ").split(".").first.trim();
    final tryIso = cleaned.contains(" ")
        ? cleaned.replaceFirst(" ", "T")
        : cleaned;
    return DateTime.tryParse(tryIso);
  }

  String _resolveReviewAuthor(Map review) {
    final author =
        (review['name'] ??
                review['author'] ??
                review['contact_name'] ??
                (review['contact'] is Map ? review['contact']['name'] : null))
            ?.toString()
            .trim() ??
        "";
    return author;
  }

  String _resolveReviewAvatarUrl(Map review) {
    final direct =
        review['photo_url'] ??
        review['photo'] ??
        review['userpic'] ??
        review['userpic_url'] ??
        review['contact_photo_url'] ??
        review['contact_photo'] ??
        review['photo_url_96'] ??
        review['photo_url_40'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }
    final contact = review['contact'];
    if (contact is Map) {
      final c =
          contact['photo_url'] ??
          contact['photo'] ??
          contact['userpic'] ??
          contact['userpic_url'] ??
          contact['photo_url_96'] ??
          contact['photo_url_40'];
      if (c != null && c.toString().trim().isNotEmpty) {
        return c.toString();
      }
    }
    return "";
  }

  String _normalizeAvatarUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith("http://") || value.startsWith("https://")) {
      return value;
    }
    if (value.startsWith("//")) return "https:$value";
    if (value.startsWith("/")) return "https://hozyain-barin.ru$value";
    return value;
  }

  String _normalizeReviewImageUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith("http://") || value.startsWith("https://")) {
      return value;
    }
    if (value.startsWith("//")) return "https:$value";
    if (value.startsWith("/")) return "https://hozyain-barin.ru$value";
    return "https://hozyain-barin.ru/$value";
  }

  List<String> _extractReviewImages(Map review, {bool preferFull = false}) {
    final List<String> result = [];
    void addValue(dynamic value) {
      if (value == null) return;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        if (!trimmed.contains("/") && !trimmed.contains(".")) return;
        final url = _normalizeReviewImageUrl(value);
        if (url.isNotEmpty) result.add(url);
        return;
      }
      if (value is List) {
        for (final item in value) {
          addValue(item);
        }
        return;
      }
      if (value is Map) {
        final direct = preferFull
            ? (value['url_full'] ??
                  value['full_url'] ??
                  value['original_url'] ??
                  value['url'] ??
                  value['image_url'] ??
                  value['src'] ??
                  value['path'] ??
                  value['file'] ??
                  value['url_thumb'] ??
                  value['thumb_url'] ??
                  value['preview_url'])
            : (value['url_thumb'] ??
                  value['thumb_url'] ??
                  value['preview_url'] ??
                  value['url'] ??
                  value['image_url'] ??
                  value['original_url'] ??
                  value['full_url'] ??
                  value['src'] ??
                  value['path'] ??
                  value['file'] ??
                  value['url_full']);
        if (direct != null) {
          addValue(direct);
          return;
        }
        final thumbs = value['thumbs'];
        if (thumbs is Map && thumbs.isNotEmpty) {
          final entries = thumbs.entries.toList();
          entries.sort((a, b) {
            final aNum =
                int.tryParse(a.key.toString().replaceAll(RegExp(r'\D'), '')) ??
                0;
            final bNum =
                int.tryParse(b.key.toString().replaceAll(RegExp(r'\D'), '')) ??
                0;
            return aNum.compareTo(bNum);
          });
          addValue(entries.isNotEmpty ? entries.last.value : null);
          return;
        }
        final urls = value['urls'];
        if (urls is List) {
          addValue(urls);
          return;
        }
        for (final entry in value.values) {
          if (entry is String || entry is Map || entry is List) {
            addValue(entry);
          }
        }
      }
    }

    addValue(review['images']);
    addValue(review['images_url']);
    addValue(review['image_url']);
    addValue(review['photos']);
    addValue(review['attachments']);
    addValue(review['files']);

    if (result.isEmpty) return result;
    final seen = <String>{};
    final unique = <String>[];
    for (final url in result) {
      if (seen.add(url)) unique.add(url);
    }
    return unique;
  }

  String _readReviewText(dynamic value) {
    if (value == null) return "";
    return _stripHtml(value.toString());
  }

  List<Map<String, dynamic>> _flattenReviews(dynamic raw) {
    final List<Map<String, dynamic>> result = [];
    void walk(Map review, int depth) {
      final status = review['status']?.toString();
      if (status == "deleted" || status == "moderation") return;
      final title = _readReviewText(review['title'] ?? review['subject'] ?? "");
      final text = _readReviewText(
        review['text'] ?? review['comment'] ?? review['review'] ?? "",
      );
      final author = _resolveReviewAuthor(review);
      final datetime =
          (review['datetime'] ??
                  review['date'] ??
                  review['created_at'] ??
                  review['created'] ??
                  review['time'])
              ?.toString()
              .trim() ??
          "";
      final rating = _parseReviewRating(
        review['rate'] ?? review['rating'] ?? review['score'],
      );
      final avatarUrl = _resolveReviewAvatarUrl(review);
      final images = _extractReviewImages(review);
      final imagesFull = _extractReviewImages(review, preferFull: true);
      final contactId =
          (review['contact_id'] ??
                  review['contactId'] ??
                  review['author_id'] ??
                  review['user_id'] ??
                  review['customer_id'])
              ?.toString() ??
          "";
      final authProvider = review['auth_provider']?.toString() ?? "";
      if (title.isEmpty && text.isEmpty && author.isEmpty && rating <= 0) {
        // keep empty comments out of the list
      } else {
        result.add({
          "title": title,
          "text": text,
          "author": author,
          "datetime": datetime,
          "rating": rating,
          "depth": depth,
          "avatar": avatarUrl,
          if (images.isNotEmpty) "images": images,
          if (imagesFull.isNotEmpty) "imagesFull": imagesFull,
          "contactId": contactId,
          "authProvider": authProvider,
        });
      }
      final comments =
          review['comments'] ?? review['children'] ?? review['replies'];
      if (comments is List) {
        for (final item in comments) {
          if (item is Map) walk(item, depth + 1);
        }
      }
    }

    dynamic data = raw;
    if (raw is Map) {
      if (raw['data'] is List) data = raw['data'];
      if (raw['reviews'] is List) data = raw['reviews'];
    }
    if (data is List) {
      final roots = data.whereType<Map>().toList();
      roots.sort((a, b) {
        final adRaw =
            (a['datetime'] ??
                    a['date'] ??
                    a['created_at'] ??
                    a['created'] ??
                    a['time'])
                ?.toString() ??
            "";
        final bdRaw =
            (b['datetime'] ??
                    b['date'] ??
                    b['created_at'] ??
                    b['created'] ??
                    b['time'])
                ?.toString() ??
            "";
        final ad =
            _parseReviewDateTime(adRaw) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bd =
            _parseReviewDateTime(bdRaw) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      for (final item in roots) {
        walk(item, 0);
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _hydrateReviewContacts(
    List<Map<String, dynamic>> reviews,
  ) async {
    if (widget.fetchCustomerById == null) return reviews;
    final ids = <String>{};
    for (final item in reviews) {
      final contactId = item['contactId']?.toString() ?? "";
      if (contactId.isEmpty) continue;
      final hasName = (item['author']?.toString().trim() ?? "").isNotEmpty;
      final hasAvatar = (item['avatar']?.toString().trim() ?? "").isNotEmpty;
      if (hasName && hasAvatar) continue;
      ids.add(contactId);
    }
    if (ids.isEmpty) return reviews;
    const int maxConcurrent = 3;
    final idList = ids.toList();
    int cursor = 0;
    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= idList.length) return;
        await _getCustomerInfoCached(idList[index]);
      }
    }

    final workers = idList.length < maxConcurrent
        ? idList.length
        : maxConcurrent;
    await Future.wait(List.generate(workers, (_) => worker()));
    for (final item in reviews) {
      final contactId = item['contactId']?.toString() ?? "";
      if (contactId.isEmpty) continue;
      final info = _customerInfoCache[contactId];
      if (info == null) continue;
      final currentName = item['author']?.toString().trim() ?? "";
      final isPlaceholder =
          currentName.isEmpty ||
          currentName.toLowerCase() == "гость" ||
          currentName.toLowerCase() == "покупатель";
      if (isPlaceholder) {
        final name = info['name']?.toString().trim() ?? "";
        if (name.isNotEmpty) item['author'] = name;
      }
      if ((item['avatar']?.toString().trim() ?? "").isEmpty) {
        final avatar = info['photo_url']?.toString().trim() ?? "";
        if (avatar.isNotEmpty) item['avatar'] = avatar;
      }
    }
    return reviews;
  }

  void _computeReviewsSummary(List<Map<String, dynamic>> reviews) {
    final counts = <int, int>{};
    double sum = 0.0;
    int count = 0;
    int ratingCount = 0;
    for (final item in reviews) {
      final depth = item['depth'] as int? ?? 0;
      final rating = item['rating'] as double? ?? 0.0;
      if (depth > 0) continue;
      count += 1;
      if (rating <= 0) continue;
      ratingCount += 1;
      sum += rating;
      final bucket = rating.round().clamp(1, 5);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    _reviewsCount = count;
    _reviewsAverage = ratingCount > 0 ? (sum / ratingCount) : 0.0;
    _reviewsByRating = counts;
    _reviewsRatedCount = ratingCount;
  }

  Future<void> _loadProductReviews(String productId) async {
    if (productId.isEmpty || widget.fetchReviewsById == null) {
      if (mounted) {
        setState(() {
          _reviews = [];
          _isReviewsLoading = false;
          _reviewsAverage = 0.0;
          _reviewsCount = 0;
          _reviewsByRating = {};
          _reviewsRatedCount = 0;
          _reviewsFilter = "all";
          _reviewsOnlyWithPhotos = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() => _isReviewsLoading = true);
    } else {
      _isReviewsLoading = true;
    }
    final raw = await _getProductReviewsCached(productId);
    if (!mounted || _currentProductId != productId) return;
    final normalized = _flattenReviews(raw);
    final enriched = await _hydrateReviewContacts(normalized);
    if (!mounted || _currentProductId != productId) return;
    setState(() {
      _reviews = enriched;
      _computeReviewsSummary(enriched);
      _isReviewsLoading = false;
    });
  }

  String _stripHtml(String input) {
    if (input.isEmpty) return "";
    String text = input;
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\s+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n\s+'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  String _normalizeDescriptionHtml(String html) {
    if (html.isEmpty) return html;
    String out = html;
    out = out.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '<br><br>',
    );
    out = out.replaceAll(
      RegExp(r'font-size\s*:\s*18px', caseSensitive: false),
      'font-size: 15px',
    );
    return out;
  }

  Future<void> _openExternalLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openReviewsForm() {
    final productId = _currentProductId;
    if (productId.isEmpty) return;
    final submit = widget.submitReview;
    Navigator.push(
      context,
      _adaptivePageRoute(
        builder: (_) => _ReviewFormPage(
          productId: productId,
          productName: _currentProduct['name']?.toString() ?? "",
          submitReview: submit,
          onSubmitted: () => _loadProductReviews(productId),
        ),
      ),
    );
  }

  String _resolveDescriptionHtml(Map product) {
    final raw =
        product['description'] ??
        product['summary'] ??
        product['short_description'] ??
        product['shortDescription'] ??
        product['text'];
    if (raw == null) return "";
    return _normalizeDescriptionHtml(raw.toString());
  }

  TextStyle _descriptionTextStyle() {
    return _subMenuStyle.copyWith(
      fontSize: _descriptionFontSize,
      height: 1.35,
      color: Colors.black87,
    );
  }

  Map<String, Style> _descriptionHtmlStyle() {
    return {
      "body": Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        fontSize: FontSize(_descriptionFontSize),
        lineHeight: const LineHeight(1.35),
        color: Colors.black87,
      ),
      "br": Style(lineHeight: const LineHeight(0.25)),
      "p": Style(margin: Margins.only(bottom: 8)),
      "h1": Style(
        fontSize: FontSize(18),
        fontWeight: FontWeight.w700,
        lineHeight: const LineHeight(1.25),
        margin: Margins.only(bottom: 8),
      ),
      "h2": Style(
        fontSize: FontSize(16),
        fontWeight: FontWeight.w700,
        lineHeight: const LineHeight(1.25),
        margin: Margins.only(bottom: 6),
      ),
      "h3": Style(
        fontSize: FontSize(15),
        fontWeight: FontWeight.w600,
        lineHeight: const LineHeight(1.25),
        margin: Margins.only(bottom: 6),
      ),
      "ul": Style(
        margin: Margins.only(bottom: 8),
        padding: HtmlPaddings.only(left: 18),
      ),
      "ol": Style(
        margin: Margins.only(bottom: 8),
        padding: HtmlPaddings.only(left: 18),
      ),
      "li": Style(margin: Margins.only(bottom: 4)),
      "a": Style(color: Colors.black, textDecoration: TextDecoration.underline),
      "strong": Style(fontWeight: FontWeight.w600),
      "em": Style(fontStyle: FontStyle.italic),
    };
  }

  Widget _buildDescriptionHtml(String html) {
    return Html(
      data: html,
      onLinkTap: (url, _, __) => _openExternalLink(url),
      style: _descriptionHtmlStyle(),
    );
  }

  Widget _buildDescriptionSection() {
    final descriptionHtml = _resolveDescriptionHtml(_currentProduct);
    final descriptionPlain = _stripHtml(descriptionHtml);
    if (descriptionPlain.isEmpty) {
      return Text(
        _isProductInfoLoading
            ? "Описание загружается..."
            : "Описание отсутствует",
        style: _subMenuStyle.copyWith(fontSize: 13, color: Colors.black54),
      );
    }
    if (_isDescriptionExpanded) {
      return _buildDescriptionHtml(descriptionHtml);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final textStyle = _descriptionTextStyle();
        final textSpan = TextSpan(text: descriptionPlain, style: textStyle);
        final painter = TextPainter(
          text: textSpan,
          maxLines: _descriptionMaxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: maxWidth);
        final isOverflow = painter.didExceedMaxLines;
        if (!isOverflow) {
          return _buildDescriptionHtml(descriptionHtml);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descriptionPlain,
              style: textStyle,
              maxLines: _descriptionMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _isDescriptionExpanded = true),
              child: Text(
                "Показать полностью",
                style: _subMenuStyle.copyWith(
                  fontSize: 14,
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _normalizeFeatureValuesLocal(dynamic rawValue) {
    final List<String> values = [];
    if (rawValue == null) return values;
    if (rawValue is List) {
      for (final item in rawValue) {
        if (item is Map) {
          if (item['value'] != null) {
            values.add(item['value'].toString());
          } else if (item['name'] != null) {
            values.add(item['name'].toString());
          } else {
            values.add(item.toString());
          }
        } else {
          values.add(item.toString());
        }
      }
    } else if (rawValue is Map) {
      if (rawValue['value'] != null) {
        values.add(rawValue['value'].toString());
      } else if (rawValue['name'] != null) {
        values.add(rawValue['name'].toString());
      } else {
        values.add(rawValue.toString());
      }
    } else {
      values.add(rawValue.toString());
    }
    return values;
  }

  String? _overrideFeatureLabel(String? raw) {
    if (raw == null) return null;
    final key = raw.trim().toLowerCase();
    if (key == "parametry_izdeliya") return "Параметры изделия";
    if (key == "obratite_vnimanie") return "Обратите внимание";
    return null;
  }

  String _resolveFeatureValueText(String fid, dynamic rawValue) {
    final values = _normalizeFeatureValuesLocal(rawValue);
    if (values.isEmpty) return "";
    final textMap = fid.isNotEmpty ? widget.featureValueTextById[fid] : null;
    final resolved = values
        .map((value) {
          final mapped = textMap?[value];
          return (mapped == null || mapped.isEmpty) ? value : mapped;
        })
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return resolved.join(", ");
  }

  String _resolveColorName(Map product) {
    final rawFeatures = product['features'];
    if (rawFeatures is! Map || rawFeatures.isEmpty) return "";
    final featuresMap = Map<String, dynamic>.from(rawFeatures);
    for (final feature in widget.availableFeatures) {
      if (feature is! Map) continue;
      final fid = feature['id']?.toString() ?? "";
      final name = feature['name']?.toString() ?? "";
      String code = feature['code']?.toString() ?? "";
      if (code.isEmpty) {
        code = widget.featureCodeById[fid] ?? "";
      }
      final nameLower = name.toLowerCase();
      final codeLower = code.toLowerCase();
      final isColor =
          nameLower.contains("цвет") ||
          codeLower.contains("color") ||
          codeLower.contains("цвет");
      if (!isColor) continue;
      dynamic rawValue;
      if (code.isNotEmpty && featuresMap.containsKey(code)) {
        rawValue = featuresMap[code];
      } else if (fid.isNotEmpty && featuresMap.containsKey(fid)) {
        rawValue = featuresMap[fid];
      }
      if (rawValue == null) continue;
      final valueText = _resolveFeatureValueText(fid, rawValue);
      if (valueText.isNotEmpty) return valueText;
    }
    for (final entry in featuresMap.entries) {
      final keyLower = entry.key.toString().toLowerCase();
      if (!keyLower.contains("цвет") && !keyLower.contains("color")) continue;
      final valueText = _resolveFeatureValueText("", entry.value);
      if (valueText.isNotEmpty) return valueText;
    }
    return "";
  }

  String _capitalizeFirst(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return "";
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  List<Map<String, String>> _resolveFeatureRows(Map product) {
    final rawFeatures = product['features'];
    if (rawFeatures is! Map || rawFeatures.isEmpty) return const [];
    final featuresMap = Map<String, dynamic>.from(rawFeatures);
    final rows = <Map<String, String>>[];
    final usedKeys = <String>{};
    const String hiddenFeatureKey = "fstock";
    final available = widget.availableFeatures;
    if (available.isNotEmpty) {
      for (final feature in available) {
        if (feature is! Map) continue;
        final fid = feature['id']?.toString() ?? "";
        final rawLabel = feature['name']?.toString() ?? "";
        final code = (feature['code']?.toString() ?? "").trim();
        if (fid == hiddenFeatureKey ||
            code == hiddenFeatureKey ||
            rawLabel == hiddenFeatureKey) {
          continue;
        }
        final overrideLabel =
            _overrideFeatureLabel(rawLabel) ??
            _overrideFeatureLabel(code) ??
            _overrideFeatureLabel(fid);
        final label = overrideLabel ?? rawLabel;
        if (label.isEmpty) continue;
        String? resolvedCode = code.isNotEmpty
            ? code
            : widget.featureCodeById[fid];
        if (resolvedCode == hiddenFeatureKey) {
          continue;
        }
        dynamic rawValue;
        if (resolvedCode != null &&
            resolvedCode.isNotEmpty &&
            featuresMap.containsKey(resolvedCode)) {
          rawValue = featuresMap[resolvedCode];
          usedKeys.add(resolvedCode);
        } else if (fid.isNotEmpty && featuresMap.containsKey(fid)) {
          rawValue = featuresMap[fid];
          usedKeys.add(fid);
        } else {
          continue;
        }
        final valueText = _resolveFeatureValueText(fid, rawValue);
        if (valueText.isEmpty) continue;
        rows.add({"label": label, "value": valueText});
      }
    }
    for (final entry in featuresMap.entries) {
      final key = entry.key.toString();
      if (key == hiddenFeatureKey) continue;
      if (usedKeys.contains(key)) continue;
      final label = _overrideFeatureLabel(key) ?? key;
      final valueText = _resolveFeatureValueText("", entry.value);
      if (valueText.isEmpty) continue;
      rows.add({"label": label, "value": valueText});
    }
    return rows;
  }

  Widget _buildDetailTab({required String title, required int index}) {
    final bool isActive = _detailTabIndex == index;
    final style = (isActive ? _boldSubMenuStyle : _subMenuStyle).copyWith(
      fontSize: 16,
      color: isActive ? Colors.black : Colors.black54,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _detailTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Colors.black : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(title, style: style),
      ),
    );
  }

  Widget _buildDetailTabs() {
    const String reviewsTitle = "Отзывы";
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _buildDetailTab(title: "Описание", index: 0),
        _buildDetailTab(title: "Характеристики", index: 1),
        _buildDetailTab(title: reviewsTitle, index: 2),
      ],
    );
  }

  Widget _buildFeatureRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: _subMenuStyle.copyWith(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: _subMenuStyle.copyWith(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _resolveCurrentStockMap() {
    final id = _currentProductId;
    if (id.isNotEmpty) {
      final resolved = widget.resolveStockMap?.call(id);
      if (resolved != null && resolved.isNotEmpty) {
        return Map<String, int>.from(resolved);
      }
    }
    final raw = _currentProduct['stock_map'];
    if (raw is Map) {
      final mapped = <String, int>{};
      raw.forEach((key, value) {
        final sid = key?.toString() ?? "";
        if (sid.isEmpty) return;
        final count = (value is num)
            ? value.toInt()
            : int.tryParse(value?.toString() ?? "0") ?? 0;
        if (count <= 0) return;
        mapped[sid] = count;
      });
      if (mapped.isNotEmpty) return mapped;
    }
    return {};
  }

  Set<String> _extractExcludedStockIds(Map<String, dynamic>? hierarchy) {
    if (hierarchy == null) return {};
    final settings = hierarchy['settings'];
    final exclude = (settings is Map) ? settings['exclude_ids'] : null;
    if (exclude is! List) return {};
    return exclude.where((id) => id != null).map((id) => id.toString()).toSet();
  }

  Map<String, int> _filterStockMap(
    Map<String, int> stockMap,
    Set<String> excludeIds,
  ) {
    if (excludeIds.isEmpty) return stockMap;
    final filtered = <String, int>{};
    stockMap.forEach((id, count) {
      if (count <= 0) return;
      if (excludeIds.contains(id)) return;
      filtered[id] = count;
    });
    return filtered;
  }

  String _resolveStockNameById(String stockId) {
    for (final stock in widget.availableStocks) {
      if (stock is! Map) continue;
      final id = stock['id']?.toString() ?? "";
      if (id != stockId) continue;
      final name = stock['name']?.toString() ?? "";
      if (name.isNotEmpty) return name;
    }
    return stockId;
  }

  String _resolveStockCity(dynamic stock) {
    if (stock is! Map) return "";
    final city = stock['city']?.toString().trim() ?? "";
    if (city.isNotEmpty) return city;
    final name = stock['name']?.toString() ?? "";
    final match = RegExp(r'\\(([^)]+)\\)').firstMatch(name);
    return match?.group(1)?.trim() ?? "";
  }

  List<Map<String, dynamic>> _buildStockEntries(Map<String, int> stockMap) {
    final entries = <Map<String, dynamic>>[];
    final usedIds = <String>{};
    for (final stock in widget.availableStocks) {
      if (stock is! Map) continue;
      final sid = stock['id']?.toString() ?? "";
      if (sid.isEmpty) continue;
      final count = stockMap[sid] ?? 0;
      if (count <= 0) continue;
      final name = stock['name']?.toString() ?? sid;
      final city = _resolveStockCity(stock);
      entries.add({"city": city, "name": name, "count": count});
      usedIds.add(sid);
    }
    for (final entry in stockMap.entries) {
      if (usedIds.contains(entry.key)) continue;
      if (entry.value <= 0) continue;
      entries.add({"city": "", "name": entry.key, "count": entry.value});
    }
    return entries;
  }

  Map<String, List<Map<String, dynamic>>> _groupStockEntries(
    List<Map<String, dynamic>> entries,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final entry in entries) {
      final city = entry["city"]?.toString().trim() ?? "";
      final key = city.isNotEmpty ? city : "Магазины";
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  List<Map<String, dynamic>> _buildHierarchyGroups(
    Map<String, int> stockMap,
    Map<String, dynamic> hierarchy,
  ) {
    final cities = hierarchy['cities'];
    if (cities is! List) return const [];
    final groups = <Map<String, dynamic>>[];
    for (final cityEntry in cities) {
      if (cityEntry is! Map) continue;
      final title = cityEntry['group_name']?.toString().trim() ?? "";
      if (title.isEmpty) continue;
      final stocks = cityEntry['stocks'];
      if (stocks is! List) continue;
      final items = <Map<String, dynamic>>[];
      for (final stock in stocks) {
        if (stock is! Map) continue;
        final id = stock['id']?.toString() ?? "";
        if (id.isEmpty) continue;
        final count = stockMap[id] ?? 0;
        if (count <= 0) continue;
        final name = stock['name']?.toString().trim();
        items.add({
          "name": (name == null || name.isEmpty)
              ? _resolveStockNameById(id)
              : name,
          "count": count,
        });
      }
      if (items.isNotEmpty) {
        groups.add({"title": title, "items": items});
      }
    }
    return groups;
  }

  List<Map<String, dynamic>> _buildFallbackGroups(Map<String, int> stockMap) {
    final entries = _buildStockEntries(stockMap);
    final grouped = _groupStockEntries(entries);
    return grouped.entries
        .map((entry) => {"title": entry.key, "items": entry.value})
        .toList();
  }

  int _sumGroupCounts(List<Map<String, dynamic>> groups) {
    int total = 0;
    for (final group in groups) {
      final items = group["items"];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        total += item["count"] as int? ?? 0;
      }
    }
    return total;
  }

  Widget _buildDottedLine(Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dotWidth = 2.0;
        const gap = 3.0;
        final count = (constraints.maxWidth / (dotWidth + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dotWidth,
              height: dotWidth,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockRow({required String name, required int count}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _subMenuStyle.copyWith(fontSize: 14, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _buildDottedLine(Colors.grey.shade300)),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              "$count шт.",
              textAlign: TextAlign.right,
              style: _subMenuStyle.copyWith(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showStockAvailabilitySheet() {
    final stockMap = _resolveCurrentStockMap();
    if (stockMap.isEmpty) return;
    final scrollController = ScrollController();
    bool showScrollHint = false;
    bool checkedOverflow = false;
    bool pulseUp = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.7;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _ensureStoresHierarchy(),
              builder: (context, snapshot) {
                final hierarchy = snapshot.data;
                final excludeIds = _extractExcludedStockIds(hierarchy);
                final filteredMap = _filterStockMap(stockMap, excludeIds);
                final hasHierarchy =
                    hierarchy != null && hierarchy['cities'] is List;
                final groups = hasHierarchy
                    ? _buildHierarchyGroups(filteredMap, hierarchy)
                    : _buildFallbackGroups(filteredMap);
                final total = _sumGroupCounts(groups);
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    hierarchy == null;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const SizedBox(height: 6),
                      _buildBottomSheetHandle(),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 36),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "В наличии ",
                                        style: _boldMenuStyle.copyWith(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w100,
                                          color: Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: "$total шт.",
                                        style: _boldMenuStyle.copyWith(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w100,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -8,
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.black54,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            height: 28,
                            width: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        )
                      else if (groups.isEmpty)
                        Text(
                          "Нет данных по наличию",
                          style: _subMenuStyle.copyWith(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        )
                      else
                        Expanded(
                          child: StatefulBuilder(
                            builder: (context, setModalState) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!context.mounted ||
                                    !scrollController.hasClients) {
                                  return;
                                }
                                if (checkedOverflow) return;
                                checkedOverflow = true;
                                final canScroll =
                                    scrollController.position.maxScrollExtent >
                                    0;
                                if (showScrollHint != canScroll) {
                                  setModalState(
                                    () => showScrollHint = canScroll,
                                  );
                                }
                              });
                              return NotificationListener<
                                ScrollUpdateNotification
                              >(
                                onNotification: (notification) {
                                  if (showScrollHint &&
                                      notification.metrics.pixels > 0) {
                                    setModalState(() => showScrollHint = false);
                                  }
                                  return false;
                                },
                                child: Stack(
                                  children: [
                                    ListView(
                                      controller: scrollController,
                                      padding: EdgeInsets.only(
                                        bottom: showScrollHint ? 30 : 0,
                                      ),
                                      children: groups.map((group) {
                                        final title =
                                            group["title"]?.toString() ?? "";
                                        final items =
                                            group["items"] as List? ?? const [];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 7,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: _boldMenuStyle.copyWith(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w100,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              for (final item in items) ...[
                                                _buildStockRow(
                                                  name:
                                                      item["name"]
                                                          ?.toString() ??
                                                      "",
                                                  count:
                                                      item["count"] as int? ??
                                                      0,
                                                ),
                                                const SizedBox(height: 5),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    if (showScrollHint)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: IgnorePointer(
                                          child: Container(
                                            padding: const EdgeInsets.only(
                                              top: 16,
                                              bottom: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.75,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.98,
                                                  ),
                                                ],
                                                stops: const [0.0, 0.55, 1.0],
                                              ),
                                            ),
                                            child:
                                                TweenAnimationBuilder<double>(
                                                  tween: Tween(
                                                    begin: pulseUp ? 0.85 : 1.1,
                                                    end: pulseUp ? 1.1 : 0.85,
                                                  ),
                                                  duration: const Duration(
                                                    milliseconds: 900,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                  onEnd: () {
                                                    if (showScrollHint) {
                                                      setModalState(
                                                        () =>
                                                            pulseUp = !pulseUp,
                                                      );
                                                    }
                                                  },
                                                  builder:
                                                      (context, scale, child) {
                                                        return Transform.scale(
                                                          scale: scale,
                                                          child: child,
                                                        );
                                                      },
                                                  child: const Icon(
                                                    Icons.keyboard_arrow_down,
                                                    size: 28,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      scrollController.dispose();
    });
  }

  Widget _buildStarRow(double rating, {double size = 14}) {
    final int full = rating.floor().clamp(0, 5);
    final bool half = (rating - full) >= 0.5 && full < 5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) {
          return Icon(Icons.star, size: size, color: _starColor);
        }
        if (i == full && half) {
          return Icon(Icons.star_half, size: size, color: _starColor);
        }
        return Icon(Icons.star_border, size: size, color: _starColor);
      }),
    );
  }

  String _formatReviewDate(String raw) {
    if (raw.isEmpty) return "";
    final cleaned = raw.replaceAll("T", " ").split(".").first.trim();
    final parts = cleaned.split(" ");
    return parts.isNotEmpty ? parts.first : cleaned;
  }

  String _formatReviewsCountText(int count) {
    final n = count.abs() % 100;
    final n1 = n % 10;
    if (n > 10 && n < 20) return "$count отзывов";
    if (n1 == 1) return "$count отзыв";
    if (n1 >= 2 && n1 <= 4) return "$count отзыва";
    return "$count отзывов";
  }

  String _formatStarsLabel(int rating) {
    if (rating == 1) return "1 звезда";
    if (rating >= 2 && rating <= 4) return "$rating звезды";
    return "$rating звезд";
  }

  Widget _buildReviewsSummary() {
    final avg = _reviewsAverage;
    final avgText = avg > 0
        ? avg.toStringAsFixed(1).replaceAll('.', ',')
        : "0,0";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStarRow(avg, size: 20),
            const Spacer(),
            Text(
              "$avgText / 5",
              style: _boldMenuStyle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (int rating = 5; rating >= 1; rating--) _buildRatingBarRow(rating),
      ],
    );
  }

  Widget _buildRatingBarRow(int rating) {
    final count = _reviewsByRating[rating] ?? 0;
    final total = _reviewsRatedCount;
    final fraction = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    final label = _formatStarsLabel(rating);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: _subMenuStyle.copyWith(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 18,
            child: Text(
              "$count",
              textAlign: TextAlign.right,
              style: _subMenuStyle.copyWith(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _readReviewImagesFromRaw(
    dynamic raw, {
    bool preferFull = false,
  }) {
    if (raw == null) return const [];
    if (raw is List) {
      final result = <String>[];
      for (final entry in raw) {
        if (entry is String) {
          final url = _normalizeReviewImageUrl(entry);
          if (url.isNotEmpty) result.add(url);
        } else if (entry is Map) {
          final direct = preferFull
              ? (entry['url_full'] ??
                    entry['full_url'] ??
                    entry['original_url'] ??
                    entry['url'] ??
                    entry['image_url'] ??
                    entry['src'] ??
                    entry['path'] ??
                    entry['file'] ??
                    entry['url_thumb'] ??
                    entry['thumb_url'] ??
                    entry['preview_url'])
              : (entry['url_thumb'] ??
                    entry['thumb_url'] ??
                    entry['preview_url'] ??
                    entry['url'] ??
                    entry['image_url'] ??
                    entry['original_url'] ??
                    entry['full_url'] ??
                    entry['src'] ??
                    entry['path'] ??
                    entry['file'] ??
                    entry['url_full']);
          if (direct != null) {
            final url = _normalizeReviewImageUrl(direct.toString());
            if (url.isNotEmpty) result.add(url);
          }
        }
      }
      return result;
    }
    if (raw is String) {
      final url = _normalizeReviewImageUrl(raw);
      return url.isNotEmpty ? [url] : const [];
    }
    return const [];
  }

  List<String> _readReviewImagesFromItem(Map item) {
    return _readReviewImagesFromRaw(item['images']);
  }

  List<String> _readReviewFullImagesFromItem(Map item) {
    final fullRaw = item['imagesFull'] ?? item['images_full'];
    final full = _readReviewImagesFromRaw(fullRaw, preferFull: true);
    if (full.isNotEmpty) return full;
    return _readReviewImagesFromItem(item);
  }

  bool _reviewHasImages(Map item) {
    return _readReviewImagesFromItem(item).isNotEmpty;
  }

  List<String> _collectReviewGalleryImages(
    List<Map<String, dynamic>> items, {
    int limit = 12,
    bool useFull = false,
  }) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final depth = item['depth'] as int? ?? 0;
      if (depth != 0) continue;
      final images = useFull
          ? _readReviewFullImagesFromItem(item)
          : _readReviewImagesFromItem(item);
      for (final url in images) {
        if (seen.add(url)) {
          result.add(url);
          if (result.length >= limit) return result;
        }
      }
    }
    return result;
  }

  Widget _buildReviewImageThumb(String url, {double size = 64}) {
    final width = size * (3 / 4);
    return SizedBox(
      width: width,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: width,
            height: size,
            color: Colors.grey.shade100,
          ),
          errorWidget: (_, __, ___) => Container(
            width: width,
            height: size,
            color: Colors.grey.shade100,
            child: const Icon(
              Icons.broken_image,
              size: 18,
              color: Colors.black26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewImagesRow(
    List<String> images, {
    double size = 64,
    List<String>? fullImages,
  }) {
    if (images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final url = images[index];
          final openImages =
              (fullImages != null && fullImages.length == images.length)
              ? fullImages
              : images;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openReviewGallery(openImages, index),
            child: _buildReviewImageThumb(url, size: size),
          );
        },
      ),
    );
  }

  void _openImageGallery(List<String> images, int initialIndex) {
    if (!mounted || images.isEmpty) return;
    final safeIndex = initialIndex.clamp(0, images.length - 1);
    final galleryPage = _ReviewGalleryPage(
      images: images,
      initialIndex: safeIndex,
    );
    Navigator.of(context).push(
      Platform.isIOS
          ? CupertinoPageRoute<void>(builder: (_) => galleryPage)
          : PageRouteBuilder(
              opaque: true,
              transitionDuration: const Duration(milliseconds: 350),
              reverseTransitionDuration: const Duration(milliseconds: 280),
              pageBuilder: (_, __, ___) => galleryPage,
              transitionsBuilder: (_, animation, __, child) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                );
              },
            ),
    );
  }

  void _openReviewGallery(List<String> images, int initialIndex) {
    _openImageGallery(images, initialIndex);
  }

  Widget _buildMiniToggle({
    required bool value,
    required VoidCallback onTap,
    double width = 34,
    double height = 18,
  }) {
    final radius = height / 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: value ? Colors.black : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: height - 4,
            height: height - 4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius - 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> item) {
    final depth = item['depth'] as int? ?? 0;
    final title = item['title']?.toString() ?? "";
    final text = item['text']?.toString() ?? "";
    final contactId = item['contactId']?.toString() ?? "";
    final authProvider = item['authProvider']?.toString().toLowerCase() ?? "";
    final authorRaw = item['author']?.toString().trim() ?? "";
    final author = authorRaw.isNotEmpty
        ? authorRaw
        : (authProvider == "guest" || contactId.isEmpty)
        ? "Гость"
        : "Покупатель";
    final datetimeRaw = item['datetime']?.toString() ?? "";
    final datetime = _formatReviewDate(datetimeRaw);
    final rating = item['rating'] as double? ?? 0.0;
    final bool isReply = depth > 0;
    final images = _readReviewImagesFromItem(item);
    final imagesFull = _readReviewFullImagesFromItem(item);
    final avatarUrl = _normalizeAvatarUrl(item['avatar']?.toString() ?? "");
    final initials = author.isNotEmpty
        ? author.substring(0, 1).toUpperCase()
        : "Г";
    final avatarRadius = isReply ? 14.0 : 16.0;
    final avatarSize = avatarRadius * 2;
    final bool isSvgAvatar = avatarUrl.toLowerCase().endsWith(".svg");
    Widget avatarFallback() {
      return Container(
        width: avatarSize,
        height: avatarSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Text(
          initials,
          style: _boldSubMenuStyle.copyWith(fontSize: isReply ? 11 : 12),
        ),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: avatarUrl.isEmpty
                  ? CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        initials,
                        style: _boldSubMenuStyle.copyWith(
                          fontSize: isReply ? 11 : 12,
                        ),
                      ),
                    )
                  : (isSvgAvatar
                        ? ClipOval(
                            child: SizedBox(
                              width: avatarSize,
                              height: avatarSize,
                              child: SvgPicture.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                placeholderBuilder: (_) => avatarFallback(),
                              ),
                            ),
                          )
                        : ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl,
                              width: avatarSize,
                              height: avatarSize,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => avatarFallback(),
                              errorWidget: (_, __, ___) => avatarFallback(),
                            ),
                          )),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (author.isNotEmpty || datetime.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            author,
                            style: _boldSubMenuStyle.copyWith(fontSize: 16),
                          ),
                        ),
                        if (datetime.isNotEmpty)
                          Text(
                            datetime,
                            style: _subMenuStyle.copyWith(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  if (rating > 0 && !isReply) ...[
                    const SizedBox(height: 4),
                    _buildStarRow(rating, size: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (title.isNotEmpty && !isReply) ...[
          const SizedBox(height: 6),
          Text("Заголовок", style: _boldSubMenuStyle.copyWith(fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            title,
            style: _subMenuStyle.copyWith(fontSize: 14, color: Colors.black87),
          ),
        ],
        if (text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text("Комментарий", style: _boldSubMenuStyle.copyWith(fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            text,
            style: _subMenuStyle.copyWith(fontSize: 14, color: Colors.black87),
          ),
        ],
        if (images.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildReviewImagesRow(
            images,
            size: isReply ? 60 : 72,
            fullImages: imagesFull,
          ),
        ],
      ],
    );

    if (isReply) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 2,
                margin: const EdgeInsets.only(right: 8),
                color: Colors.grey.shade300,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Padding(padding: const EdgeInsets.only(bottom: 12), child: content);
  }

  bool _matchesReviewFilter(Map<String, dynamic> item) {
    if (_reviewsFilter == "all") return true;
    final rating = item['rating'] as double? ?? 0.0;
    if (rating <= 0) return false;
    if (_reviewsFilter == "high") return rating >= 4;
    if (_reviewsFilter == "low") return rating <= 3;
    return true;
  }

  List<Map<String, dynamic>> _filteredReviews() {
    final result = <Map<String, dynamic>>[];
    bool include = true;
    for (final item in _reviews) {
      final depth = item['depth'] as int? ?? 0;
      if (depth == 0) {
        include =
            _matchesReviewFilter(item) &&
            (!_reviewsOnlyWithPhotos || _reviewHasImages(item));
      }
      if (include) {
        result.add(item);
      }
    }
    return result;
  }

  Widget _buildReviewsFilterControl() {
    final label = _reviewsFilter == "all"
        ? "Все отзывы"
        : _reviewsFilter == "high"
        ? "Высокий рейтинг"
        : "Низкий рейтинг";
    return Row(
      children: [
        PopupMenuButton<String>(
          onSelected: (value) => setState(() => _reviewsFilter = value),
          itemBuilder: (context) => const [
            PopupMenuItem(value: "all", child: Text("Все отзывы")),
            PopupMenuItem(value: "high", child: Text("Высокий рейтинг")),
            PopupMenuItem(value: "low", child: Text("Низкий рейтинг")),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: _subMenuStyle.copyWith(fontSize: 13)),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildMiniToggle(
                value: _reviewsOnlyWithPhotos,
                onTap: () => setState(
                  () => _reviewsOnlyWithPhotos = !_reviewsOnlyWithPhotos,
                ),
                width: 34,
                height: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "Только с фотографиями",
                style: _subMenuStyle.copyWith(
                  fontSize: 13,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    if (_isReviewsLoading) {
      return Text(
        "Отзывы загружаются...",
        style: _subMenuStyle.copyWith(fontSize: 13, color: Colors.black54),
      );
    }
    if (_reviews.isEmpty) {
      return Text(
        "Отзывов нет",
        style: _subMenuStyle.copyWith(fontSize: 13, color: Colors.black54),
      );
    }
    final filtered = _filteredReviews();
    final galleryImages = _collectReviewGalleryImages(filtered);
    final galleryFullImages = _collectReviewGalleryImages(
      filtered,
      useFull: true,
    );
    final reviewsLabel = _formatReviewsCountText(_reviewsCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReviewsSummary(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _openReviewsForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text("Написать отзыв"),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text("Отзывы", style: _boldMenuStyle.copyWith(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              reviewsLabel,
              style: _subMenuStyle.copyWith(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildReviewsFilterControl(),
        const SizedBox(height: 12),
        if (galleryImages.isNotEmpty) ...[
          Text(
            "Фотографии покупателей",
            style: _menuStyle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          _buildReviewImagesRow(
            galleryImages,
            size: 72,
            fullImages: galleryFullImages,
          ),
          const SizedBox(height: 16),
        ],
        Divider(
          height: 1,
          thickness: 1,
          indent: 12,
          endIndent: 12,
          color: Colors.grey.shade200,
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Text(
            "Нет отзывов по фильтру",
            style: _subMenuStyle.copyWith(fontSize: 13, color: Colors.black54),
          )
        else
          for (final item in filtered) _buildReviewItem(item),
      ],
    );
  }

  Widget _buildDetailTabContent() {
    if (_detailTabIndex == 0) {
      return _buildDescriptionSection();
    }
    if (_detailTabIndex == 1) {
      final rows = _resolveFeatureRows(_currentProduct);
      if (rows.isEmpty) {
        return Text(
          _isProductInfoLoading
              ? "Характеристики загружаются..."
              : "Характеристики отсутствуют",
          style: _subMenuStyle.copyWith(fontSize: 13, color: Colors.black54),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            _buildFeatureRow(row["label"] ?? "", row["value"] ?? ""),
        ],
      );
    }
    return _buildReviewsSection();
  }

  Widget _buildDetailCartButton() {
    final isInCart =
        widget.cartListenable != null && widget.isInCartResolver != null
        ? widget.isInCartResolver!(_currentProductId)
        : false;
    return ElevatedButton(
      onPressed: widget.onAddToCart,
      style: ElevatedButton.styleFrom(
        backgroundColor: isInCart ? Colors.white : Colors.black,
        foregroundColor: isInCart ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isInCart
              ? const BorderSide(color: Colors.black, width: 1)
              : BorderSide.none,
        ),
        elevation: 0,
      ),
      child: Text(
        isInCart ? "В корзине" : "В корзину",
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildContent() {
    final product = _currentProduct;
    final productId = _currentProductId;
    final name = product['name']?.toString() ?? "";
    final price = product['price']?.toString() ?? "";
    final oldPrice = product['old_price']?.toString() ?? "";
    final article = widget.resolveArticle(product);
    final stockCount = widget.resolveStockCount(product);
    final discount = product['discount']?.toString() ?? "";
    final benefit = product['benefit']?.toString() ?? "";
    final images = _images.isNotEmpty
        ? _images
        : (_previewImages.isNotEmpty
              ? _previewImages
              : _normalizeImages(
                  widget.resolveImages(product),
                  toLarge: false,
                ));

    final bool isNew =
        product['is_new'] == true || product['isNew'] == true || widget.isNew;
    final List<Widget> badges = [];
    if (isNew) {
      badges.add(
        _buildBadge(
          "НОВИНКА",
          const Color(0xFF42BA96),
          textColor: Colors.white,
        ),
      );
    }
    if (discount.isNotEmpty) {
      badges.add(_buildBadge(discount, const Color(0xFFFAD776)));
    }
    if (benefit.isNotEmpty) {
      badges.add(_buildBadge(benefit, const Color(0xFFFAD776)));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Stack(
                          children: [
                            if (images.isEmpty)
                              Container(color: Colors.grey.shade100)
                            else
                              PageView.builder(
                                controller: _pageController,
                                itemCount: images.length,
                                onPageChanged: (index) {
                                  setState(() => _currentImage = index);
                                  _precacheAround(index);
                                },
                                itemBuilder: (context, index) {
                                  final url = images[index];
                                  final String previewUrl =
                                      _previewImages.isNotEmpty
                                      ? _previewImages[index.clamp(
                                          0,
                                          _previewImages.length - 1,
                                        )]
                                      : "";
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        _openImageGallery(images, index),
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      fadeInDuration: Duration.zero,
                                      fadeOutDuration: Duration.zero,
                                      useOldImageOnUrlChange: true,
                                      placeholder: (context, _) {
                                        if (previewUrl.isNotEmpty &&
                                            previewUrl != url) {
                                          return Image(
                                            image: CachedNetworkImageProvider(
                                              previewUrl,
                                            ),
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        return Container(
                                          color: Colors.grey.shade100,
                                        );
                                      },
                                      errorWidget: (context, _, __) =>
                                          const Icon(Icons.broken_image),
                                    ),
                                  );
                                },
                              ),
                            Positioned(
                              top: 4,
                              left: 4,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Colors.white,
                                  size: 26,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.ios_share,
                                  color: Colors.white,
                                  size: 26,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                onPressed: widget.onShare,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 10,
                              child: _buildIndicator(images.length),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            left: BorderSide(color: Colors.grey.shade200),
                            right: BorderSide(color: Colors.grey.shade200),
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: badges,
                                  ),
                                ),
                                if (_favoriteListenable == null)
                                  _buildActionIcon(
                                    icon: Icons.favorite_border,
                                    active: false,
                                    onTap: () =>
                                        widget.onFavoriteTap(_currentProduct),
                                  )
                                else
                                  ValueListenableBuilder<int>(
                                    valueListenable: _favoriteListenable!,
                                    builder: (context, _, __) {
                                      final active =
                                          widget.isFavoriteResolver?.call(
                                            productId,
                                          ) ??
                                          false;
                                      return _buildActionIcon(
                                        icon: Icons.favorite_border,
                                        active: active,
                                        onTap: () => widget.onFavoriteTap(
                                          _currentProduct,
                                        ),
                                      );
                                    },
                                  ),
                                const SizedBox(width: 8),
                                if (_compareListenable == null)
                                  _buildActionIcon(
                                    icon: Icons.bar_chart_outlined,
                                    active: false,
                                    onTap: () =>
                                        widget.onCompareTap(_currentProduct),
                                  )
                                else
                                  ValueListenableBuilder<int>(
                                    valueListenable: _compareListenable!,
                                    builder: (context, _, __) {
                                      final active =
                                          widget.isCompareResolver?.call(
                                            productId,
                                          ) ??
                                          false;
                                      return _buildActionIcon(
                                        icon: Icons.bar_chart_outlined,
                                        active: active,
                                        onTap: () => widget.onCompareTap(
                                          _currentProduct,
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        price,
                                        style: _cardPriceStyle.copyWith(
                                          fontSize: 20,
                                        ),
                                      ),
                                      if (oldPrice.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          oldPrice,
                                          style: _cardOldPriceStyle.copyWith(
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (stockCount > 0)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _showStockAvailabilitySheet,
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          const WidgetSpan(
                                            alignment:
                                                PlaceholderAlignment.middle,
                                            child: Icon(
                                              Icons.add,
                                              size: 16,
                                              color: Colors.black38,
                                            ),
                                          ),
                                          const WidgetSpan(
                                            child: SizedBox(width: 4),
                                          ),
                                          TextSpan(
                                            text: "В наличии ",
                                            style: _subMenuStyle.copyWith(
                                              fontSize: 13,
                                              color: Colors.black,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "$stockCount шт.",
                                            style: _subMenuStyle.copyWith(
                                              fontSize: 13,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildUpsellSection(),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: _boldMenuStyle.copyWith(
                          fontSize: 18,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              "Артикул: ${article.isEmpty ? "-" : article}",
                              style: _subMenuStyle.copyWith(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openReviewsForm,
                            child: _reviewsCount > 0
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _buildStarRow(_reviewsAverage, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${_reviewsAverage.toStringAsFixed(1).replaceAll('.', ',')} / 5 ($_reviewsCount)",
                                        style: _subMenuStyle.copyWith(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.star_border,
                                        size: 16,
                                        color: Colors.black38,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Добавить отзыв",
                                        style: _subMenuStyle.copyWith(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 12,
                        endIndent: 12,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 10),
                      _buildDetailTabs(),
                      const SizedBox(height: 12),
                      _buildDetailTabContent(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: _buildDetailCartButton(),
                ),
              ),
              if (widget.bottomBar != null) widget.bottomBar!,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[];
    if (_galleryListenable != null) {
      listenables.add(_galleryListenable!);
    }
    if (widget.cartListenable != null) {
      listenables.add(widget.cartListenable!);
    }
    final Widget content = listenables.isEmpty
        ? _buildContent()
        : AnimatedBuilder(
            animation: Listenable.merge(listenables),
            builder: (context, _) => _buildContent(),
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.white,
        systemNavigationBarContrastEnforced: false,
      ),
      child: content,
    );
  }
}

class _SlideInOutCard extends StatefulWidget {
  final String id;
  final Set<String> animatedIds;
  final Widget child;
  const _SlideInOutCard({
    required this.id,
    required this.animatedIds,
    required this.child,
  });

  @override
  State<_SlideInOutCard> createState() => _SlideInOutCardState();
}

class _SlideInOutCardState extends State<_SlideInOutCard> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _applyEntryAnimation(initial: true);
  }

  @override
  void didUpdateWidget(covariant _SlideInOutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _applyEntryAnimation(initial: false);
    }
  }

  void _applyEntryAnimation({required bool initial}) {
    if (widget.id.isEmpty) {
      if (!initial && !_visible) setState(() => _visible = true);
      return;
    }
    final shouldAnimate = !widget.animatedIds.contains(widget.id);
    if (shouldAnimate) {
      widget.animatedIds.add(widget.id);
      if (initial) {
        _visible = false;
      } else {
        setState(() => _visible = false);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _visible = true);
      });
    } else if (!initial && !_visible) {
      setState(() => _visible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _visible
          ? (widget.id.isNotEmpty
                ? KeyedSubtree(key: ValueKey(widget.id), child: widget.child)
                : widget.child)
          : const SizedBox.shrink(),
    );
  }
}

class _ReviewFormPage extends StatefulWidget {
  final String productId;
  final String productName;
  final Future<bool> Function({
    required String productId,
    required String name,
    required String title,
    required String text,
    required int rate,
    required List<XFile> photos,
  })?
  submitReview;
  final VoidCallback? onSubmitted;
  const _ReviewFormPage({
    required this.productId,
    required this.productName,
    this.submitReview,
    this.onSubmitted,
  });

  @override
  State<_ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends State<_ReviewFormPage> {
  static const MethodChannel _nativeImagePickerChannel = MethodChannel(
    'native_image_picker',
  );
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  static const int _maxReviewPhotos = 10;
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedPhotos = [];
  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _requestPhotoPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    if (Platform.isAndroid) {
      final photos = await Permission.photos.request();
      final storage = await Permission.storage.request();
      final camera = await Permission.camera.request();
      return photos.isGranted || storage.isGranted || camera.isGranted;
    }
    return true;
  }

  Future<void> _pickFromGallery() async {
    final remaining = _maxReviewPhotos - _selectedPhotos.length;
    if (remaining <= 0) {
      _showMessage("Можно добавить не больше $_maxReviewPhotos фото");
      return;
    }
    final allowed = await _requestPhotoPermission();
    if (!allowed) {
      _showMessage("Нужно разрешение на доступ к фото");
      return;
    }
    if (Platform.isAndroid) {
      try {
        final result = await _nativeImagePickerChannel
            .invokeMethod<List<dynamic>>('pickImages');
        if (!mounted) return;
        final paths = result?.whereType<String>().toList() ?? const <String>[];
        if (paths.isEmpty) return;
        final toAdd = paths
            .take(remaining)
            .map((p) => XFile(p))
            .toList(growable: false);
        setState(() => _selectedPhotos.addAll(toAdd));
        if (paths.length > remaining) {
          _showMessage("Можно добавить не больше $_maxReviewPhotos фото");
        }
      } catch (e) {
        if (mounted) _showMessage("Не удалось открыть выбор фото");
      }
      return;
    }
    final picked = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (!mounted) return;
    if (picked.isEmpty) return;
    final toAdd = picked.take(remaining).toList(growable: false);
    setState(() => _selectedPhotos.addAll(toAdd));
    if (picked.length > remaining) {
      _showMessage("Можно добавить не больше $_maxReviewPhotos фото");
    }
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _selectedPhotos.length) return;
    setState(() => _selectedPhotos.removeAt(index));
  }

  Widget _buildPhotoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickFromGallery,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_a_photo_outlined, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Добавить фотографии (до $_maxReviewPhotos шт.)",
                  style: _subMenuStyle.copyWith(fontSize: 13),
                ),
              ),
              Text(
                "${_selectedPhotos.length}/$_maxReviewPhotos",
                style: _subMenuStyle.copyWith(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
        if (_selectedPhotos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedPhotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final photo = _selectedPhotos[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(photo.path),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.close, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final rawName = _nameController.text.trim();
    final name = rawName.isEmpty ? "Александр" : rawName;
    final title = _titleController.text.trim();
    final text = _textController.text.trim();
    if (_rating <= 0) {
      _showMessage("Поставьте оценку");
      return;
    }
    if (text.isEmpty) {
      _showMessage("Введите комментарий");
      return;
    }
    if (widget.submitReview == null) {
      _showMessage("Отправка отзывов недоступна");
      return;
    }
    setState(() => _isSubmitting = true);
    final ok = await widget.submitReview!(
      productId: widget.productId,
      name: name,
      title: title,
      text: text,
      rate: _rating,
      photos: List<XFile>.from(_selectedPhotos),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      widget.onSubmitted?.call();
      _showMessage("Отзыв отправлен");
      Navigator.pop(context);
    } else {
      _showMessage("Не удалось отправить отзыв");
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _subMenuStyle),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black54),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow() {
    return Row(
      children: List.generate(5, (index) {
        final value = index + 1;
        final isActive = value <= _rating;
        return IconButton(
          onPressed: () => setState(() => _rating = value),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(
            isActive ? Icons.star : Icons.star_border,
            color: isActive ? _starColor : Colors.black38,
            size: 28,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.black,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  "Отзывы",
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.productName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    widget.productName,
                    style: _boldMenuStyle.copyWith(fontSize: 16),
                  ),
                ),
              _buildField(
                label: "Ваше имя",
                controller: _nameController,
                hint: "Имя",
              ),
              const SizedBox(height: 16),
              _buildField(
                label: "Заголовок",
                controller: _titleController,
                hint: "Например: Отличный товар",
              ),
              const SizedBox(height: 16),
              const Text("Оцените покупку", style: _subMenuStyle),
              const SizedBox(height: 8),
              _buildRatingRow(),
              const SizedBox(height: 16),
              _buildField(
                label: "Комментарий к отзыву",
                controller: _textController,
                hint: "Поделитесь впечатлениями о товаре",
                maxLines: 5,
              ),
              const SizedBox(height: 18),
              _buildPhotoPicker(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Отправить отзыв"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewGalleryPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _ReviewGalleryPage({required this.images, required this.initialIndex});

  @override
  State<_ReviewGalleryPage> createState() => _ReviewGalleryPageState();
}

class _ReviewGalleryPageState extends State<_ReviewGalleryPage> {
  late final PageController _controller;
  final ScrollController _thumbController = ScrollController();
  int _currentIndex = 0;
  int _thumbActiveIndex = 0;
  bool _isZoomed = false;
  bool _systemBarsHidden = false;
  double _bottomSafeInset = 0;
  int _activePointers = 0;
  int? _dismissPointerId;
  Offset? _dismissStartPosition;
  double _dismissDragOffset = 0.0;
  bool _isDismissDragging = false;
  static const double _dismissMinDrag = 120.0;
  static const double _dismissMaxFadeDrag = 320.0;
  final Map<String, Size> _imageSizeCache = {};
  final Map<String, Future<Size?>> _imageSizeInFlight = {};
  bool _isThumbInteracting = false;
  final Map<int, PhotoViewController> _photoControllers = {};
  final Map<int, StreamSubscription<PhotoViewControllerValue>> _photoSubs = {};
  final Map<int, double> _baseScales = {};
  double _thumbItemWidth = 0;
  double _thumbItemExtent = 0;
  double _thumbViewportWidth = 0;
  static const double _thumbVisibleCount = 5.4;
  static const double _thumbSpacing = 4;
  static const double _thumbSidePadding = 8;
  static const double _galleryPhotoGap = 5;
  static const SystemUiOverlayStyle _galleryUiStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );
  static const SystemUiOverlayStyle _defaultUiStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarDividerColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  void initState() {
    super.initState();
    final safeIndex = widget.images.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.images.length - 1);
    _currentIndex = safeIndex;
    _thumbActiveIndex = safeIndex;
    _controller = PageController(initialPage: safeIndex);
    SystemChrome.setSystemUIOverlayStyle(_galleryUiStyle);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _systemBarsHidden = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollThumbsToIndex(safeIndex);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _thumbController.dispose();
    for (final sub in _photoSubs.values) {
      sub.cancel();
    }
    for (final controller in _photoControllers.values) {
      controller.dispose();
    }
    SystemChrome.setSystemUIOverlayStyle(_defaultUiStyle);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  PhotoViewController _photoControllerFor(int index) {
    return _photoControllers.putIfAbsent(index, () {
      final controller = PhotoViewController();
      _photoSubs[index] = controller.outputStateStream.listen((value) {
        final scale = value.scale ?? 1.0;
        _baseScales.putIfAbsent(index, () => scale);
        if (!mounted || index != _currentIndex) return;
        final base = _baseScales[index] ?? scale;
        final zoomed = scale > base + 0.01;
        if (zoomed == _isZoomed) return;
        _setSystemBarsHidden(zoomed);
        setState(() => _isZoomed = zoomed);
      });
      return controller;
    });
  }

  void _updateThumbMetrics(double viewportWidth) {
    if (viewportWidth <= 0) return;
    final usableWidth = viewportWidth - (_thumbSidePadding * 2);
    final itemWidth =
        (usableWidth - _thumbSpacing * (_thumbVisibleCount - 1)) /
        _thumbVisibleCount;
    _thumbViewportWidth = viewportWidth;
    _thumbItemWidth = itemWidth;
    _thumbItemExtent = itemWidth + _thumbSpacing;
  }

  void _scrollThumbsToIndex(int index) {
    if (!_thumbController.hasClients || _thumbItemExtent <= 0) return;
    final halfViewport = _thumbViewportWidth / 2;
    final targetCenter = index * _thumbItemExtent + (_thumbItemWidth / 2);
    final target = targetCenter - halfViewport + _thumbSidePadding;
    final maxOffset = _thumbController.position.maxScrollExtent;
    final clamped = target.clamp(0.0, maxOffset);
    _thumbController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  void _scheduleThumbActiveUpdate(int index) {
    if (_thumbActiveIndex == index) return;
    setState(() => _thumbActiveIndex = index);
  }

  void _setThumbInteracting(bool value) {
    if (_isThumbInteracting == value) return;
    setState(() => _isThumbInteracting = value);
  }

  void _onGalleryPointerDown(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers == 1 && !_isZoomed) {
      _dismissPointerId = event.pointer;
      _dismissStartPosition = event.position;
      _isDismissDragging = false;
    }
    if (_activePointers >= 2) {
      _setSystemBarsHidden(true);
    }
  }

  void _onGalleryPointerMove(PointerMoveEvent event) {
    if (_dismissPointerId != event.pointer ||
        _dismissStartPosition == null ||
        _activePointers != 1 ||
        _isZoomed ||
        _isThumbInteracting) {
      return;
    }
    final delta = event.position - _dismissStartPosition!;
    final dy = delta.dy;
    if (dy <= 0) return;

    final dxAbs = delta.dx.abs();
    final dyAbs = dy.abs();
    if (!_isDismissDragging) {
      if (dyAbs < 10) return;
      if (dyAbs < dxAbs * 1.2) return;
      _isDismissDragging = true;
      _setSystemBarsHidden(true);
    }

    final nextOffset = dy.clamp(0.0, 520.0).toDouble();
    if (nextOffset == _dismissDragOffset) return;
    setState(() => _dismissDragOffset = nextOffset);
  }

  void _onGalleryPointerEnd(PointerEvent event) {
    if (_dismissPointerId == event.pointer) {
      final drag = _dismissDragOffset;
      _dismissPointerId = null;
      _dismissStartPosition = null;

      if (_isDismissDragging && drag >= _dismissMinDrag) {
        Navigator.pop(context);
        return;
      }
      _isDismissDragging = false;
      if (_dismissDragOffset != 0.0) {
        setState(() => _dismissDragOffset = 0.0);
      }
    }
    if (_activePointers > 0) _activePointers--;
    if (_activePointers == 0 && !_isZoomed) {
      _setSystemBarsHidden(false);
    }
  }

  PhotoViewScaleState _galleryScaleStateCycle(PhotoViewScaleState actual) {
    // Disable double-tap scale cycling entirely.
    return actual;
  }

  void _setSystemBarsHidden(bool hidden) {
    if (_systemBarsHidden == hidden) return;
    _systemBarsHidden = hidden;
    SystemChrome.setEnabledSystemUIMode(
      hidden ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    SystemChrome.setSystemUIOverlayStyle(_galleryUiStyle);
  }

  void _ensureImageSize(String url) {
    if (_imageSizeCache.containsKey(url) ||
        _imageSizeInFlight.containsKey(url)) {
      return;
    }
    final provider = CachedNetworkImageProvider(url);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    final future = Completer<Size?>();
    _imageSizeInFlight[url] = future.future;
    listener = ImageStreamListener(
      (info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        _imageSizeCache[url] = size;
        _imageSizeInFlight.remove(url);
        stream.removeListener(listener);
        if (mounted) {
          setState(() {});
        }
        future.complete(size);
      },
      onError: (_, __) {
        _imageSizeInFlight.remove(url);
        stream.removeListener(listener);
        future.complete(null);
      },
    );
    stream.addListener(listener);
  }

  Widget _buildThumbnail(
    String url,
    int index, {
    required double width,
    required double height,
  }) {
    final isActive = index == _thumbActiveIndex;
    final borderColor = Color.lerp(
      Colors.white24,
      Colors.white,
      isActive ? 1.0 : 0.0,
    )!;
    final borderWidth = isActive ? 2.0 : 1.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_currentIndex == index) return;
        _setThumbInteracting(false);
        _controller.jumpToPage(index);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollThumbsToIndex(index);
        });
      },
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey.shade900,
              ),
              errorWidget: (_, __, ___) => Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey.shade900,
                child: const Icon(
                  Icons.broken_image,
                  size: 18,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    final screenWidth = MediaQuery.of(context).size.width;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    if (safeBottom > 0 && safeBottom != _bottomSafeInset) {
      _bottomSafeInset = safeBottom;
    }
    final bottomInset = _bottomSafeInset;
    _updateThumbMetrics(screenWidth);
    final double thumbHeight = _thumbItemWidth <= 0
        ? 84.0
        : (_thumbItemWidth * (4.0 / 3.0));
    final double thumbWidth = _thumbItemWidth <= 0
        ? (thumbHeight * (3.0 / 4.0))
        : _thumbItemWidth;
    final double thumbBarHeight = total > 1 ? (thumbHeight + 16.0) : 0.0;
    final double galleryBottom = _isZoomed ? 0.0 : thumbBarHeight;
    final double viewHeight =
        (MediaQuery.of(context).size.height - galleryBottom).clamp(
          1.0,
          double.infinity,
        );
    final double galleryWidth = (screenWidth - _galleryPhotoGap).clamp(
      1.0,
      double.infinity,
    );
    final Size viewSize = Size(galleryWidth, viewHeight);
    final gallery = PhotoViewGallery.builder(
      pageController: _controller,
      itemCount: total,
      onPageChanged: (index) {
        final controller = _photoControllers[index];
        final scale = controller?.value.scale ?? 1.0;
        final base = _baseScales[index] ?? scale;
        final zoomed = scale > base + 0.01;
        _setSystemBarsHidden(zoomed);
        setState(() {
          _currentIndex = index;
          _isZoomed = zoomed;
        });
        _scheduleThumbActiveUpdate(index);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollThumbsToIndex(index);
        });
      },
      scaleStateChangedCallback: (state) {
        final zoomed = state != PhotoViewScaleState.initial;
        _setSystemBarsHidden(zoomed);
        if (zoomed != _isZoomed) {
          setState(() => _isZoomed = zoomed);
        }
      },
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      customSize: viewSize,
      scrollPhysics: (_isThumbInteracting || _isZoomed)
          ? const NeverScrollableScrollPhysics()
          : const _SlowPageScrollPhysics(),
      pageSnapping: true,
      builder: (context, index) {
        final url = widget.images[index];
        final cachedSize = _imageSizeCache[url];
        if (cachedSize == null) {
          _ensureImageSize(url);
        }
        final effectiveSize = cachedSize ?? viewSize;
        return PhotoViewGalleryPageOptions.customChild(
          controller: _photoControllerFor(index),
          childSize: effectiveSize,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3.0,
          initialScale: PhotoViewComputedScale.contained,
          scaleStateCycle: _galleryScaleStateCycle,
          gestureDetectorBehavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: effectiveSize.width,
            height: effectiveSize.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 150),
                fadeOutDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white70,
                  size: 32,
                ),
              ),
            ),
          ),
        );
      },
      loadingBuilder: (context, event) {
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );

    final dragOffset = _dismissDragOffset;
    final bgOpacity = (1.0 - (dragOffset / _dismissMaxFadeDrag).clamp(0.0, 0.5))
        .toDouble();
    final contentTransformDuration = _isDismissDragging
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _galleryUiStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: bgOpacity),
              ),
            ),
            AnimatedContainer(
              duration: contentTransformDuration,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, dragOffset, 0),
              child: Stack(
                children: [
                  if (total > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        ignoring: _isZoomed,
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) => _setThumbInteracting(true),
                          onPointerUp: (_) => _setThumbInteracting(false),
                          onPointerCancel: (_) => _setThumbInteracting(false),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                            padding: EdgeInsets.fromLTRB(
                              _thumbSidePadding,
                              8,
                              _thumbSidePadding,
                              8 + bottomInset,
                            ),
                            child: SizedBox(
                              height: thumbHeight,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                controller: _thumbController,
                                physics: const BouncingScrollPhysics(),
                                itemCount: total,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: _thumbSpacing),
                                itemBuilder: (context, index) {
                                  final url = widget.images[index];
                                  return _buildThumbnail(
                                    url,
                                    index,
                                    width: thumbWidth,
                                    height: thumbHeight,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: galleryBottom,
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _onGalleryPointerDown,
                      onPointerMove: _onGalleryPointerMove,
                      onPointerUp: _onGalleryPointerEnd,
                      onPointerCancel: _onGalleryPointerEnd,
                      child: PhotoViewGestureDetectorScope(
                        axis: Axis.horizontal,
                        child: gallery,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlowPageScrollPhysics extends PageScrollPhysics {
  const _SlowPageScrollPhysics({super.parent});

  @override
  _SlowPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SlowPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 1.0, stiffness: 320, damping: 32);
}

class NativeProductCard extends StatefulWidget {
  final dynamic product;
  final VoidCallback onTap;
  final bool isNew;
  final bool isHorizontal;
  final ValueListenable<int>? galleryListenable;
  final ValueListenable<bool>? scrollListenable;
  final ValueListenable<Set<String>>? scrollMainImageListenable;
  final ValueListenable<int>? favoriteListenable;
  final bool Function(String id)? isFavoriteResolver;
  final VoidCallback? onFavoriteTap;
  final ValueListenable<int>? compareListenable;
  final bool Function(String id)? isCompareResolver;
  final VoidCallback? onCompareTap;
  final VoidCallback? onAddToCart;
  final ValueListenable<int>? cartListenable;
  final bool Function(String id)? isInCartResolver;
  final bool deferHighRes;
  const NativeProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.isNew = false,
    this.isHorizontal = false,
    this.galleryListenable,
    this.scrollListenable,
    this.scrollMainImageListenable,
    this.deferHighRes = false,
    this.favoriteListenable,
    this.isFavoriteResolver,
    this.onFavoriteTap,
    this.compareListenable,
    this.isCompareResolver,
    this.onCompareTap,
    this.onAddToCart,
    this.cartListenable,
    this.isInCartResolver,
  });

  @override
  State<NativeProductCard> createState() => _NativeProductCardState();
}

class _NativeProductCardState extends State<NativeProductCard>
    with AutomaticKeepAliveClientMixin {
  static const int _deferHighResMs = 460;
  int _currentIdx = 0;
  int _maxGalleryIndex = 2;
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  PageController? _controller;
  bool _wasScrolling = false;
  bool _wasUsingGallery = false;
  bool _preferThumb = false;
  Timer? _deferHighResTimer;
  static const bool _cardDebug = false;
  static const int _loopSeed = 1000;
  static final RegExp _sizeTokenRegex = RegExp(r'\\.0x\\d+\\.');
  static final RegExp _sizeAltRegex = RegExp(r'\\.\\d+x\\d+\\.');
  int _lastLoggedImagesLen = -1;
  bool? _lastLoggedUseGallery;
  String _lastLoggedFirstImage = "";
  int _lastLoopImageCount = 0;
  bool _pendingLoopRecenter = false;

  @override
  bool get wantKeepAlive => widget.isHorizontal;

  @override
  void initState() {
    super.initState();
    _startDeferHighResTimer();
    _resetController();
  }

  void _startDeferHighResTimer() {
    _deferHighResTimer?.cancel();
    if (!widget.deferHighRes) {
      _preferThumb = false;
      return;
    }
    _preferThumb = true;
    _deferHighResTimer = Timer(
      const Duration(milliseconds: _deferHighResMs),
      () {
        if (!mounted) return;
        if (_preferThumb) {
          setState(() => _preferThumb = false);
        }
      },
    );
  }

  void _resetController({int initialPage = 0}) {
    _setCurrentIndex(0);
    _controller?.dispose();
    _controller = PageController(initialPage: initialPage, keepPage: false);
    // Дополнительная страховка: сброс через один фрейм
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller != null && _controller!.hasClients) {
        _controller!.jumpToPage(initialPage);
      }
    });
  }

  bool _isInBuildPhase() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    return phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
  }

  void _setCurrentIndex(int value) {
    if (_currentIdx == value && _currentIndexNotifier.value == value) return;
    _currentIdx = value;
    void applyValue() {
      if (_currentIndexNotifier.value != value) {
        _currentIndexNotifier.value = value;
      }
    }

    if (_isInBuildPhase()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        applyValue();
      });
      return;
    }
    applyValue();
  }

  void _cardLog(String message) {
    if (!_cardDebug || !kDebugMode) return;
    debugPrint("[GalleryMark] $message");
  }

  String _toThumbUrl(String url) {
    if (url.isEmpty) return url;
    if (_sizeTokenRegex.hasMatch(url)) {
      return url.replaceAll(_sizeTokenRegex, '.0x200.');
    }
    if (_sizeAltRegex.hasMatch(url)) {
      return url.replaceAll(_sizeAltRegex, '.0x200.');
    }
    return url;
  }

  String _toLargeUrl(String url) {
    if (url.isEmpty) return url;
    if (_sizeTokenRegex.hasMatch(url)) {
      return url.replaceAll(_sizeTokenRegex, '.0x700.');
    }
    if (_sizeAltRegex.hasMatch(url)) {
      return url.replaceAll(_sizeAltRegex, '.0x700.');
    }
    return url;
  }

  int _loopInitialPage(int imageCount, {int currentIndex = 0}) {
    if (imageCount <= 1) return 0;
    final int safeIndex = currentIndex.clamp(0, imageCount - 1);
    return imageCount * _loopSeed + safeIndex;
  }

  int _loopPageToImageIndex(int pageIndex, int imageCount) {
    if (imageCount <= 1) return 0;
    return pageIndex % imageCount;
  }

  void _scheduleLoopRecenter(int imageCount) {
    if (imageCount <= 1) return;
    if (_pendingLoopRecenter) return;
    _pendingLoopRecenter = true;
    final int targetIdx = _currentIdx.clamp(0, imageCount - 1);
    _setCurrentIndex(targetIdx);
    final int targetPage = _loopInitialPage(
      imageCount,
      currentIndex: targetIdx,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingLoopRecenter = false;
      if (!mounted || _controller == null || !_controller!.hasClients) return;
      final double? page = _controller!.page;
      final int currentPage = page == null
          ? _controller!.initialPage
          : page.round();
      if (currentPage != targetPage) {
        _controller!.jumpToPage(targetPage);
      }
    });
  }

  void _handleLoopPageChanged(int pageIndex, int imageCount) {
    if (!mounted || imageCount <= 1) return;
    final int actualIndex = _loopPageToImageIndex(pageIndex, imageCount);
    _setCurrentIndex(actualIndex);
    final int nextMax = (actualIndex + 1).clamp(0, imageCount - 1);
    if (nextMax > _maxGalleryIndex) {
      setState(() {
        _maxGalleryIndex = nextMax;
      });
    }
  }

  @override
  void didUpdateWidget(NativeProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deferHighRes != widget.deferHighRes) {
      _startDeferHighResTimer();
    }
    // Если ID товара изменился ИЛИ количество картинок изменилось (подгрузилась галерея)
    // мы должны убедиться, что всё еще показываем первую картинку
    List<String> oldImages = List<String>.from(
      oldWidget.product['images'] ?? [],
    );
    List<String> newImages = List<String>.from(widget.product['images'] ?? []);

    // Проверяем изменение ID, длины или содержимого списка изображений
    bool idChanged = oldWidget.product['id'] != widget.product['id'];
    bool contentChanged =
        oldImages.isNotEmpty &&
        newImages.isNotEmpty &&
        oldImages[0] != newImages[0];

    if (idChanged || contentChanged) {
      final oldFirst = oldImages.isNotEmpty ? oldImages.first : "";
      final newFirst = newImages.isNotEmpty ? newImages.first : "";
      _cardLog(
        "RESET id=${widget.product['id']} reason="
        "${idChanged ? 'id' : ''}${contentChanged ? ' first' : ''} "
        "oldLen=${oldImages.length} newLen=${newImages.length} "
        "oldFirst=$oldFirst newFirst=$newFirst",
      );
      _maxGalleryIndex = 2;
      _resetController();
    }
  }

  void _ensureControllerForGallery(
    bool shouldHaveController, {
    int initialPage = 0,
  }) {
    if (!shouldHaveController) return;
    if (_controller == null) {
      _resetController(initialPage: initialPage);
    }
  }

  @override
  void dispose() {
    _deferHighResTimer?.cancel();
    _controller?.dispose();
    _currentIndexNotifier.dispose();
    super.dispose();
  }

  Widget _buildCard(BuildContext context, {required bool isScrolling}) {
    final p = widget.product;
    final String productId = p['id']?.toString() ?? "";
    final bool isNewProduct = widget.isNew;
    List<String> images = List<String>.from(p['images'] ?? []);
    if (images.isEmpty && p['image'] != null) images = [p['image']];
    String mainImage = images.isNotEmpty ? images.first : "";
    List<String> gallery = List<String>.from(p['gallery'] ?? []);
    if (gallery.isEmpty && images.length > 1) {
      gallery = images.sublist(1);
    }
    if (mainImage.isEmpty && gallery.isNotEmpty) {
      mainImage = gallery.first;
    }
    final List<String> displayImages = [];
    if (mainImage.isNotEmpty) displayImages.add(mainImage);
    for (final url in gallery) {
      if (url.isEmpty || url == mainImage) continue;
      displayImages.add(url);
      if (displayImages.length >= 5) break;
    }
    final bool hasGallery = displayImages.length > 1;
    final Set<String> allowedIds =
        widget.scrollMainImageListenable?.value ?? const <String>{};
    final bool allowGallery = widget.scrollMainImageListenable == null
        ? true
        : (productId.isNotEmpty && allowedIds.contains(productId));
    final bool allowHighResMain = widget.scrollMainImageListenable == null
        ? true
        : (productId.isNotEmpty && allowedIds.contains(productId));
    final bool useThumbForMain =
        (widget.deferHighRes && (_preferThumb || isScrolling)) ||
        !allowHighResMain;
    final bool useGallery =
        hasGallery &&
        !isScrolling &&
        allowGallery &&
        !(widget.deferHighRes && _preferThumb);
    if (_lastLoopImageCount != displayImages.length) {
      _lastLoopImageCount = displayImages.length;
      if (useGallery && displayImages.length > 1) {
        _scheduleLoopRecenter(displayImages.length);
      }
    }
    final String mainImageFull = widget.deferHighRes
        ? _toLargeUrl(mainImage)
        : mainImage;
    final String mainImageThumb = widget.deferHighRes
        ? mainImage
        : _toThumbUrl(mainImage);
    final bool showThumbPlaceholder =
        mainImageThumb.isNotEmpty && mainImageThumb != mainImageFull;
    final String mainImageToRender =
        (useThumbForMain && mainImageThumb.isNotEmpty)
        ? mainImageThumb
        : mainImageFull;
    final String mainImageFallback = mainImageThumb.isNotEmpty
        ? mainImageThumb
        : mainImageFull;
    final int maxGalleryIndex = displayImages.isEmpty
        ? 0
        : (isScrolling ? 0 : _maxGalleryIndex).clamp(
            0,
            displayImages.length - 1,
          );
    final String firstImageSafe = mainImage;
    if (_lastLoggedImagesLen != displayImages.length ||
        _lastLoggedFirstImage != firstImageSafe) {
      _lastLoggedImagesLen = displayImages.length;
      _lastLoggedFirstImage = firstImageSafe;
      _cardLog(
        "IMAGES id=${p['id']} len=${displayImages.length} first=$firstImageSafe",
      );
    }
    if (_lastLoggedUseGallery == null || _lastLoggedUseGallery != useGallery) {
      _lastLoggedUseGallery = useGallery;
      _cardLog(
        "TOGGLE id=${p['id']} useGallery=$useGallery scrolling=$isScrolling len=${displayImages.length}",
      );
    }
    final bool allowMainImage = mainImage.isNotEmpty;
    if (isScrolling && !_wasScrolling) {
      _cardLog("SCROLL_START id=${p['id']}");
      _setCurrentIndex(0);
    }
    if (_wasScrolling && !isScrolling && hasGallery) {
      _cardLog("SCROLL_STOP id=${p['id']}");
    }
    _wasScrolling = isScrolling;
    if (useGallery && !_wasUsingGallery) {
      _cardLog("GALLERY_ENABLE id=${p['id']}");
      _setCurrentIndex(0);
      _maxGalleryIndex = displayImages.length > 2
          ? 2
          : (displayImages.length > 1 ? 1 : 0);
      final int enableInitialPage = _loopInitialPage(
        displayImages.length,
        currentIndex: 0,
      );
      _resetController(initialPage: enableInitialPage);
    }
    _wasUsingGallery = useGallery;
    final int loopInitialPage = _loopInitialPage(
      displayImages.length,
      currentIndex: _currentIdx,
    );
    _ensureControllerForGallery(
      hasGallery && !isScrolling,
      initialPage: loopInitialPage,
    );

    final double screenWidth = MediaQuery.of(context).size.width;
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final double cardWidth = widget.isHorizontal
        ? (screenWidth - 40) / 1.4
        : (screenWidth - 8 - 8) / 2;
    final double imageHeight = cardWidth * 4 / 3;
    final int cacheWidth = (cardWidth * dpr).round().clamp(1, 2000).toInt();
    final int cacheHeight = (imageHeight * dpr).round().clamp(1, 2000).toInt();
    final int mainCacheWidth = cacheWidth;
    final int mainCacheHeight = cacheHeight;
    return Container(
      width: widget.isHorizontal ? cardWidth : null,
      margin: widget.isHorizontal
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 5)
          : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade200,
        ), // Обводка чуть темнее фона
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: useGallery
                      ? PageView.builder(
                          key: ValueKey("pv_${p['id']}"),
                          controller: _controller!,
                          itemCount: null,
                          onPageChanged: (idx) {
                            _handleLoopPageChanged(idx, displayImages.length);
                          },
                          itemBuilder: (context, i) {
                            final int imageIndex = _loopPageToImageIndex(
                              i,
                              displayImages.length,
                            );
                            final imageUrl = displayImages[imageIndex];
                            final String thumbUrl = _toThumbUrl(imageUrl);
                            final bool showThumb =
                                thumbUrl.isNotEmpty && thumbUrl != imageUrl;
                            final bool allowLoad =
                                imageIndex <= maxGalleryIndex;
                            if (!allowLoad) {
                              return GestureDetector(
                                onTap: widget.onTap,
                                child: mainImageFallback.isNotEmpty
                                    ? Image(
                                        image: ResizeImage(
                                          CachedNetworkImageProvider(
                                            mainImageFallback,
                                          ),
                                          width: cacheWidth,
                                          height: cacheHeight,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : Container(color: Colors.grey.shade50),
                              );
                            }
                            return GestureDetector(
                              onTap: widget.onTap,
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                memCacheHeight: cacheHeight,
                                memCacheWidth: cacheWidth,
                                filterQuality: FilterQuality.low,
                                fadeInDuration: const Duration(
                                  milliseconds: 200,
                                ),
                                fadeOutDuration: const Duration(
                                  milliseconds: 120,
                                ),
                                useOldImageOnUrlChange: true,
                                placeholder: (context, url) {
                                  if (showThumb) {
                                    return Image(
                                      image: CachedNetworkImageProvider(
                                        thumbUrl,
                                      ),
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return Container(color: Colors.grey.shade50);
                                },
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.broken_image),
                              ),
                            );
                          },
                        )
                      : GestureDetector(
                          onTap: widget.onTap,
                          child: (!allowMainImage || mainImage.isEmpty)
                              ? Container(color: Colors.grey.shade50)
                              : CachedNetworkImage(
                                  imageUrl: mainImageToRender,
                                  fit: BoxFit.cover,
                                  memCacheHeight: mainCacheHeight,
                                  memCacheWidth: mainCacheWidth,
                                  filterQuality: FilterQuality.low,
                                  fadeInDuration: const Duration(
                                    milliseconds: 200,
                                  ),
                                  fadeOutDuration: const Duration(
                                    milliseconds: 120,
                                  ),
                                  useOldImageOnUrlChange: true,
                                  placeholder: (context, url) {
                                    if (showThumbPlaceholder) {
                                      return Image(
                                        image: CachedNetworkImageProvider(
                                          mainImageThumb,
                                        ),
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    return Container(
                                      color: Colors.grey.shade50,
                                    );
                                  },
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.broken_image),
                                ),
                        ),
                ),
                // Бейджи (скидка и выгода) - перенес наверх
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 5,
                    children: [
                      if (isNewProduct)
                        Padding(
                          padding: EdgeInsets.only(
                            right:
                                (p['discount'] != null || p['benefit'] != null)
                                ? 6
                                : 0,
                          ),
                          child: _badge(
                            "НОВИНКА",
                            const Color(0xFF42BA96),
                            textColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 3,
                            ),
                            letterSpacing: 1.0,
                            fontFamily: "Roboto",
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                offset: Offset(0, 3.2),
                                blurRadius: 18,
                                spreadRadius: -5.6,
                              ),
                            ],
                          ),
                        ),
                      if (p['discount'] != null)
                        _badge(
                          p['discount'],
                          const Color(0xFFFAD776),
                          textColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          letterSpacing: 1.0,
                          fontFamily: "Roboto",
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              offset: Offset(0, 3.2),
                              blurRadius: 18,
                              spreadRadius: -5.6,
                            ),
                          ],
                        ),
                      if (p['benefit'] != null)
                        _badge(
                          p['benefit'],
                          const Color(0xFFFAD776),
                          textColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          letterSpacing: 1.0,
                          fontFamily: "Roboto",
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              offset: Offset(0, 3.2),
                              blurRadius: 18,
                              spreadRadius: -5.6,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Индикаторы-полоски (ленивые, всегда видимы)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: ValueListenableBuilder<int>(
              valueListenable: _currentIndexNotifier,
              builder: (context, currentIdx, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final bool isActive = useGallery
                        ? index == currentIdx.clamp(0, 4)
                        : (displayImages.isNotEmpty && index == 0);
                    return Container(
                      width: 14,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.black : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.isHorizontal ? 12 : 8,
                6,
                widget.isHorizontal ? 12 : 8,
                15, // отступ снизу
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Цены в один ряд
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(p['price'] ?? "", style: _cardPriceStyle),
                      if (p['old_price'] != null) ...[
                        const SizedBox(width: 6),
                        Text(p['old_price'], style: _cardOldPriceStyle),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Название товара (полное)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTap,
                    child: Text(
                      p['name'] ?? "",
                      style: _cardNameStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 15), // Отступ над кнопкой
                  // Нижняя панель: Кнопка + иконки
                  Row(
                    children: [
                      Expanded(
                        child: _buildCartButton(
                          productId,
                          compact: widget.isHorizontal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onFavoriteTap,
                        child: SizedBox(
                          width: widget.isHorizontal ? 26 : 30,
                          height: widget.isHorizontal ? 26 : 30,
                          child: Center(
                            child: (widget.favoriteListenable == null)
                                ? Icon(
                                    Icons.favorite_border,
                                    size: widget.isHorizontal ? 20 : 22,
                                    color: Colors.black26,
                                  )
                                : ValueListenableBuilder<int>(
                                    valueListenable: widget.favoriteListenable!,
                                    builder: (context, _, __) {
                                      final isFavorite =
                                          widget.isFavoriteResolver?.call(
                                            productId,
                                          ) ??
                                          false;
                                      return Icon(
                                        Icons.favorite_border,
                                        size: widget.isHorizontal ? 20 : 22,
                                        color: isFavorite
                                            ? Colors.black
                                            : Colors.black26,
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onCompareTap,
                        child: SizedBox(
                          width: widget.isHorizontal ? 26 : 30,
                          height: widget.isHorizontal ? 26 : 30,
                          child: Center(
                            child: (widget.compareListenable == null)
                                ? Icon(
                                    Icons.bar_chart_outlined,
                                    size: widget.isHorizontal ? 20 : 22,
                                    color: Colors.black26,
                                  )
                                : ValueListenableBuilder<int>(
                                    valueListenable: widget.compareListenable!,
                                    builder: (context, _, __) {
                                      final isCompared =
                                          widget.isCompareResolver?.call(
                                            productId,
                                          ) ??
                                          false;
                                      return Icon(
                                        Icons.bar_chart_outlined,
                                        size: widget.isHorizontal ? 20 : 22,
                                        color: isCompared
                                            ? Colors.black
                                            : Colors.black26,
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartButton(String productId, {bool compact = false}) {
    final inCart =
        widget.cartListenable != null && widget.isInCartResolver != null
        ? widget.isInCartResolver!(productId)
        : false;
    final bool isInCart = inCart;
    return GestureDetector(
      onTap: widget.onAddToCart ?? widget.onTap,
      child: Container(
        height: 28,
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isInCart ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: isInCart ? Border.all(color: Colors.black, width: 1) : null,
        ),
        child: Text(
          isInCart ? "В корзине" : "В корзину",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isInCart ? Colors.black : Colors.white,
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final listenables = <Listenable>[];
    if (widget.galleryListenable != null) {
      listenables.add(widget.galleryListenable!);
    }
    if (widget.scrollListenable != null) {
      listenables.add(widget.scrollListenable!);
    }
    if (widget.scrollMainImageListenable != null) {
      listenables.add(widget.scrollMainImageListenable!);
    }
    if (widget.cartListenable != null) {
      listenables.add(widget.cartListenable!);
    }
    // favoriteListenable/compareListenable handled by ValueListenableBuilder in icon
    if (listenables.isEmpty) {
      return _buildCard(context, isScrolling: false);
    }
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final isScrolling = widget.scrollListenable?.value ?? false;
        return _buildCard(context, isScrolling: isScrolling);
      },
    );
  }

  Widget _badge(
    String text,
    Color color, {
    Color textColor = Colors.black,
    EdgeInsetsGeometry? padding,
    double? letterSpacing,
    String? fontFamily,
    FontWeight? fontWeight,
    double? fontSize,
    List<BoxShadow>? boxShadow,
  }) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: boxShadow,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize ?? 11,
          fontWeight: fontWeight ?? FontWeight.w500,
          fontFamily: fontFamily,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }
}

class _GalleryRequest {
  final String productId;
  final int index;
  final String categoryKey;

  const _GalleryRequest({
    required this.productId,
    required this.index,
    required this.categoryKey,
  });
}

class _CompareIndices {
  final int left;
  final int right;
  final bool hasRight;

  const _CompareIndices(this.left, this.right, this.hasRight);
}

class _CompareFeatureRender {
  final String label;
  final List<String> values;
  final bool hasDiff;
  final bool highlighted;

  const _CompareFeatureRender(
    this.label,
    this.values,
    this.hasDiff,
    this.highlighted,
  );
}

class _FeatureInfoRequest {
  final String fid;
  final StateSetter? modalSetter;

  const _FeatureInfoRequest(this.fid, this.modalSetter);
}

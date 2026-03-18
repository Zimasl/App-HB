import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/manticore_category.dart';
import '../models/manticore_product.dart';
import '../models/manticore_search_result.dart';

class ManticoreSearchService {
  static const String _defaultEndpoint = 'http://212.8.229.227:9308/sql';
  static const String _defaultSuggestEndpoint =
      'http://212.8.229.227:9308/cli_json';
  static const bool _logRawManticoreResponse = false;

  final Dio _dio;
  final String endpoint;
  final String suggestEndpoint;

  ManticoreSearchService({
    Dio? dio,
    this.endpoint = _defaultEndpoint,
    String? suggestEndpoint,
  }) : suggestEndpoint = suggestEndpoint ?? _deriveSuggestEndpoint(endpoint),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 5),
               receiveTimeout: const Duration(seconds: 8),
               sendTimeout: const Duration(seconds: 5),
               headers: const <String, String>{
                 'Accept': 'application/json',
                 'Content-Type': 'application/json',
               },
             ),
           );

  Future<ManticoreSearchResult> search({
    required String query,
    int productLimit = 15,
    int categoryLimit = 8,
  }) async {
    final normalizedQuery = _normalizeQuery(query);
    if (normalizedQuery.length < 3) {
      return ManticoreSearchResult.empty;
    }

    final plainQuery = _buildPlainMatchQuery(normalizedQuery);
    if (plainQuery.isEmpty) {
      return ManticoreSearchResult.empty;
    }

    final directResult = await _searchWithVariantFallback(
      plainQuery: plainQuery,
      productLimit: productLimit,
      categoryLimit: categoryLimit,
    );
    if (directResult.hasResults) {
      return directResult;
    }

    final suggestedQuery = await _suggestQuery(plainQuery);
    if (suggestedQuery == null) {
      return ManticoreSearchResult.empty;
    }

    final correctedPlainQuery = _buildPlainMatchQuery(
      _normalizeQuery(suggestedQuery),
    );
    if (correctedPlainQuery.isEmpty) {
      return ManticoreSearchResult.empty;
    }

    final correctedResult = await _searchWithVariantFallback(
      plainQuery: correctedPlainQuery,
      productLimit: productLimit,
      categoryLimit: categoryLimit,
    );
    if (!correctedResult.hasResults) {
      return ManticoreSearchResult.empty;
    }
    return ManticoreSearchResult(
      products: correctedResult.products,
      categories: correctedResult.categories,
      correctedQuery: correctedPlainQuery,
    );
  }

  Future<ManticoreSearchResult> searchProducts({
    required String query,
    int productLimit = 30,
    int productOffset = 0,
  }) async {
    final normalizedQuery = _normalizeQuery(query);
    if (normalizedQuery.length < 3) {
      return ManticoreSearchResult.empty;
    }

    final plainQuery = _buildPlainMatchQuery(normalizedQuery);
    if (plainQuery.isEmpty) {
      return ManticoreSearchResult.empty;
    }

    final directProducts = await _searchProductsWithVariantFallback(
      plainQuery: plainQuery,
      productLimit: productLimit,
      productOffset: productOffset,
    );
    if (directProducts.isNotEmpty) {
      return ManticoreSearchResult(
        products: directProducts,
        categories: const <ManticoreCategory>[],
      );
    }

    final suggestedQuery = await _suggestQuery(plainQuery);
    if (suggestedQuery == null) {
      return ManticoreSearchResult.empty;
    }

    final correctedPlainQuery = _buildPlainMatchQuery(
      _normalizeQuery(suggestedQuery),
    );
    if (correctedPlainQuery.isEmpty) {
      return ManticoreSearchResult.empty;
    }

    final correctedProducts = await _searchProductsWithVariantFallback(
      plainQuery: correctedPlainQuery,
      productLimit: productLimit,
      productOffset: productOffset,
    );
    if (correctedProducts.isEmpty) {
      return ManticoreSearchResult.empty;
    }

    return ManticoreSearchResult(
      products: correctedProducts,
      categories: const <ManticoreCategory>[],
      correctedQuery: correctedPlainQuery,
    );
  }

  Future<List<ManticoreProduct>> _searchProductsWithVariantFallback({
    required String plainQuery,
    required int productLimit,
    int productOffset = 0,
  }) async {
    final primary = await _searchProductsByInfix(
      plainQuery: plainQuery,
      productLimit: productLimit,
      productOffset: productOffset,
    );
    if (primary.isNotEmpty) {
      return primary;
    }

    for (final variant in _buildFallbackQueries(plainQuery)) {
      final next = await _searchProductsByInfix(
        plainQuery: variant,
        productLimit: productLimit,
        productOffset: productOffset,
      );
      if (next.isNotEmpty) {
        return next;
      }
    }

    return const <ManticoreProduct>[];
  }

  Future<ManticoreSearchResult> _searchWithVariantFallback({
    required String plainQuery,
    required int productLimit,
    required int categoryLimit,
  }) async {
    final primary = await _searchByInfix(
      plainQuery: plainQuery,
      productLimit: productLimit,
      categoryLimit: categoryLimit,
    );
    var products = primary.products;
    var categories = primary.categories;
    if (products.isNotEmpty && categories.isNotEmpty) {
      return primary;
    }

    for (final variant in _buildFallbackQueries(plainQuery)) {
      if (products.isNotEmpty && categories.isNotEmpty) {
        break;
      }
      final loadProducts = products.isEmpty;
      final loadCategories = categories.isEmpty;
      final futures = <Future<dynamic>>[];
      if (loadProducts) {
        futures.add(
          _searchProductsByInfix(
            plainQuery: variant,
            productLimit: productLimit,
          ),
        );
      }
      if (loadCategories) {
        futures.add(
          _searchCategoriesByInfix(
            plainQuery: variant,
            categoryLimit: categoryLimit,
          ),
        );
      }
      if (futures.isEmpty) {
        break;
      }
      final responses = await Future.wait<dynamic>(futures);
      var responseIndex = 0;
      if (loadProducts) {
        final nextProducts =
            responses[responseIndex++] as List<ManticoreProduct>;
        if (nextProducts.isNotEmpty) {
          products = nextProducts;
        }
      }
      if (loadCategories) {
        final nextCategories =
            responses[responseIndex++] as List<ManticoreCategory>;
        if (nextCategories.isNotEmpty) {
          categories = nextCategories;
        }
      }
    }

    return ManticoreSearchResult(products: products, categories: categories);
  }

  Future<ManticoreSearchResult> _searchByInfix({
    required String plainQuery,
    required int productLimit,
    required int categoryLimit,
  }) async {
    final responses = await Future.wait<dynamic>(<Future<dynamic>>[
      _searchProductsByInfix(
        plainQuery: plainQuery,
        productLimit: productLimit,
      ),
      _searchCategoriesByInfix(
        plainQuery: plainQuery,
        categoryLimit: categoryLimit,
      ),
    ]);
    return ManticoreSearchResult(
      products: responses[0] as List<ManticoreProduct>,
      categories: responses[1] as List<ManticoreCategory>,
    );
  }

  Future<List<ManticoreProduct>> _searchProductsByInfix({
    required String plainQuery,
    required int productLimit,
    int productOffset = 0,
  }) async {
    final escapedInfixExpr = _escapeSql(_buildInfixMatchExpression(plainQuery));
    final safeLimit = productLimit < 1
        ? 1
        : (productLimit > 120 ? 120 : productLimit);
    final safeOffset = productOffset < 0 ? 0 : productOffset;
    final payload = await _querySql(
      "SELECT id, name, summary, image_url, url, price, count FROM products WHERE MATCH('$escapedInfixExpr') LIMIT $safeOffset, $safeLimit",
    );
    return _parseProducts(payload);
  }

  Future<List<ManticoreCategory>> _searchCategoriesByInfix({
    required String plainQuery,
    required int categoryLimit,
  }) async {
    final escapedInfixExpr = _escapeSql(_buildInfixMatchExpression(plainQuery));
    final payload = await _querySql(
      "SELECT id, name FROM categories WHERE MATCH('$escapedInfixExpr') LIMIT ${categoryLimit.clamp(1, 30)}",
    );
    return _parseCategories(payload);
  }

  Future<String?> _suggestQuery(String plainQuery) async {
    final payload = await _queryCliJson(
      "CALL SUGGEST('${_escapeSql(plainQuery)}', 'products')",
    );
    final rows = _extractCliJsonRows(payload);
    final candidates = <({String suggest, int distance, int docs})>[];
    for (final row in rows) {
      final suggest = _normalizeQuery(row['suggest']?.toString() ?? '');
      final distance = int.tryParse(row['distance']?.toString() ?? '');
      final docs = int.tryParse(row['docs']?.toString() ?? '') ?? 0;
      if (suggest.isEmpty || distance == null || distance < 1 || distance > 2) {
        continue;
      }
      candidates.add((suggest: suggest, distance: distance, docs: docs));
    }
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) {
      final distanceDiff = a.distance.compareTo(b.distance);
      if (distanceDiff != 0) return distanceDiff;
      final docsDiff = b.docs.compareTo(a.docs);
      if (docsDiff != 0) return docsDiff;
      return a.suggest.length.compareTo(b.suggest.length);
    });
    final best = candidates.first.suggest;
    final normalizedBest = _buildPlainMatchQuery(best);
    if (normalizedBest.isEmpty ||
        _normalizeLookupKey(normalizedBest) ==
            _normalizeLookupKey(plainQuery)) {
      return null;
    }
    return normalizedBest;
  }

  Future<dynamic> _querySql(String sql) async {
    // This endpoint works reliably with raw SQL in POST body.
    try {
      final rawResponse = await _dio.post<dynamic>(
        endpoint,
        data: sql,
        options: Options(
          contentType: 'text/plain; charset=utf-8',
          responseType: ResponseType.json,
          validateStatus: (code) => code != null && code >= 200 && code < 500,
        ),
      );
      if (rawResponse.statusCode == 200 &&
          !_isManticoreParseError(rawResponse.data)) {
        final normalized = _normalizePayload(rawResponse.data);
        _debugLogResponse(sql, normalized, transport: 'raw');
        return normalized;
      }
    } catch (_) {
      // Try JSON envelope as a fallback only if raw transport fails.
    }

    final jsonResponse = await _dio.post<dynamic>(
      endpoint,
      data: <String, String>{'query': sql},
      options: Options(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (code) => code != null && code >= 200 && code < 500,
      ),
    );
    if (jsonResponse.statusCode != 200) {
      throw StateError('Manticore request failed: ${jsonResponse.statusCode}');
    }
    if (_isManticoreParseError(jsonResponse.data)) {
      throw StateError('Manticore SQL parse error');
    }
    final normalized = _normalizePayload(jsonResponse.data);
    _debugLogResponse(sql, normalized, transport: 'json');
    return normalized;
  }

  Future<dynamic> _queryCliJson(String sql) async {
    final response = await _dio.post<dynamic>(
      suggestEndpoint,
      data: sql,
      options: Options(
        contentType: 'text/plain; charset=utf-8',
        responseType: ResponseType.json,
        validateStatus: (code) => code != null && code >= 200 && code < 500,
      ),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Manticore cli_json request failed: ${response.statusCode}',
      );
    }
    final normalized = _normalizePayload(response.data);
    if (_isManticoreParseError(normalized) || _hasCliJsonError(normalized)) {
      throw StateError('Manticore cli_json parse error');
    }
    _debugLogResponse(sql, normalized, transport: 'cli_json');
    return normalized;
  }

  String _normalizeQuery(String query) {
    return query.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _buildPlainMatchQuery(String query) {
    final safe = query.replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё\s\-]'), ' ');
    return safe.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _buildInfixMatchExpression(String plainQuery) {
    final parts = plainQuery
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((part) => '*$part*')
        .toList(growable: false);
    if (parts.isEmpty) {
      return '*$plainQuery*';
    }
    return parts.join(' ');
  }

  List<String> _buildFallbackQueries(String plainQuery) {
    final normalizedPlainQuery = _normalizeLookupKey(plainQuery);
    final words = plainQuery
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return const <String>[];
    }
    final variants = <String>[];

    void addCandidate(String candidate) {
      final normalizedCandidate = _normalizeLookupKey(
        _buildPlainMatchQuery(candidate),
      );
      if (normalizedCandidate.isEmpty ||
          normalizedCandidate.length < 3 ||
          normalizedCandidate == normalizedPlainQuery ||
          variants.contains(normalizedCandidate)) {
        return;
      }
      variants.add(normalizedCandidate);
    }

    if (words.length == 1) {
      final word = words.first.toLowerCase();
      addCandidate(_stripRussianAdjectiveEnding(word));
      addCandidate(_stripRussianGeneralEnding(word));
      return variants;
    }

    final fallbackWords = <String>[];
    var hasFallbackWord = false;
    for (final rawWord in words) {
      final word = rawWord.toLowerCase();
      final adjectiveStem = _stripRussianAdjectiveEnding(word);
      final generalStem = _stripRussianGeneralEnding(word);
      final preferredStem = adjectiveStem.isNotEmpty
          ? adjectiveStem
          : generalStem;
      if (preferredStem.isNotEmpty) {
        fallbackWords.add(preferredStem);
        hasFallbackWord = true;
      } else {
        fallbackWords.add(word);
      }
    }
    if (hasFallbackWord) {
      addCandidate(fallbackWords.join(' '));
    }

    return variants;
  }

  String _stripRussianAdjectiveEnding(String word) {
    const endings = <String>[
      'ыми',
      'ими',
      'ого',
      'его',
      'ому',
      'ему',
      'ыми',
      'ими',
      'ых',
      'их',
      'ую',
      'юю',
      'ая',
      'яя',
      'ое',
      'ее',
      'ые',
      'ие',
      'ый',
      'ий',
      'ой',
      'ым',
      'им',
      'ом',
      'ем',
    ];
    return _stripRussianEnding(word, endings);
  }

  String _stripRussianGeneralEnding(String word) {
    const endings = <String>[
      'иями',
      'ями',
      'ами',
      'иях',
      'ах',
      'ях',
      'ов',
      'ев',
      'ей',
      'ам',
      'ям',
      'ом',
      'ем',
      'ою',
      'ею',
      'ию',
      'ью',
      'ия',
      'ья',
      'а',
      'я',
      'ы',
      'и',
      'о',
      'е',
      'у',
      'ю',
      'ь',
      'й',
    ];
    return _stripRussianEnding(word, endings);
  }

  String _stripRussianEnding(String word, List<String> endings) {
    for (final ending in endings) {
      if (word.length > ending.length + 2 && word.endsWith(ending)) {
        return word.substring(0, word.length - ending.length);
      }
    }
    return '';
  }

  String _normalizeLookupKey(String value) =>
      _normalizeQuery(value).toLowerCase();

  String _escapeSql(String value) => value.replaceAll("'", "''");

  bool _isManticoreParseError(dynamic payload) {
    if (payload is! Map) return false;
    final errorText = payload['error']?.toString().trim() ?? '';
    return errorText.isNotEmpty;
  }

  bool _hasCliJsonError(dynamic payload) {
    for (final statement in _extractCliJsonStatements(payload)) {
      final errorText = statement['error']?.toString().trim() ?? '';
      if (errorText.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  dynamic _normalizePayload(dynamic payload) {
    if (payload is String) {
      final body = payload.trim();
      if (body.isEmpty) return payload;
      try {
        return json.decode(body);
      } catch (_) {
        return payload;
      }
    }
    return payload;
  }

  List<Map<String, dynamic>> _extractCliJsonRows(dynamic payload) {
    final rows = <Map<String, dynamic>>[];
    for (final statement in _extractCliJsonStatements(payload)) {
      if (statement['data'] is! List) continue;
      for (final row in statement['data'] as List) {
        if (row is Map) {
          rows.add(Map<String, dynamic>.from(row));
        }
      }
    }
    return rows;
  }

  List<Map<String, dynamic>> _extractCliJsonStatements(dynamic payload) {
    Iterable<dynamic> statements;
    if (payload is List) {
      statements = payload;
    } else if (payload is Map && payload['value'] is List) {
      statements = payload['value'] as List;
    } else {
      return const <Map<String, dynamic>>[];
    }
    final result = <Map<String, dynamic>>[];
    for (final statement in statements) {
      if (statement is Map) {
        result.add(Map<String, dynamic>.from(statement));
      }
    }
    return result;
  }

  void _debugLogResponse(
    String sql,
    dynamic payload, {
    required String transport,
  }) {
    if (!_logRawManticoreResponse) return;
    String body;
    try {
      body = payload is String ? payload : jsonEncode(payload);
    } catch (_) {
      body = payload?.toString() ?? '';
    }
    // debugPrint is globally silenced in this app, so use print for diagnostics.
    // ignore: avoid_print
    print('Manticore transport: $transport');
    // ignore: avoid_print
    print('Manticore SQL: $sql');
    // ignore: avoid_print
    print('Raw JSON: $body');
  }

  List<ManticoreProduct> _parseProducts(dynamic payload) {
    final result = <ManticoreProduct>[];
    for (final hit in _extractRawHits(payload)) {
      final source = hit.source;
      final sourceIdRaw = source['id']?.toString().trim() ?? '';
      final hitIdRaw = hit.id?.toString().trim() ?? '';
      final idCandidate = sourceIdRaw.isNotEmpty ? sourceIdRaw : hitIdRaw;
      final idInt = int.tryParse(idCandidate);
      if (idInt == null) continue;
      final id = idInt.toString();
      final name = source['name']?.toString().trim() ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      final priceRaw = source['price'];
      final price = priceRaw is num
          ? priceRaw.toDouble()
          : double.tryParse(priceRaw?.toString() ?? '') ?? 0.0;
      final summary = source['summary']?.toString() ?? '';
      final imageUrl = source['image_url']?.toString().trim() ?? '';
      final url = source['url']?.toString().trim() ?? '';
      final countRaw = source['count'];
      final count = countRaw is num
          ? countRaw.toInt()
          : int.tryParse(countRaw?.toString() ?? '') ?? 0;
      result.add(
        ManticoreProduct(
          id: id,
          name: name,
          price: price,
          summary: summary,
          imageUrl: imageUrl,
          url: url,
          count: count,
        ),
      );
    }
    return result;
  }

  List<ManticoreCategory> _parseCategories(dynamic payload) {
    final result = <ManticoreCategory>[];
    for (final hit in _extractRawHits(payload)) {
      final source = hit.source;
      final sourceIdRaw = source['id']?.toString().trim() ?? '';
      final hitIdRaw = hit.id?.toString().trim() ?? '';
      final idCandidate = sourceIdRaw.isNotEmpty ? sourceIdRaw : hitIdRaw;
      final idInt = int.tryParse(idCandidate);
      if (idInt == null) continue;
      final id = idInt.toString();
      final name = source['name']?.toString().trim() ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      result.add(ManticoreCategory(id: id, name: name));
    }
    return result;
  }

  List<({dynamic id, Map<String, dynamic> source})> _extractRawHits(
    dynamic payload,
  ) {
    Iterable<dynamic> rows;
    if (payload is Map &&
        payload['hits'] is Map &&
        (payload['hits'] as Map)['hits'] is List) {
      rows = ((payload['hits'] as Map)['hits'] as List);
    } else if (payload is List) {
      rows = payload;
    } else if (payload is Map && payload['data'] is List) {
      rows = payload['data'] as List;
    } else {
      return const <({dynamic id, Map<String, dynamic> source})>[];
    }

    final result = <({dynamic id, Map<String, dynamic> source})>[];
    for (final rawHit in rows) {
      if (rawHit is! Map) continue;
      final id = rawHit['_id'];
      final rawSource = rawHit['_source'];
      final source = rawSource is Map
          ? Map<String, dynamic>.from(rawSource)
          : Map<String, dynamic>.from(rawHit);
      result.add((id: id, source: source));
    }
    return result;
  }

  static String _deriveSuggestEndpoint(String endpoint) {
    if (endpoint.trim().isEmpty) {
      return _defaultSuggestEndpoint;
    }
    try {
      final uri = Uri.parse(endpoint);
      final nextPath = uri.path.endsWith('/sql')
          ? uri.path.replaceFirst(RegExp(r'/sql$'), '/cli_json')
          : '/cli_json';
      return uri.replace(path: nextPath).toString();
    } catch (_) {
      return _defaultSuggestEndpoint;
    }
  }
}

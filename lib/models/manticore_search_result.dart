import 'manticore_category.dart';
import 'manticore_product.dart';

class ManticoreSearchResult {
  final List<ManticoreProduct> products;
  final List<ManticoreCategory> categories;
  final String? correctedQuery;

  const ManticoreSearchResult({
    required this.products,
    required this.categories,
    this.correctedQuery,
  });

  bool get hasResults => products.isNotEmpty || categories.isNotEmpty;

  bool get hasCorrection =>
      correctedQuery != null && correctedQuery!.trim().isNotEmpty;

  static const ManticoreSearchResult empty = ManticoreSearchResult(
    products: <ManticoreProduct>[],
    categories: <ManticoreCategory>[],
  );
}

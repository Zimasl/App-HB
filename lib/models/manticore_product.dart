class ManticoreProduct {
  final String id;
  final String name;
  final double price;
  final String summary;
  final String imageUrl;
  final String url;
  final int count;

  const ManticoreProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.summary,
    required this.imageUrl,
    required this.url,
    required this.count,
  });

  bool get hasPrice => price > 0;

  bool get hasImage => imageUrl.trim().isNotEmpty;

  bool get hasUrl => url.trim().isNotEmpty;
}

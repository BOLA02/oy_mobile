class Promo {
  const Promo({required this.id, required this.title, this.description, this.imageUrl, this.businessId, this.businessName});

  final int id;
  final String title;
  final String? description;

  /// `bgGradient` holds either an image URL or web-only Tailwind classes;
  /// only a URL is usable here, otherwise the brand gradient is drawn.
  final String? imageUrl;
  final int? businessId;
  final String? businessName;

  factory Promo.fromJson(Map<String, dynamic> j) {
    final bg = j['bgGradient'];
    final business = j['business'];
    return Promo(
      id: j['id'] as int,
      title: '${j['title'] ?? 'Special offer'}',
      description: j['desc'] as String?,
      imageUrl: bg is String && bg.startsWith('http') ? bg : null,
      businessId: (j['businessId'] as num?)?.toInt(),
      businessName: business is Map ? business['name'] as String? : null,
    );
  }
}

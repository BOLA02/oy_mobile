class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    this.type,
    this.city,
    this.state,
    this.description,
    this.imageUrl,
    this.rating,
    this.reviewCount = 0,
    this.minimumOrder,
    this.deliveryFee,
    this.openingHour,
    this.closingHour,
  });

  final int id;
  final String name;
  final String? type;
  final String? city;
  final String? state;
  final String? description;
  final String? imageUrl;
  final double? rating;
  final int reviewCount;
  final double? minimumOrder;
  final double? deliveryFee;
  final String? openingHour;
  final String? closingHour;

  String get location => [city, state].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  factory Restaurant.fromJson(Map<String, dynamic> j) {
    final gallery = j['galleryImages'];
    final firstGallery = gallery is List && gallery.isNotEmpty && gallery.first is Map
        ? (gallery.first as Map)['imageUrl'] as String?
        : null;
    return Restaurant(
      id: j['id'] as int,
      name: (j['name'] ?? '') as String,
      type: j['type'] as String?,
      city: j['city'] as String?,
      state: j['state'] as String?,
      description: j['description'] as String?,
      imageUrl: (j['thumbnailUrl'] ?? j['profilePicUrl'] ?? firstGallery) as String?,
      rating: (j['rating'] as num?)?.toDouble(),
      reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
      minimumOrder: (j['minimumOrder'] as num?)?.toDouble(),
      deliveryFee: (j['deliveryFee'] as num?)?.toDouble(),
      openingHour: j['openingHour'] as String?,
      closingHour: j['closingHour'] as String?,
    );
  }
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.category,
    this.description,
    this.imageUrl,
  });

  final int id;
  final String name;
  final double price;
  final String? category;
  final String? description;
  final String? imageUrl;

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        price: (j['price'] as num).toDouble(),
        category: j['category'] as String?,
        description: j['description'] as String?,
        imageUrl: j['imageUrl'] as String?,
      );
}

class RestaurantMenu {
  const RestaurantMenu({required this.restaurant, required this.items});

  final Restaurant restaurant;
  final List<MenuItem> items;

  Map<String, List<MenuItem>> get byCategory {
    final out = <String, List<MenuItem>>{};
    for (final i in items) {
      out.putIfAbsent(i.category?.trim().isNotEmpty == true ? i.category! : 'Menu', () => []).add(i);
    }
    return out;
  }
}

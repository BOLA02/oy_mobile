/// Business types are stored as codes (`buka_mamaput`); this gives them the
/// names customers should see. Unknown codes are tidied up rather than hidden.
String businessTypeLabel(String? raw) {
  final code = raw?.trim() ?? '';
  if (code.isEmpty) return '';
  const known = {
    'buka_mamaput': 'Buka / Mama Put',
    'fastfood_qsr': 'Fast food',
    'casual_dining': 'Casual dining',
    'restaurant': 'Restaurant',
    'ghost_kitchen': 'Delivery kitchen',
    'pastries_bakery': 'Bakery & pastries',
    'supermarket_grocery': 'Groceries',
    'drinks_liquor': 'Drinks',
  };
  final label = known[code.toLowerCase()];
  if (label != null) return label;
  final spaced = code.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return spaced[0].toUpperCase() + spaced.substring(1);
}

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

  String get typeLabel => businessTypeLabel(type);

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

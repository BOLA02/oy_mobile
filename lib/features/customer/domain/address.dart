class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  final int id;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  bool get hasLocation => latitude != null && longitude != null;

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        id: j['id'] as int,
        label: '${j['label'] ?? ''}',
        address: '${j['address'] ?? ''}',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        isDefault: j['isDefault'] == true,
      );
}

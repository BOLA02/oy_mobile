/// Who is using the app. The role is chosen at login and decides which half
/// of the app (customer or rider) is shown.
enum AppRole {
  customer,
  rider;

  String get label => this == customer ? 'Customer' : 'Rider';
}

class Session {
  const Session({
    required this.token,
    required this.role,
    required this.userId,
    this.name,
  });

  final String token;
  final AppRole role;
  final int userId;
  final String? name;

  Map<String, String> toStorage() => {
        'token': token,
        'role': role.name,
        'userId': '$userId',
        'name': ?name,
      };

  static Session? fromStorage(Map<String, String> m) {
    final token = m['token'];
    final role = AppRole.values.where((r) => r.name == m['role']).firstOrNull;
    final userId = int.tryParse(m['userId'] ?? '');
    if (token == null || role == null || userId == null) return null;
    return Session(token: token, role: role, userId: userId, name: m['name']);
  }
}

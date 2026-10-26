import 'restaurant.dart';

class CartLine {
  const CartLine({required this.item, required this.quantity});

  final MenuItem item;
  final int quantity;

  double get total => item.price * quantity;
}

class CartState {
  const CartState({this.restaurantId, this.restaurantName, this.lines = const []});

  final int? restaurantId;
  final String? restaurantName;
  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (n, l) => n + l.quantity);
  double get subtotal => lines.fold(0, (s, l) => s + l.total);
}

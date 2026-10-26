import 'restaurant.dart';

class CartLine {
  const CartLine({required this.item, required this.quantity});

  final MenuItem item;
  final int quantity;

  double get total => item.price * quantity;
}

class CartState {
  const CartState({
    this.restaurantId,
    this.restaurantName,
    this.deliveryFee,
    this.minimumOrder,
    this.lines = const [],
  });

  final int? restaurantId;
  final String? restaurantName;

  /// The restaurant's own fee, shown as an estimate in the cart. The real fee
  /// comes from the server's delivery quote at checkout.
  final double? deliveryFee;
  final double? minimumOrder;
  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (n, l) => n + l.quantity);
  double get subtotal => lines.fold(0, (s, l) => s + l.total);

  /// How much more must be added to reach the restaurant's minimum order.
  double get shortfall {
    final min = minimumOrder ?? 0;
    return subtotal >= min ? 0 : min - subtotal;
  }

  CartState copyWithLines(List<CartLine> next) => CartState(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        deliveryFee: deliveryFee,
        minimumOrder: minimumOrder,
        lines: next,
      );
}

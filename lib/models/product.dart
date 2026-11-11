class Product {
  const Product({
    required this.name,
    required this.price,
    required this.quantity,
    required this.image,
    this.key,
  });

  static const maxNameLength = 100;
  static const maxQuantity = 2147483647;
  static const maxPrice = 999999999999;
  static const maxImageBytes = 256 * 1024;

  final String? key;
  final String name;
  final num price;
  final int quantity;
  final String image;

  // Document ID nằm ngoài dữ liệu. Giá có thể là số nguyên hoặc số thực.
  factory Product.fromFirestore(String key, Map<String, dynamic> value) {
    final name = value['name'];
    final price = value['price'];
    final quantity = value['soluong'];
    final image = value['image'];
    if (name is! String ||
        price is! num ||
        !price.isFinite ||
        price < 0 ||
        quantity is! int ||
        quantity < 0 ||
        quantity > maxQuantity ||
        image is! String) {
      throw const FormatException('Sản phẩm có trường sai kiểu hoặc giá trị.');
    }
    return Product(
      key: key,
      name: name,
      price: price,
      quantity: quantity,
      image: image,
    );
  }

  // Chỉ ghi bốn trường theo đề. Số lượng trong Dart ánh xạ sang `soluong`.
  Map<String, Object> toFirestore() => {
    'name': name,
    'price': price,
    'soluong': quantity,
    'image': image,
  };
}

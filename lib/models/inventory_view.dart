import 'product.dart';

enum StockFilter {
  all('Tất cả'),
  inStock('Còn hàng'),
  outOfStock('Hết hàng');

  const StockFilter(this.label);
  final String label;
}

enum PriceOrder {
  original('Mặc định'),
  ascending('Giá tăng dần'),
  descending('Giá giảm dần');

  const PriceOrder(this.label);
  final String label;
}

const _vietnameseLetters = {
  'a': 'àáảãạăằắẳẵặâầấẩẫậ',
  'd': 'đ',
  'e': 'èéẻẽẹêềếểễệ',
  'i': 'ìíỉĩị',
  'o': 'òóỏõọôồốổỗộơờớởỡợ',
  'u': 'ùúủũụưừứửữự',
  'y': 'ỳýỷỹỵ',
};
final _vietnamesePatterns = _vietnameseLetters.map(
  (letter, variants) => MapEntry(letter, RegExp('[$variants]')),
);
final _combiningMarks = RegExp(
  r'[\u0300\u0301\u0302\u0303\u0306\u0309\u031b\u0323]',
);
final _spaces = RegExp(r'\s+');

// Chuẩn hóa cả chữ có dấu ghép sẵn và dấu Unicode tách rời.
String normalizeProductName(String text) {
  var normalized = text.toLowerCase().replaceAll(_combiningMarks, '');
  for (final MapEntry(key: letter, value: pattern)
      in _vietnamesePatterns.entries) {
    normalized = normalized.replaceAll(pattern, letter);
  }
  return normalized.trim().replaceAll(_spaces, ' ');
}

// Lọc trên cùng một snapshot, giữ thứ tự gốc khi giá bằng nhau.
List<Product> browseProducts(
  List<Product> products, {
  required String query,
  required StockFilter stock,
  required PriceOrder order,
}) {
  final search = normalizeProductName(query);
  final matches = products.indexed.where((entry) {
    final product = entry.$2;
    final matchesStock = switch (stock) {
      StockFilter.all => true,
      StockFilter.inStock => product.hasStock,
      StockFilter.outOfStock => !product.hasStock,
    };
    return matchesStock &&
        (search.isEmpty || normalizeProductName(product.name).contains(search));
  }).toList();
  if (order != PriceOrder.original) {
    matches.sort((left, right) {
      final byPrice = left.$2.price.compareTo(right.$2.price);
      if (byPrice == 0) return left.$1.compareTo(right.$1);
      return order == PriceOrder.ascending ? byPrice : -byPrice;
    });
  }
  return matches.map((entry) => entry.$2).toList(growable: false);
}

class InventorySummary {
  const InventorySummary._(this.productCount, this.unitCount, this.totalValue);

  final int productCount;
  final BigInt unitCount;
  final String totalValue;

  // Cộng giá × số lượng trên toàn bộ kho bằng số nguyên có thang thập phân.
  factory InventorySummary.fromProducts(List<Product> products) {
    var units = BigInt.zero;
    var value = BigInt.zero;
    var scale = 0;
    for (final product in products) {
      final quantity = BigInt.from(product.quantity);
      units += quantity;
      if (quantity == BigInt.zero) continue;

      final priceParts = product.price.toString().split('e');
      final digits = priceParts.first.split('.');
      final exponent = priceParts.length == 2 ? int.parse(priceParts.last) : 0;
      final priceScale =
          (digits.length == 2 ? digits.last.length : 0) - exponent;
      if (priceScale > scale) {
        value *= BigInt.from(10).pow(priceScale - scale);
        scale = priceScale;
      }
      final price = BigInt.parse(digits.join());
      value += price * quantity * BigInt.from(10).pow(scale - priceScale);
    }
    final digits = value.toString().padLeft(scale + 1, '0');
    final decimalPoint = digits.length - scale;
    final whole = groupInventoryDigits(digits.substring(0, decimalPoint));
    final fraction = digits
        .substring(decimalPoint)
        .replaceFirst(RegExp(r'0+$'), '');
    final formatted = fraction.isEmpty ? whole : '$whole,$fraction';
    return InventorySummary._(products.length, units, formatted);
  }
}

String groupInventoryDigits(String digits) =>
    digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

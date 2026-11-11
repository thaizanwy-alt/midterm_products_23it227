import 'package:flutter_test/flutter_test.dart';
import 'package:midterm_products_23it227/models/inventory_view.dart';
import 'package:midterm_products_23it227/models/product.dart';

Product product(String name, num price, int quantity) =>
    Product(name: name, price: price, quantity: quantity, image: 'test-image');

void main() {
  test('chuẩn hóa chữ hoa, đ và dấu Unicode tách rời', () {
    expect(normalizeProductName('  SỔ   TAY Đỏ  '), 'so tay do');
    expect(normalizeProductName('So\u0302\u0309 tay Đo\u0309'), 'so tay do');
  });

  test('tìm, lọc và sắp xếp cùng lúc, giữ thứ tự gốc khi giá bằng nhau', () {
    final first = product('Đèn bàn', 12, 2);
    final tie = product('Đèn tường', 12, 1);
    final cheap = product('Đèn đọc sách', 9.5, 3);
    final empty = product('Đèn trần', 3, 0);
    final other = product('Sổ tay', 2, 4);
    final products = [first, tie, cheap, empty, other];

    expect(
      browseProducts(
        products,
        query: 'DEN',
        stock: StockFilter.inStock,
        order: PriceOrder.ascending,
      ),
      [cheap, first, tie],
    );
    expect(
      browseProducts(
        products,
        query: 'đèn',
        stock: StockFilter.inStock,
        order: PriceOrder.descending,
      ),
      [first, tie, cheap],
    );
    expect(
      browseProducts(
        products,
        query: 'den',
        stock: StockFilter.outOfStock,
        order: PriceOrder.original,
      ),
      [empty],
    );
    expect(
      browseProducts(
        products,
        query: '',
        stock: StockFilter.all,
        order: PriceOrder.original,
      ),
      products,
    );
    expect(products, [first, tie, cheap, empty, other]);
  });

  test('tổng giá trị giữ phần lẻ và tích lớn hơn số nguyên 64 bit', () {
    final summary = InventorySummary.fromProducts([
      product('Số lớn', Product.maxPrice, Product.maxQuantity),
      product('Giá lẻ', 0.1, 3),
      product('Giá thập phân từ Firestore', 1e-7, 2),
      product('Hết hàng', 999, 0),
    ]);
    expect(summary.productCount, 4);
    expect(summary.unitCount, BigInt.from(Product.maxQuantity + 5));
    expect(summary.totalValue, '2.147.483.646.997.852.516.353,3000002');
    expect(InventorySummary.fromProducts([]).totalValue, '0');
  });

  test('ghi Firestore chỉ chứa bốn trường theo đề', () {
    final row = Product(
      key: 'document-id',
      name: 'Sổ tay',
      price: 9.5,
      quantity: 2,
      image: 'abc',
    );
    expect(row.toFirestore(), {
      'name': 'Sổ tay',
      'price': 9.5,
      'soluong': 2,
      'image': 'abc',
    });
  });
}

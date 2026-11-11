import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

class ProductService {
  ProductService(FirebaseFirestore database)
    : _products = database.collection('products');

  final CollectionReference<Map<String, dynamic>> _products;

  // snapshots() cập nhật danh sách khi Web hoặc Android ghi dữ liệu.
  Stream<List<Product>> watchProducts() =>
      _products.orderBy('name').snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) {
              return Product.fromFirestore(doc.id, doc.data());
            })
            .toList(growable: false);
      });

  // Trang chi tiết theo dõi đúng tài liệu khi kho cập nhật từ thiết bị khác.
  Stream<Product?> watchProduct(String key) =>
      _products.doc(key).snapshots().map((snapshot) {
        final data = snapshot.data();
        return data == null ? null : Product.fromFirestore(snapshot.id, data);
      });

  // add() để Firestore tạo Document ID tự động, bên ngoài bốn trường dữ liệu.
  Future<void> add(Product product) async {
    await _products.add(product.toFirestore());
  }

  // update() sửa đúng document và báo lỗi nếu document đã bị xóa.
  Future<void> update(String key, Product product) =>
      _products.doc(key).update(product.toFirestore());

  Future<void> delete(String key) => _products.doc(key).delete();
}

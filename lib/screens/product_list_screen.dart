import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../widgets/product_image.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({
    super.key,
    required this.auth,
    required this.service,
  });

  final AuthService auth;
  final ProductService service;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Stream<List<Product>> _products = widget.service.watchProducts();
  final _priceFormat = NumberFormat('#,##0.##', 'vi_VN');
  final _quantityFormat = NumberFormat.decimalPattern('vi_VN');
  final _deleting = <String>{};

  Future<void> _openForm([Product? product]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProductFormScreen(service: widget.service, product: product),
      ),
    );
    if (mounted && saved == true) {
      _notify(product == null ? 'Đã thêm sản phẩm.' : 'Đã lưu thay đổi.');
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // Hỏi lại trước khi xóa, rồi dùng Document ID của dòng được chọn.
  Future<void> _delete(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Xóa sản phẩm?'),
        content: Text('Bạn muốn xóa “${product.name}” khỏi kho?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    final key = product.key!;
    setState(() => _deleting.add(key));
    try {
      await widget.service.delete(key);
      if (mounted) _notify('Đã xóa sản phẩm.');
    } on FirebaseException {
      if (mounted) {
        _notify('Không xóa được sản phẩm. Hãy kiểm tra quyền và kết nối.');
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(key));
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.auth.signOut();
    } on FirebaseException {
      if (mounted) _notify('Không đăng xuất được. Hãy thử lại.');
    }
  }

  Widget _row(Product product, bool wide) {
    final theme = Theme.of(context);
    final price = '${_priceFormat.format(product.price)} đ';
    final quantity = _quantityFormat.format(product.quantity);
    final deleting = _deleting.contains(product.key);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: theme.textTheme.titleMedium),
        if (!wide) ...[
          const SizedBox(height: 4),
          Text(price),
          Text('Số lượng $quantity', style: theme.textTheme.bodySmall),
        ],
      ],
    );
    return Padding(
      key: ValueKey(product.key),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          SizedBox.square(
            dimension: wide ? 68 : 52,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: ProductImage(encoded: product.image, cacheWidth: 160),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: details),
          if (wide) ...[
            Expanded(
              flex: 2,
              child: Text(
                price,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: Text(quantity)),
          ],
          IconButton(
            tooltip: 'Sửa ${product.name}',
            onPressed: deleting ? null : () => _openForm(product),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Xóa ${product.name}',
            onPressed: deleting ? null : () => _delete(product),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined),
            SizedBox(width: 10),
            Text('Kho sản phẩm'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: StreamBuilder<List<Product>>(
              stream: _products,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final denied =
                      error is FirebaseException &&
                      error.code == 'permission-denied';
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            denied
                                ? 'Phiên này không có quyền đọc sản phẩm.'
                                : 'Không tải được danh sách sản phẩm.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => setState(
                              () => _products = widget.service.watchProducts(),
                            ),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${products.length} sản phẩm',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _openForm,
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm sản phẩm'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (products.isEmpty)
                        const Expanded(
                          child: Center(child: Text('Kho chưa có sản phẩm.')),
                        )
                      else
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 670;
                              return Column(
                                children: [
                                  if (wide)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: colors.secondaryContainer,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 11,
                                      ),
                                      child: const Row(
                                        children: [
                                          SizedBox(width: 80),
                                          Expanded(
                                            flex: 4,
                                            child: Text('Sản phẩm'),
                                          ),
                                          Expanded(flex: 2, child: Text('Giá')),
                                          Expanded(child: Text('Số lượng')),
                                          SizedBox(width: 96),
                                        ],
                                      ),
                                    ),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: products.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) =>
                                          _row(products[index], wide),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

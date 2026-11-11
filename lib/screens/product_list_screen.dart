import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/inventory_view.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../widgets/inventory_widgets.dart';
import '../widgets/product_image.dart';
import 'product_details_screen.dart';
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

  void _openDetails(Product product) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailsScreen(service: widget.service, product: product),
      ),
    );
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // Xác nhận tên sản phẩm, sau đó xóa theo Document ID.
  Future<void> _delete(Product product) async {
    final key = product.key!;
    if (!_deleting.add(key)) return;
    setState(() {});
    try {
      final colors = Theme.of(context).colorScheme;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          icon: Icon(Icons.delete_outline_rounded, color: colors.error),
          title: const Text('Xóa sản phẩm?'),
          content: Text('Xóa “${product.name}” khỏi kho?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Xóa sản phẩm'),
            ),
          ],
        ),
      );
      if (!mounted || confirm != true) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined),
            SizedBox(width: 10),
            Flexible(child: Text('Kho sản phẩm')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
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
            final products = snapshot.data;
            if (products == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _InventoryContent(
              products: products,
              deleting: _deleting,
              onAdd: _openForm,
              onEdit: _openForm,
              onDelete: _delete,
              onDetails: _openDetails,
            );
          },
        ),
      ),
    );
  }
}

class _InventoryContent extends StatefulWidget {
  const _InventoryContent({
    required this.products,
    required this.deleting,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onDetails,
  });

  final List<Product> products;
  final Set<String> deleting;
  final VoidCallback onAdd;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;
  final ValueChanged<Product> onDetails;

  @override
  State<_InventoryContent> createState() => _InventoryContentState();
}

class _InventoryContentState extends State<_InventoryContent> {
  final _search = TextEditingController();
  var _stock = StockFilter.all;
  var _order = PriceOrder.original;
  late var _summary = InventorySummary.fromProducts(widget.products);

  @override
  void didUpdateWidget(covariant _InventoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.products, widget.products)) {
      _summary = InventorySummary.fromProducts(widget.products);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _search.clear();
      _stock = StockFilter.all;
      _order = PriceOrder.original;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final products = browseProducts(
      widget.products,
      query: _search.text,
      stock: _stock,
      order: _order,
    );
    final hasFilters =
        _search.text.isNotEmpty ||
        _stock != StockFilter.all ||
        _order != PriceOrder.original;
    final search = TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (_) => setState(() {}),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: const InputDecoration(
        labelText: 'Tìm tên sản phẩm',
        prefixIcon: Icon(Icons.search_rounded),
      ),
    );
    final stock = _InventoryChoice(
      title: 'Tồn kho',
      value: _stock,
      values: StockFilter.values,
      label: (value) => value.label,
      onChanged: (value) => setState(() => _stock = value),
    );
    final order = _InventoryChoice(
      title: 'Sắp xếp',
      value: _order,
      values: PriceOrder.values,
      label: (value) => value.label,
      onChanged: (value) => setState(() => _order = value),
    );
    final reset = TextButton.icon(
      onPressed: hasFilters ? _reset : null,
      icon: const Icon(Icons.restart_alt_rounded),
      label: const Text('Đặt lại'),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 880;
            final padding = EdgeInsets.symmetric(horizontal: wide ? 28 : 16);
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: padding.add(const EdgeInsets.only(top: 20)),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InventorySummaryBar(summary: _summary, wide: wide),
                        const SizedBox(height: 22),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 10,
                          children: [
                            Text(
                              'Sản phẩm',
                              style: theme.textTheme.headlineSmall,
                            ),
                            FilledButton.icon(
                              onPressed: widget.onAdd,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Thêm sản phẩm'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (wide)
                          Row(
                            children: [
                              Expanded(flex: 3, child: search),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: stock),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: order),
                              const SizedBox(width: 8),
                              reset,
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              search,
                              const SizedBox(height: 10),
                              stock,
                              const SizedBox(height: 10),
                              order,
                              Align(
                                alignment: Alignment.centerRight,
                                child: reset,
                              ),
                            ],
                          ),
                        if (hasFilters &&
                            products.length != widget.products.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                'Hiển thị ${products.length}/${widget.products.length} mặt hàng',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (wide && products.isNotEmpty)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: DefaultTextStyle(
                                style: theme.textTheme.labelLarge!,
                                child: const _ProductColumns(
                                  identity: Text('Tên sản phẩm'),
                                  price: Text('Giá', textAlign: TextAlign.end),
                                  quantity: Text(
                                    'Số lượng',
                                    textAlign: TextAlign.end,
                                  ),
                                  stock: Text('Tồn kho'),
                                  actions: Text(
                                    'Thao tác',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (products.isEmpty)
                  SliverPadding(
                    padding: padding,
                    sliver: SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 34),
                        child: Text(
                          widget.products.isEmpty
                              ? 'Kho chưa có sản phẩm.'
                              : 'Không tìm thấy sản phẩm phù hợp.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: padding.add(const EdgeInsets.only(bottom: 24)),
                    sliver: SliverList.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final busy = widget.deleting.contains(product.key);
                        return _ProductRow(
                          key: ValueKey(product.key),
                          product: product,
                          wide: wide,
                          last: index == products.length - 1,
                          onDetails: () => widget.onDetails(product),
                          onEdit: busy ? null : () => widget.onEdit(product),
                          onDelete: busy
                              ? null
                              : () => widget.onDelete(product),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InventoryChoice<T> extends StatelessWidget {
  const _InventoryChoice({
    required this.title,
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: title,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.expand_more_rounded),
          items: [
            for (final option in values)
              DropdownMenuItem(value: option, child: Text(label(option))),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    super.key,
    required this.product,
    required this.wide,
    required this.last,
    required this.onDetails,
    this.onEdit,
    this.onDelete,
  });

  final Product product;
  final bool wide;
  final bool last;
  final VoidCallback onDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stock = StockBadge(hasStock: product.hasStock);
    final quantity = formatProductUnits(product.quantity);
    final price = Text(
      formatProductPrice(product.price),
      textAlign: wide ? TextAlign.end : TextAlign.start,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
    final identity = Semantics(
      container: true,
      button: true,
      label: 'Xem chi tiết ${product.name}',
      onTap: onDetails,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox.square(
                dimension: wide ? 62 : 54,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ProductImage(encoded: product.image, cacheWidth: 160),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(product.name, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Sửa ${product.name}',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Xóa ${product.name}',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
    final radius = wide
        ? BorderRadius.vertical(bottom: Radius.circular(last ? 12 : 0))
        : BorderRadius.circular(12);
    return Padding(
      padding: EdgeInsets.only(bottom: wide ? 0 : 10),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: wide
              ? _ProductColumns(
                  identity: identity,
                  price: price,
                  quantity: Text(quantity, textAlign: TextAlign.end),
                  stock: Align(alignment: Alignment.centerLeft, child: stock),
                  actions: Center(child: actions),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              price,
                              Text(
                                'Số lượng $quantity',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        actions,
                      ],
                    ),
                    stock,
                  ],
                ),
        ),
      ),
    );
  }
}

class _ProductColumns extends StatelessWidget {
  const _ProductColumns({
    required this.identity,
    required this.price,
    required this.quantity,
    required this.stock,
    required this.actions,
  });

  final Widget identity;
  final Widget price;
  final Widget quantity;
  final Widget stock;
  final Widget actions;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(flex: 5, child: identity),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: price),
      const SizedBox(width: 12),
      Expanded(flex: 2, child: quantity),
      const SizedBox(width: 20),
      Expanded(flex: 2, child: stock),
      SizedBox(width: 104, child: actions),
    ],
  );
}

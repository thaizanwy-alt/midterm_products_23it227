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
                        const SizedBox(height: 12),
                        _InventoryToolbar(
                          wide: wide,
                          search: _search,
                          stock: _stock,
                          order: _order,
                          onSearchChanged: (_) => setState(() {}),
                          onClearSearch: _search.text.isEmpty
                              ? null
                              : () => setState(_search.clear),
                          onStockChanged: (value) =>
                              setState(() => _stock = value),
                          onOrderChanged: (value) =>
                              setState(() => _order = value),
                          onReset: hasFilters ? _reset : null,
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
                        const SizedBox(height: 8),
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

class _InventoryToolbar extends StatelessWidget {
  const _InventoryToolbar({
    required this.wide,
    required this.search,
    required this.stock,
    required this.order,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onStockChanged,
    required this.onOrderChanged,
    required this.onReset,
  });

  final bool wide;
  final TextEditingController search;
  final StockFilter stock;
  final PriceOrder order;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClearSearch;
  final ValueChanged<StockFilter> onStockChanged;
  final ValueChanged<PriceOrder> onOrderChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const pill = BorderRadius.all(Radius.circular(24));
    final searchField = SizedBox(
      height: 48,
      child: TextField(
        controller: search,
        textInputAction: TextInputAction.search,
        onChanged: onSearchChanged,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          labelText: 'Tìm tên sản phẩm',
          floatingLabelBehavior: FloatingLabelBehavior.never,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: pill,
            borderSide: BorderSide(color: colors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: pill,
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 48,
          ),
          suffixIcon: onClearSearch == null
              ? null
              : IconButton(
                  tooltip: 'Xóa từ khóa',
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
        ),
      ),
    );
    final stockFilter = _StockChoice(value: stock, onChanged: onStockChanged);
    final sorted = order != PriceOrder.original;
    final sort = SizedBox.square(
      dimension: 48,
      child: PopupMenuButton<PriceOrder>(
        tooltip: 'Sắp xếp theo giá: ${order.label}',
        icon: const Icon(Icons.sort_rounded, size: 22),
        position: PopupMenuPosition.under,
        style: IconButton.styleFrom(
          backgroundColor: sorted ? colors.secondaryContainer : colors.surface,
          foregroundColor: sorted
              ? colors.onSecondaryContainer
              : colors.onSurfaceVariant,
          side: BorderSide(color: sorted ? colors.primary : colors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onSelected: onOrderChanged,
        itemBuilder: (context) => [
          for (final option in PriceOrder.values)
            CheckedPopupMenuItem(
              value: option,
              checked: order == option,
              child: Text(option.label),
            ),
        ],
      ),
    );
    final reset = TextButton.icon(
      onPressed: onReset,
      icon: const Icon(Icons.restart_alt_rounded),
      label: const Text('Đặt lại'),
    );

    // Keep a tap on a toolbar control from dismissing the search keyboard
    // before the control can handle the tap.
    return TextFieldTapRegion(
      child: wide
          ? Row(
              children: [
                SizedBox(width: 352, child: searchField),
                const SizedBox(width: 12),
                SizedBox(width: 188, child: stockFilter),
                const Spacer(),
                reset,
                const SizedBox(width: 8),
                sort,
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 8),
                    sort,
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: stockFilter),
                    const SizedBox(width: 8),
                    reset,
                  ],
                ),
              ],
            ),
    );
  }
}

class _StockChoice extends StatelessWidget {
  const _StockChoice({required this.value, required this.onChanged});

  final StockFilter value;
  final ValueChanged<StockFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Tồn kho',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StockFilter>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.expand_more_rounded),
          items: [
            for (final option in StockFilter.values)
              DropdownMenuItem(value: option, child: Text(option.label)),
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

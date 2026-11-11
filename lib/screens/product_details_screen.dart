import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/inventory_widgets.dart';
import '../widgets/product_image.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.service,
    required this.product,
  });

  final ProductService service;
  final Product product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late final _product = widget.service.watchProduct(widget.product.key!);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const InventoryBackButton(),
        title: const Text('Chi tiết sản phẩm'),
      ),
      body: SafeArea(
        child: StreamBuilder<Product?>(
          stream: _product,
          initialData: widget.product,
          builder: (context, snapshot) {
            final product = snapshot.data;
            if (snapshot.hasError || product == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    snapshot.hasError
                        ? 'Không tải được chi tiết sản phẩm.'
                        : 'Sản phẩm đã được xóa khỏi kho.',
                  ),
                ),
              );
            }
            final image = AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Semantics(
                    image: true,
                    label: 'Ảnh sản phẩm ${product.name}',
                    child: ProductImage(
                      encoded: product.image,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StockBadge(hasStock: product.hasStock),
                const SizedBox(height: 12),
                Text(product.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 20),
                Text('Giá', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  formatProductPrice(product.price),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Số lượng', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  formatProductUnits(product.quantity),
                  style: theme.textTheme.titleLarge,
                ),
              ],
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 640;
                      return Container(
                        padding: EdgeInsets.all(wide ? 24 : 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: image),
                                  const SizedBox(width: 28),
                                  Expanded(flex: 2, child: info),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  image,
                                  const SizedBox(height: 20),
                                  info,
                                ],
                              ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.encoded,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  });

  final String? encoded;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    // Ảnh là chuỗi Base64 thô. Image.memory dùng cùng một cách trên cả hai nền tảng.
    Uint8List? bytes;
    try {
      final value = encoded;
      if (value != null && value.isNotEmpty) bytes = base64Decode(value);
    } on FormatException {
      return const _ImagePlaceholder(icon: Icons.broken_image_outlined);
    }
    if (bytes == null) {
      return const _ImagePlaceholder(icon: Icons.image_outlined);
    }
    return Image.memory(
      bytes,
      fit: fit,
      cacheWidth: cacheWidth,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) =>
          const _ImagePlaceholder(icon: Icons.broken_image_outlined),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: 32, color: colors.onSurfaceVariant),
      ),
    );
  }
}

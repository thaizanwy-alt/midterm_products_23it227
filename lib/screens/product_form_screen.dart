import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/inventory_widgets.dart';
import '../widgets/product_image.dart';

const _maxSourceBytes = 10 * 1024 * 1024;
const _maxSourcePixels = 16000000;
const _maxSide = 960;

// Đọc định dạng theo nội dung. Giới hạn kích thước trước khi giải nén ảnh.
String _encodePhoto(Uint8List bytes) {
  final png = img.PngDecoder();
  final jpeg = img.JpegDecoder();
  final isPng = png.isValidFile(bytes);
  if (!isPng && !jpeg.isValidFile(bytes)) {
    throw const FormatException('Hãy chọn ảnh JPEG hoặc PNG.');
  }
  final img.Decoder decoder = isPng ? png : jpeg;
  final info = decoder.startDecode(bytes);
  if (info == null) throw const FormatException('Không đọc được ảnh đã chọn.');
  if (info.width * info.height > _maxSourcePixels) {
    throw const FormatException(
      'Ảnh vượt quá 16 megapixel. Hãy chọn ảnh nhỏ hơn.',
    );
  }
  final decoded = decoder.decode(bytes, frame: 0);
  if (decoded == null) {
    throw const FormatException('Không đọc được ảnh đã chọn.');
  }

  var photo = img.bakeOrientation(decoded);
  if (photo.width > _maxSide || photo.height > _maxSide) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? _maxSide : null,
      height: photo.height > photo.width ? _maxSide : null,
      interpolation: img.Interpolation.average,
    );
  }
  final compressed = isPng
      ? img.encodePng(photo)
      : img.encodeJpg(photo, quality: 78);
  if (compressed.length > Product.maxImageBytes) {
    throw const FormatException(
      'Ảnh sau khi thu nhỏ vượt 256 KB. Hãy chọn ảnh nhỏ hơn.',
    );
  }
  return base64Encode(compressed);
}

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.service, this.product});

  final ProductService service;
  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _price = TextEditingController(
    text: widget.product?.price.toString(),
  );
  late final _quantity = TextEditingController(
    text: widget.product?.quantity.toString(),
  );
  late String? _image = widget.product?.image;
  bool _picking = false;
  bool _saving = false;
  String? _imageError;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  // Android mở trình chọn ảnh của thiết bị. Web mở hộp thoại chọn tệp.
  Future<void> _pickImage() async {
    if (_picking || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _picking = true;
      _imageError = null;
    });
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (await file.length() > _maxSourceBytes) {
        throw const FormatException(
          'Tệp ảnh vượt 10 MB. Hãy chọn tệp nhỏ hơn.',
        );
      }
      final encoded = await compute(_encodePhoto, await file.readAsBytes());
      if (mounted) setState(() => _image = encoded);
    } on FormatException catch (error) {
      if (mounted) setState(() => _imageError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _imageError =
              'Không đọc được ảnh. Hãy chọn lại tệp JPEG hoặc PNG.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  num? _parsePrice(String raw) {
    final value = raw.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;
    final price = num.tryParse(value);
    return price != null && price <= Product.maxPrice ? price : null;
  }

  int? _parseQuantity(String raw) {
    final value = raw.trim();
    if (!RegExp(r'^\d+$').hasMatch(value)) return null;
    final quantity = int.tryParse(value);
    return quantity != null && quantity <= Product.maxQuantity
        ? quantity
        : null;
  }

  // Dùng cùng một form, chọn thao tác dựa trên Document ID hiện có.
  Future<void> _save() async {
    if (_saving || _picking) return;
    final valid = _formKey.currentState!.validate();
    final image = _image;
    if (image == null || image.isEmpty) {
      setState(() => _imageError = 'Hãy chọn ảnh sản phẩm.');
    }
    if (!valid || image == null || image.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final key = widget.product?.key;
    final product = Product(
      name: _name.text.trim(),
      price: _parsePrice(_price.text)!,
      quantity: _parseQuantity(_quantity.text)!,
      image: image,
    );
    try {
      if (key == null) {
        await widget.service.add(product);
      } else {
        await widget.service.update(key, product);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(
        () => _saveError = switch (error.code) {
          'permission-denied' => 'Phiên này không có quyền lưu sản phẩm.',
          'not-found' => 'Sản phẩm đã bị xóa. Hãy trở về danh sách.',
          _ => 'Không lưu được sản phẩm. Hãy kiểm tra kết nối và thử lại.',
        },
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imagePanel = _FormPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ảnh sản phẩm', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerLow,
                child: ProductImage(encoded: _image, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _picking || _saving ? null : _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _picking
                  ? 'Đang đọc ảnh…'
                  : _image == null
                  ? 'Chọn ảnh'
                  : 'Đổi ảnh',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _imageError ?? 'JPEG hoặc PNG, tối đa 10 MB trước khi thu nhỏ.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _imageError == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
    final fields = _FormPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Thông tin sản phẩm', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            enabled: !_saving,
            maxLength: Product.maxNameLength,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Tên sản phẩm'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Hãy nhập tên sản phẩm.'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _price,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Giá',
              suffixText: 'đ',
              helperText: 'Ví dụ 120000 hoặc 120000,50',
            ),
            validator: (value) => _parsePrice(value ?? '') == null
                ? 'Nhập giá từ 0 đến 999999999999, tối đa 2 số lẻ.'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _quantity,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Số lượng'),
            validator: (value) => _parseQuantity(value ?? '') == null
                ? 'Nhập số nguyên từ 0 đến 2147483647.'
                : null,
          ),
        ],
      ),
    );
    final saveAction = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saveError case final error?) ...[
          const SizedBox(height: 12),
          Text(error, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _picking || _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Đang đồng bộ…' : 'Lưu sản phẩm'),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        leading: const InventoryBackButton(),
        title: Text(widget.product == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 680) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: imagePanel),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(children: [fields, saveAction]),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        fields,
                        const SizedBox(height: 16),
                        imagePanel,
                        saveAction,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

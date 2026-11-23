class Garment {
  const Garment({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.image,
    required this.tag,
    this.store = '',
    this.sizes = const [],
  });

  final String id;
  final String name;
  final String category;
  final String price;
  final String image;
  final String tag;
  final String store;
  final List<String> sizes;

  String get storeId => store;
  String get tienda => store;

  /// Returns the realistic and appropriate sizes for this garment depending on its type.
  List<String> get availableSizes {
    if (sizes.isNotEmpty) {
      // Validate that the sizes match the product category
      final isCalzado = _isShoe;
      final isAcc = _isAccessory;
      if (isCalzado && sizes.any((s) => int.tryParse(s) != null)) {
        return sizes;
      }
      if (isAcc && sizes.any((s) => s.toLowerCase().contains('unic'))) {
        return const ['Talla Única'];
      }
      if (!isCalzado && !isAcc) {
        return sizes;
      }
    }

    if (_isShoe) {
      return const ['36', '37', '38', '39', '40', '41', '42', '43'];
    }
    if (_isAccessory) {
      return const ['Talla Única'];
    }
    return const ['S', 'M', 'L', 'XL', 'XXL'];
  }

  bool get _isShoe {
    final c = category.toLowerCase();
    final n = name.toLowerCase();
    return c.contains('calzado') ||
        c.contains('zapato') ||
        c.contains('zapatilla') ||
        n.contains('zapatilla') ||
        n.contains('zapato') ||
        n.contains('bota') ||
        n.contains('mocasín') ||
        n.contains('mocasin') ||
        n.contains('sandalia');
  }

  bool get _isAccessory {
    final c = category.toLowerCase();
    final n = name.toLowerCase();
    return c.contains('accesorio') ||
        c.contains('bolso') ||
        c.contains('mochila') ||
        c.contains('cartera') ||
        n.contains('bolso') ||
        n.contains('mochila') ||
        n.contains('cartera') ||
        n.contains('billetera') ||
        n.contains('gorro') ||
        n.contains('gorra') ||
        n.contains('cinturón') ||
        n.contains('cinto') ||
        n.contains('reloj') ||
        n.contains('lentes');
  }

  factory Garment.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final category =
        _stringValue(data['category'] ?? data['categoria']) ?? 'Otros';

    final rawSizes = data['sizes'] ?? data['tallas'];
    List<String> parsedSizes = [];
    if (rawSizes is List) {
      parsedSizes = rawSizes
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return Garment(
      id: id,
      name: _stringValue(data['name'] ?? data['nombre']) ?? 'Prenda sin nombre',
      category: category,
      price: _priceValue(data['price'] ?? data['precio']),
      image:
          _stringValue(
            data['image'] ??
                data['imageUrl'] ??
                data['image_url'] ??
                data['imagen'] ??
                data['foto'],
          ) ??
          '',
      tag: _stringValue(data['tag'] ?? data['etiqueta']) ?? category,
      store: _stringValue(
        data['store'] ??
            data['storeId'] ??
            data['store_id'] ??
            data['storeName'] ??
            data['tienda'] ??
            data['tiendaId'] ??
            data['tienda_id'] ??
            data['tiendaNombre'],
      ) ?? '',
      sizes: parsedSizes,
    );
  }

  static String? _stringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static String _priceValue(Object? value) {
    if (value is num) {
      return 'S/ ${value == value.roundToDouble() ? value.toInt() : value}';
    }
    return _stringValue(value) ?? 'Consultar';
  }
}

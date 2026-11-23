class Garment {
  const Garment({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.image,
    required this.tag,
    this.store = '',
  });

  final String id;
  final String name;
  final String category;
  final String price;
  final String image;
  final String tag;
  final String store;

  String get storeId => store;
  String get tienda => store;

  factory Garment.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final category =
        _stringValue(data['category'] ?? data['categoria']) ?? 'Otros';

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

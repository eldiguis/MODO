import 'dart:math' as math;
import '../../../models/garment.dart';

/// Representa una combinación de dos prendas (superior e inferior)
/// creada dentro de la experiencia interactiva "Swipe to Match".
class CapsuleOutfit {
  final Garment top;
  final Garment bottom;

  const CapsuleOutfit({
    required this.top,
    required this.bottom,
  });

  /// Parsea el valor numérico de un precio en formato String (ej: "S/ 89.90" o "120.00")
  static double parsePrice(String priceString) {
    final cleaned = priceString
        .replaceAll('S/', '')
        .replaceAll('s/', '')
        .replaceAll(r'$', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Precio total combinado de ambas prendas
  double get totalPrice => parsePrice(top.price) + parsePrice(bottom.price);

  /// Precio total formateado en soles
  String get formattedTotalPrice => 'S/ ${totalPrice.toStringAsFixed(2)}';

  /// Desglose de precios en formato legible
  String get priceBreakdown =>
      '${top.price.trim()} + ${bottom.price.trim()} = $formattedTotalPrice';

  /// Estilo estético / "Vibe" de la cápsula según las prendas combinadas
  String get vibeTitle {
    final combined = '${top.name} ${top.tag} ${bottom.name} ${bottom.tag}'.toLowerCase();
    if (combined.contains('lino') || combined.contains('blanco') || combined.contains('beige')) {
      return 'Cápsula Minimal Orgánica';
    } else if (combined.contains('negro') || combined.contains('black') || combined.contains('cuero')) {
      return 'Total Black Editorial';
    } else if (combined.contains('cargo') || combined.contains('oversize') || combined.contains('street')) {
      return 'Urban Streetwear';
    } else if (combined.contains('camisa') || combined.contains('blazer') || combined.contains('formal')) {
      return 'Smart Casual Chic';
    } else if (combined.contains('casaca') || combined.contains('denim') || combined.contains('jean')) {
      return 'Capsule Denim & Outerwear';
    }
    return 'Cápsula Esencial Contemporánea';
  }

  /// Porcentaje de afinidad / compatibilidad del look (93% - 98%)
  int get compatibilityScore {
    final hash = (top.id.hashCode ^ bottom.id.hashCode).abs();
    return 93 + (hash % 6); // Rango entre 93% y 98%
  }

  /// Puntos destacados del conjunto
  List<String> get highlights => const [
        'Silueta estilizada y equilibrada',
        'Armonía cromática de temporada',
        'Versatilidad para día y noche',
      ];
}

/// Clasificador inteligente de prendas para el catálogo de MODO
class GarmentClassifier {
  static const _topKeywords = [
    'polo',
    'polos',
    'top',
    'tops',
    'camisa',
    'camisas',
    'casaca',
    'casacas',
    'chaqueta',
    'blazer',
    'sweater',
    'hoodie',
    'chompa',
    'polera',
    'abrigo',
    't-shirt',
    'shirt',
    'jacket',
    'blusa',
  ];

  static const _bottomKeywords = [
    'pantalón',
    'pantalon',
    'pantalones',
    'jean',
    'jeans',
    'falda',
    'faldas',
    'short',
    'shorts',
    'cargo',
    'jogger',
    'calzado',
    'calzados',
    'zapatilla',
    'zapatillas',
    'botas',
    'shoes',
    'sneakers',
  ];

  /// Determina si una prenda es de la parte superior
  static bool isTop(Garment g) {
    final search = '${g.name} ${g.tag}'.toLowerCase();
    for (final kw in _topKeywords) {
      if (search.contains(kw)) return true;
    }
    return false;
  }

  /// Determina si una prenda es de la parte inferior o calzado
  static bool isBottom(Garment g) {
    final search = '${g.name} ${g.tag}'.toLowerCase();
    for (final kw in _bottomKeywords) {
      if (search.contains(kw)) return true;
    }
    return false;
  }

  /// Separa un catálogo completo en dos listas balanceadas: Tops y Bottoms.
  /// Si el catálogo no tiene suficientes prendas clasificables, distribuye
  /// de forma segura para garantizar que siempre haya prendas para deslizar.
  static ({List<Garment> tops, List<Garment> bottoms}) splitCatalog(
    List<Garment> all,
  ) {
    if (all.isEmpty) {
      return (tops: <Garment>[], bottoms: <Garment>[]);
    }

    final tops = <Garment>[];
    final bottoms = <Garment>[];

    for (final item in all) {
      if (isTop(item)) {
        tops.add(item);
      } else if (isBottom(item)) {
        bottoms.add(item);
      }
    }

    // Si una de las dos listas quedó vacía o con muy pocas prendas,
    // distribuimos las prendas restantes de forma balanceada.
    if (tops.isEmpty || bottoms.isEmpty) {
      final half = (all.length / 2).ceil();
      return (
        tops: all.sublist(0, math.min(half, all.length)),
        bottoms: all.sublist(math.min(half, all.length)),
      );
    }

    return (tops: tops, bottoms: bottoms);
  }
}

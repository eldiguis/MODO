import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/garment.dart';
import 'package:flutter_application_1/features/swipe_to_match/models/capsule_outfit.dart';
import 'package:flutter_application_1/features/swipe_to_match/presentation/swipe_to_match_screen.dart';

void main() {
  final sampleTop = Garment(
    id: 'top_01',
    name: 'Polo Oversize Essential',
    category: 'Polos',
    price: 'S/ 89.90',
    image: 'https://images.unsplash.com/photo-1',
    tag: 'Polos y Tops',
  );

  final sampleBottom = Garment(
    id: 'bottom_01',
    name: 'Pantalón Cargo Minimal',
    category: 'Pantalones',
    price: 'S/ 129.90',
    image: 'https://images.unsplash.com/photo-2',
    tag: 'Pantalones',
  );

  final sampleShoe = Garment(
    id: 'shoe_01',
    name: 'Zapatillas Urbanas Blancas',
    category: 'Calzado',
    price: 'S/ 199.90',
    image: 'https://images.unsplash.com/photo-3',
    tag: 'Calzado',
  );

  group('GarmentClassifier Unit Tests', () {
    test('classifies tops and bottoms correctly', () {
      expect(GarmentClassifier.isTop(sampleTop), isTrue);
      expect(GarmentClassifier.isBottom(sampleTop), isFalse);

      expect(GarmentClassifier.isBottom(sampleBottom), isTrue);
      expect(GarmentClassifier.isTop(sampleBottom), isFalse);

      expect(GarmentClassifier.isBottom(sampleShoe), isTrue);
      expect(GarmentClassifier.isTop(sampleShoe), isFalse);
    });

    test('splits catalog into tops and bottoms', () {
      final catalog = [sampleTop, sampleBottom, sampleShoe];
      final split = GarmentClassifier.splitCatalog(catalog);

      expect(split.tops.length, 1);
      expect(split.bottoms.length, 2);
      expect(split.tops.first.id, 'top_01');
    });
  });

  group('CapsuleOutfit Calculation Tests', () {
    test('calculates total price and formatted strings properly', () {
      final outfit = CapsuleOutfit(top: sampleTop, bottom: sampleBottom);

      expect(outfit.totalPrice, closeTo(219.80, 0.01));
      expect(outfit.formattedTotalPrice, 'S/ 219.80');
      expect(outfit.priceBreakdown, contains('S/ 89.90'));
      expect(outfit.priceBreakdown, contains('S/ 129.90'));
      expect(outfit.compatibilityScore, greaterThanOrEqualTo(93));
      expect(outfit.compatibilityScore, lessThanOrEqualTo(98));
      expect(outfit.vibeTitle, isNotEmpty);
      expect(outfit.highlights, hasLength(3));
    });
  });

  group('SwipeToMatchScreen Widget Tests', () {
    testWidgets('renders carousels, total price, and action buttons', (tester) async {
      final catalog = [sampleTop, sampleBottom];
      Garment? addedTop;
      Garment? addedBottom;

      await tester.pumpWidget(
        MaterialApp(
          home: SwipeToMatchScreen(
            catalog: catalog,
            onAddOutfitToCart: (top, bottom) {
              addedTop = top;
              addedBottom = bottom;
            },
            onTryOutfitInFittingRoom: (_, _) {},
          ),
        ),
      );

      // Verificamos que se renderice el título y la barra
      expect(find.text('SWIPE TO MATCH'), findsOneWidget);
      expect(find.textContaining('TOTAL DEL CONJUNTO'), findsOneWidget);
      expect(find.text('S/ 219.80'), findsOneWidget);
      expect(find.text('Añadir conjunto'), findsOneWidget);
      expect(find.text('Probar en IA'), findsOneWidget);

      // Tocamos el botón de añadir conjunto a la bolsa
      await tester.tap(find.text('Añadir conjunto'));
      await tester.pumpAndSettle();

      expect(addedTop?.id, 'top_01');
      expect(addedBottom?.id, 'bottom_01');
      expect(find.textContaining('¡Conjunto añadido!'), findsOneWidget);
    });

    testWidgets('toggles lock on garment when tap lock icon', (tester) async {
      final catalog = [sampleTop, sampleBottom];

      await tester.pumpWidget(
        MaterialApp(
          home: SwipeToMatchScreen(
            catalog: catalog,
            onAddOutfitToCart: (_, _) {},
            onTryOutfitInFittingRoom: (_, _) {},
          ),
        ),
      );

      // Inicialmente dice "Fijar"
      expect(find.text('Fijar'), findsNWidgets(2)); // Uno para top y uno para bottom

      // Tocamos el botón Fijar del top
      await tester.tap(find.text('Fijar').first);
      await tester.pumpAndSettle();

      // Ahora uno cambió a "Fijado"
      expect(find.text('Fijado'), findsOneWidget);
    });
  });
}

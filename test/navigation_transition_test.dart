import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets(
    'bottom navigation switches screens with an animated transition',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: ShopShell(customerName: 'Test shopper')),
      );
      expect(find.byType(AnimatedSwitcher), findsOneWidget);

      await tester.tap(find.text('Tienda'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));

      expect(find.text('Encuentra tu\npróximo favorito.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

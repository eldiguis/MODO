import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/product_catalog_repository.dart';

void main() {
  group('ProductCatalogRepository', () {
    test(
      'maps every Firestore document and preserves its document id',
      () async {
        final repository = ProductCatalogRepository(
          source: _FakeProductCatalogSource([
            ProductCatalogDocument(
              id: 'coat-1',
              data: {'name': 'Abrigo', 'category': 'Abrigos'},
            ),
            ProductCatalogDocument(
              id: 'shirt-2',
              data: {'name': 'Camisa', 'category': 'Camisas'},
            ),
          ]),
        );

        final products = await repository.watchProducts().first;

        expect(products.map((product) => product.id), ['coat-1', 'shirt-2']);
        expect(products.map((product) => product.name), ['Abrigo', 'Camisa']);
      },
    );

    test(
      'filters the loaded products by category without limiting the catalog',
      () async {
        final repository = ProductCatalogRepository(
          source: _FakeProductCatalogSource([
            ProductCatalogDocument(
              id: 'coat-1',
              data: {'name': 'Abrigo', 'category': 'Abrigos'},
            ),
            ProductCatalogDocument(
              id: 'shirt-2',
              data: {'name': 'Camisa', 'category': 'Camisas'},
            ),
            ProductCatalogDocument(
              id: 'coat-3',
              data: {'name': 'Gabardina', 'category': 'Abrigos'},
            ),
          ]),
        );

        final products = await repository
            .watchProducts(category: 'Abrigos')
            .first;

        expect(products.map((product) => product.id), ['coat-1', 'coat-3']);
      },
    );

    test('uses defensive defaults for optional or malformed fields', () async {
      final repository = ProductCatalogRepository(
        source: _FakeProductCatalogSource([
          ProductCatalogDocument(
            id: 'minimal',
            data: {
              'name': 'Prenda básica',
              'category': 'Básicos',
              'price': null,
              'image': 42,
            },
          ),
        ]),
      );

      final product = (await repository.watchProducts().first).single;

      expect(product.id, 'minimal');
      expect(product.price, 'Consultar');
      expect(product.image, isEmpty);
      expect(product.tag, 'Básicos');
    });
  });
}

class _FakeProductCatalogSource implements ProductCatalogDataSource {
  _FakeProductCatalogSource(this.documents);

  final List<ProductCatalogDocument> documents;

  @override
  Stream<List<ProductCatalogDocument>> watchDocuments() =>
      Stream.value(documents);
}

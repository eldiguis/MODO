import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/product_catalog_repository.dart';

void main() {
  test('catalog loads all forty uniquely named Firestore documents', () async {
    final repository = ProductCatalogRepository(
      source: _FakeProductCatalogSource(
        List.generate(
          40,
          (index) => ProductCatalogDocument(
            id: 'demo_$index',
            data: {'name': 'Garment $index', 'category': 'Shirts'},
          ),
        ),
      ),
    );

    final products = await repository.watchProducts().first;

    expect(products, hasLength(40));
    expect(products.map((item) => item.name).toSet(), hasLength(40));
  });
}

class _FakeProductCatalogSource implements ProductCatalogDataSource {
  _FakeProductCatalogSource(this.documents);

  final List<ProductCatalogDocument> documents;

  @override
  Stream<List<ProductCatalogDocument>> watchDocuments() =>
      Stream.value(documents);
}

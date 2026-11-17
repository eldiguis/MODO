import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/garment.dart';

class ProductCatalogDocument {
  const ProductCatalogDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

abstract interface class ProductCatalogDataSource {
  Stream<List<ProductCatalogDocument>> watchDocuments();
}

class FirestoreProductCatalogDataSource implements ProductCatalogDataSource {
  FirestoreProductCatalogDataSource({
    FirebaseFirestore? firestore,
    this.collectionName = 'productos',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String collectionName;

  @override
  Stream<List<ProductCatalogDocument>> watchDocuments() {
    return _firestore
        .collection(collectionName)
        .snapshots()
        .map(
          (snapshot) {
            debugPrint(
              '[Catalog] ${snapshot.docs.length} docs from "$collectionName"',
            );
            return snapshot.docs
                .map(
                  (document) => ProductCatalogDocument(
                    id: document.id,
                    data: document.data(),
                  ),
                )
                .toList(growable: false);
          },
        );
  }
}

class ProductCatalogRepository {
  ProductCatalogRepository({ProductCatalogDataSource? source})
    : _source = source ?? FirestoreProductCatalogDataSource();

  final ProductCatalogDataSource _source;

  Stream<List<Garment>> watchProducts({String? category}) {
    return _source.watchDocuments().map((documents) {
      final products = documents
          .map(
            (document) => Garment.fromMap(id: document.id, data: document.data),
          )
          .toList(growable: false);
      debugPrint('[Catalog] Parsed ${products.length} garments');
      if (category == null || category.toLowerCase() == 'todo') return products;
      return products
          .where((product) => product.category == category)
          .toList(growable: false);
    });
  }
}

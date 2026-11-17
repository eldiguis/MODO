import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/nearby_store_repository.dart';
import 'package:flutter_application_1/models/nearby_store.dart';

void main() {
  group('FirestoreNearbyStoreRecord', () {
    test('parses store fields and Firestore GeoPoint defensively', () {
      final store = StoreRecord.fromFirestore('store-1', {
        'name': 'Centro',
        'address': 'Av. Uno 123',
        'location': const GeoPoint(-12.0464, -77.0428),
        'phone': '555-1000',
        'openingHours': '9:00–18:00',
      });

      expect(store, isNotNull);
      expect(store!.name, 'Centro');
      expect(store.address, 'Av. Uno 123');
      expect(store.latitude, closeTo(-12.0464, 0.00001));
      expect(store.longitude, closeTo(-77.0428, 0.00001));
      expect(store.phone, '555-1000');
      expect(store.openingHours, '9:00–18:00');
      expect(StoreRecord.fromFirestore('bad', {'name': 'Bad'}), isNull);
    });

    test('parses inventory quantity and optional store price', () {
      final inventory = InventoryRecord.fromFirestore('p-1', {
        'productId': 'p-1',
        'quantity': 3,
        'price': 42.5,
      });
      expect(inventory, isNotNull);
      expect(inventory!.productId, 'p-1');
      expect(inventory.quantity, 3);
      expect(inventory.price, 42.5);
      expect(InventoryRecord.fromFirestore('p-1', {'quantity': -2}), isNull);
    });
  });

  test('requests foreground location on invocation and returns stocked stores nearest first', () async {
    final source = _FakeStoreSource(
      stores: [
        const StoreRecord(
          id: 'far',
          name: 'Far',
          address: 'B',
          latitude: 0,
          longitude: 1,
        ),
        const StoreRecord(
          id: 'near',
          name: 'Near',
          address: 'A',
          latitude: 0,
          longitude: 0.1,
        ),
        const StoreRecord(
          id: 'empty',
          name: 'Empty',
          address: 'C',
          latitude: 0,
          longitude: 0.01,
        ),
      ],
      inventory: {
        ('far', 'p-1'): const InventoryRecord(productId: 'p-1', quantity: 2),
        ('near', 'p-1'): const InventoryRecord(
          productId: 'p-1',
          quantity: 1,
          price: 50,
        ),
        ('empty', 'p-1'): const InventoryRecord(productId: 'p-1', quantity: 0),
      },
    );
    final location = _FakeLocationProvider(const UserLocation(0, 0));
    final repository = NearbyStoreRepository(
      source: source,
      locationProvider: location,
    );

    expect(location.calls, 0);
    final stores = await repository.findStoresForProduct('p-1');

    expect(location.calls, 1);
    expect(stores.map((store) => store.id), ['near', 'far']);
    expect(stores.first.quantity, 1);
    expect(stores.first.price, 50);
    expect(stores.first.distanceMeters, lessThan(stores.last.distanceMeters));
  });

  test(
    'propagates disabled or denied location as a typed unavailable result',
    () async {
      final repository = NearbyStoreRepository(
        source: _FakeStoreSource(),
        locationProvider: _FakeLocationProvider(null),
      );

      await expectLater(
        repository.findStoresForProduct('p-1'),
        throwsA(isA<LocationUnavailableException>()),
      );
    },
  );
}

class _FakeStoreSource implements NearbyStoreDataSource {
  _FakeStoreSource({this.stores = const [], this.inventory = const {}});
  final List<StoreRecord> stores;
  final Map<(String, String), InventoryRecord> inventory;

  @override
  Future<List<StoreRecord>> getStores() async => stores;

  @override
  Future<InventoryRecord?> getInventory(
    String storeId,
    String productId,
  ) async => inventory[(storeId, productId)];
}

class _FakeLocationProvider implements UserLocationProvider {
  _FakeLocationProvider(this.location);
  final UserLocation? location;
  int calls = 0;

  @override
  Future<UserLocation> getCurrentLocation() async {
    calls++;
    if (location == null) {
      throw const LocationUnavailableException(
        'Location is disabled or permission was denied.',
      );
    }
    return location!;
  }
}

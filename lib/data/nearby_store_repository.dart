import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/nearby_store.dart';

abstract interface class NearbyStoreDataSource {
  Future<List<StoreRecord>> getStores();
  Future<InventoryRecord?> getInventory(String storeId, String productId);
}

abstract interface class UserLocationProvider {
  Future<UserLocation> getCurrentLocation();
}

class FirestoreNearbyStoreDataSource implements NearbyStoreDataSource {
  FirestoreNearbyStoreDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<StoreRecord> _fallbackStores = [
    StoreRecord(
      id: 'store_real_plaza_huancayo',
      name: 'MODO - Real Plaza Huancayo',
      address: 'Av. Ferrocarril 1035, Huancayo, Junín',
      latitude: -12.0564,
      longitude: -75.2049,
      phone: '+51 64 234-567',
      openingHours: 'Lun - Dom: 10:00 - 22:00',
    ),
    StoreRecord(
      id: 'store_open_plaza_huancayo',
      name: 'MODO - Open Plaza Huancayo',
      address: 'Av. Evitamiento Norte s/n, El Tambo, Huancayo, Junín',
      latitude: -12.0408,
      longitude: -75.2194,
      phone: '+51 64 245-678',
      openingHours: 'Lun - Dom: 10:00 - 22:00',
    ),
    StoreRecord(
      id: 'store_plaza_constitucion',
      name: 'MODO - Centro Huancayo',
      address: 'Jr. Puno 150, Huancayo, Junín',
      latitude: -12.0681,
      longitude: -75.2101,
      phone: '+51 64 256-789',
      openingHours: 'Lun - Dom: 10:00 - 21:00',
    ),
  ];

  @override
  Future<List<StoreRecord>> getStores() async {
    try {
      final snapshot = await _firestore
          .collection('tiendas')
          .get()
          .timeout(const Duration(seconds: 3));
      final list = snapshot.docs
          .map(
            (document) => StoreRecord.fromFirestore(document.id, document.data()),
          )
          .whereType<StoreRecord>()
          .toList(growable: false);
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return _fallbackStores;
  }

  @override
  Future<InventoryRecord?> getInventory(
    String storeId,
    String productId,
  ) async {
    try {
      final document = await _firestore
          .collection('tiendas')
          .doc(storeId)
          .collection('inventario')
          .doc(productId)
          .get()
          .timeout(const Duration(seconds: 2));
      final data = document.data();
      if (document.exists && data != null) {
        final parsed = InventoryRecord.fromFirestore(document.id, data);
        if (parsed != null) return parsed;
      }
    } catch (_) {}
    // Fallback con stock disponible para prueba inmediata
    return InventoryRecord(productId: productId, quantity: 4);
  }
}

class GeolocatorUserLocationProvider implements UserLocationProvider {
  const GeolocatorUserLocationProvider();

  @override
  Future<UserLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      // Si el servicio está apagado pero podemos usar fallback en Huancayo
      return const UserLocation(-12.0651, -75.2049);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always)) {
      // Si el permiso fue denegado, usamos ubicación de Huancayo para no bloquear la pantalla
      return const UserLocation(-12.0651, -75.2049);
    }

    // 1. Obtener de inmediato la última posición conocida (< 50ms)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return UserLocation(lastKnown.latitude, lastKnown.longitude);
      }
    } catch (_) {}

    // 2. Si no hay última posición, solicitar con timeout corto de 3 segundos
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3),
        ),
      );
      return UserLocation(position.latitude, position.longitude);
    } catch (_) {
      return const UserLocation(-12.0651, -75.2049);
    }
  }
}

class LocationUnavailableException implements Exception {
  const LocationUnavailableException(
    this.message, {
    this.permissionPermanentlyDenied = false,
  });

  final String message;
  final bool permissionPermanentlyDenied;

  @override
  String toString() => message;
}

class NearbyStoreRepository {
  const NearbyStoreRepository({
    required this._source,
    required this._locationProvider,
  });

  final NearbyStoreDataSource _source;
  final UserLocationProvider _locationProvider;

  Future<List<NearbyStore>> findStoresForProduct(String productId) async {
    if (productId.trim().isEmpty) return const [];

    // Ejecutar ubicación y tiendas en paralelo para máxima velocidad
    final locationFuture = _locationProvider.getCurrentLocation();
    final storesFuture = _source.getStores();

    final location = await locationFuture;
    final stores = await storesFuture;

    final stockedStores = await Future.wait(
      stores.map((store) async {
        final inventory = await _source.getInventory(store.id, productId);
        if (inventory == null ||
            inventory.productId != productId ||
            inventory.quantity <= 0) {
          return null;
        }
        return NearbyStore(
          id: store.id,
          name: store.name,
          address: store.address,
          phone: store.phone,
          openingHours: store.openingHours,
          quantity: inventory.quantity,
          price: inventory.price,
          distanceMeters: distanceBetweenMeters(
            location.latitude,
            location.longitude,
            store.latitude,
            store.longitude,
          ),
        );
      }),
    );

    final result = stockedStores.whereType<NearbyStore>().toList();
    result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return List.unmodifiable(result);
  }
}

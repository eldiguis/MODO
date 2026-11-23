import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class StoreRecord {
  const StoreRecord({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.openingHours,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? openingHours;

  static StoreRecord? fromFirestore(String id, Map<String, dynamic> data) {
    final name = data['name'];
    final address = data['address'];
    final location = data['location'];
    if (id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        address is! String ||
        address.trim().isEmpty ||
        location is! GeoPoint ||
        !location.latitude.isFinite ||
        !location.longitude.isFinite ||
        location.latitude < -90 ||
        location.latitude > 90 ||
        location.longitude < -180 ||
        location.longitude > 180) {
      return null;
    }

    return StoreRecord(
      id: id,
      name: name.trim(),
      address: address.trim(),
      latitude: location.latitude,
      longitude: location.longitude,
      phone: _optionalString(data['phone']),
      openingHours: _optionalString(data['openingHours']),
    );
  }
}

class InventoryRecord {
  const InventoryRecord({
    required this.productId,
    required this.quantity,
    this.price,
  });

  final String productId;
  final int quantity;
  final double? price;

  static InventoryRecord? fromFirestore(
    String documentProductId,
    Map<String, dynamic> data,
  ) {
    final rawProductId = data['productId'];
    final rawQuantity = data['quantity'];
    final rawPrice = data['price'];
    final productId = rawProductId is String && rawProductId.trim().isNotEmpty
        ? rawProductId.trim()
        : documentProductId;
    if (productId.isEmpty ||
        (rawProductId is String && rawProductId != documentProductId) ||
        rawQuantity is! num ||
        !rawQuantity.isFinite ||
        rawQuantity < 0 ||
        rawQuantity % 1 != 0 ||
        (rawPrice != null &&
            (rawPrice is! num || !rawPrice.isFinite || rawPrice < 0))) {
      return null;
    }

    return InventoryRecord(
      productId: productId,
      quantity: rawQuantity.toInt(),
      price: rawPrice is num ? rawPrice.toDouble() : null,
    );
  }
}

class UserLocation {
  const UserLocation(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class NearbyStore {
  const NearbyStore({
    required this.id,
    required this.name,
    required this.address,
    required this.quantity,
    required this.distanceMeters,
    this.phone,
    this.openingHours,
    this.price,
  });

  final String id;
  final String name;
  final String address;
  final int quantity;
  final double distanceMeters;
  final String? phone;
  final String? openingHours;
  final double? price;
}

double distanceBetweenMeters(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const earthRadiusMeters = 6371000.0;
  final lat1 = _toRadians(latitude1);
  final lat2 = _toRadians(latitude2);
  final deltaLat = _toRadians(latitude2 - latitude1);
  final deltaLon = _toRadians(longitude2 - longitude1);
  final sinLat = math.sin(deltaLat / 2);
  final sinLon = math.sin(deltaLon / 2);
  final a =
      (sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon)
          .clamp(0.0, 1.0);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;

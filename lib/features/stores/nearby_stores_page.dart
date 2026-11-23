import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui_skeletons.dart';
import '../catalog/models/garment.dart';
import 'data/nearby_store_repository.dart';
import 'models/nearby_store.dart';

const Map<String, String> storeDisplayNames = {
  'store_real_plaza_huancayo': 'MODO - Real Plaza Huancayo',
  'store_open_plaza_huancayo': 'MODO - Open Plaza Huancayo',
  'store_plaza_constitucion': 'MODO - Centro Huancayo',
};

Future<void> openStoreLocation(BuildContext context, String storeId) async {
  if (storeId.trim().isEmpty) return;
  final source = FirestoreNearbyStoreDataSource();
  final stores = await source.getStores();
  StoreRecord? store;
  for (final candidate in stores) {
    if (candidate.id == storeId) {
      store = candidate;
      break;
    }
  }
  if (store == null) return;
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${store.latitude},${store.longitude}',
  );
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo abrir la app de Google Maps.')),
      );
    }
  }
}

class NearbyStoresPage extends StatefulWidget {
  const NearbyStoresPage({super.key, required this.product});

  final Garment product;

  @override
  State<NearbyStoresPage> createState() => _NearbyStoresPageState();
}

class _NearbyStoresPageState extends State<NearbyStoresPage> {
  bool loading = true;
  String? error;
  bool permissionPermanentlyDenied = false;
  List<NearbyStore> stores = const [];

  Future<void> loadStores() async {
    setState(() {
      loading = true;
      error = null;
      permissionPermanentlyDenied = false;
    });
    try {
      final result = await NearbyStoreRepository(
        source: FirestoreNearbyStoreDataSource(),
        locationProvider: const GeolocatorUserLocationProvider(),
      ).findStoresForProduct(widget.product.id);
      if (!mounted) return;
      setState(() {
        stores = result;
        loading = false;
      });
    } on LocationUnavailableException catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.message;
        permissionPermanentlyDenied = exception.permissionPermanentlyDenied;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'No se pudo consultar tiendas e inventario en Firebase.';
        loading = false;
      });
      debugPrint('Nearby store lookup failed: $exception');
    }
  }

  @override
  void initState() {
    super.initState();
    loadStores();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: paper,
        appBar: AppBar(
          title: const Text('Tiendas cercanas'),
          backgroundColor: paper,
        ),
        body: SafeArea(
          child: loading
              ? const StoreListSkeleton()
              : error != null
                  ? _message(
                      icon: Icons.location_disabled_outlined,
                      title: 'No pudimos obtener tu ubicación',
                      subtitle:
                          '$error\nActiva el servicio de ubicación y permite el acceso mientras usas la app.',
                      action: permissionPermanentlyDenied
                          ? 'ABRIR AJUSTES'
                          : 'INTENTAR DE NUEVO',
                      onPressed: permissionPermanentlyDenied
                          ? Geolocator.openAppSettings
                          : loadStores,
                    )
                  : stores.isEmpty
                      ? _message(
                          icon: Icons.store_mall_directory_outlined,
                          title: 'No hay tiendas con stock cercano',
                          subtitle:
                              'Aún no encontramos inventario disponible para ${widget.product.name}. La disponibilidad se consulta en Firebase.',
                          action: 'ACTUALIZAR',
                          onPressed: loadStores,
                        )
                      : RefreshIndicator(
                          color: ink,
                          backgroundColor: lime,
                          onRefresh: loadStores,
                          child: ListView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.all(18),
                            children: [
                              Text(
                                widget.product.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Disponibilidad y stock en nuestras tiendas oficiales MODO.',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                              const SizedBox(height: 14),
                              for (final store in stores)
                                Card(
                                  color: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(color: line),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: lime,
                                      foregroundColor: ink,
                                      child: Icon(Icons.storefront_outlined),
                                    ),
                                    title: Text(
                                      store.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    subtitle: Text(
                                      '${store.address}\n${_distanceLabel(store.distanceMeters)} · Stock: ${store.quantity}'
                                      '${store.openingHours == null ? '' : '\n${store.openingHours}'}',
                                    ),
                                    isThreeLine: true,
                                    trailing: IconButton(
                                      icon: const Icon(Icons.map_outlined),
                                      tooltip: 'Ver en Google Maps',
                                      onPressed: () =>
                                          openStoreLocation(context, store.id),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
        ),
      );

  Widget _message({
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onPressed,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: muted),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onPressed, child: Text(action)),
            ],
          ),
        ),
      );

  String _distanceLabel(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';
}

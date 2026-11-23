import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/fade_slide_route.dart';
import '../../core/widgets/ui_skeletons.dart';
import '../catalog/data/product_catalog_repository.dart';
import '../catalog/models/garment.dart';
import '../catalog/product_detail_page.dart';
import '../fitting_room/models/body_measurements.dart';
import '../fitting_room/sensor_camera_guide.dart';
import '../fitting_room/services/fit_predictor_service.dart';
import '../fitting_room/widgets/fit_prediction_card.dart';
import '../fitting_room/widgets/privacy_consent_sheet.dart';
import '../onboarding/user_guide_dialogs.dart';
import '../swipe_to_match/presentation/swipe_to_match_screen.dart';

/// Returns a Unsplash CDN URL or the [source] itself if already a full URL.
String photo(String source, {int width = 800}) {
  if (source.startsWith('https://') || source.startsWith('http://')) return source;
  return 'https://images.unsplash.com/$source?auto=format&fit=crop&w=$width&q=85';
}

class ShopShell extends StatefulWidget {
  final String customerName;
  final bool firebaseConfigured;
  final VoidCallback? onSignOut;

  const ShopShell({
    super.key,
    required this.customerName,
    this.firebaseConfigured = false,
    this.onSignOut,
  });

  @override
  State<ShopShell> createState() => _ShopShellState();
}

class _ShopShellState extends State<ShopShell> {
  int tab = 0;
  DateTime? lastBackPressTime;
  String category = 'Todo';

  // ── Cart ────────────────────────────────────────────────────────────────────
  final Map<String, int> cartQuantities = {};

  int get cartCount =>
      cartQuantities.values.fold<int>(0, (total, q) => total + q);

  double get cartTotalPrice {
    double sum = 0;
    for (final entry in cartQuantities.entries) {
      if (entry.value <= 0) continue;
      final product = catalogProducts.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => Garment(
          id: entry.key,
          name: 'Prenda MODO',
          category: 'Ropa',
          price: 'S/ 0.00',
          image: '',
          tag: '',
        ),
      );
      final raw = product.price
          .replaceAll('S/', '')
          .replaceAll('s/', '')
          .replaceAll(r'$', '')
          .replaceAll(',', '.')
          .trim();
      sum += (double.tryParse(raw) ?? 0.0) * entry.value;
    }
    return sum;
  }

  String get formattedCartTotal => 'S/ ${cartTotalPrice.toStringAsFixed(2)}';

  // ── Accessibility ────────────────────────────────────────────────────────────
  bool largeText = false;
  bool highContrast = false;
  bool reduceMotion = false;

  // ── Favorites (persisted) ────────────────────────────────────────────────────
  final Set<String> favorites = {};

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('favorite_ids') ?? [];
      if (mounted) setState(() => favorites.addAll(ids));
    } catch (_) {}
  }

  Future<void> _toggleFavorite(String id) async {
    setState(() {
      if (favorites.contains(id)) {
        favorites.remove(id);
      } else {
        favorites.add(id);
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_ids', favorites.toList());
    } catch (_) {}
  }

  // ── Catalog ──────────────────────────────────────────────────────────────────
  final List<Garment> catalogProducts = [];
  StreamSubscription<List<Garment>>? catalogSubscription;
  bool catalogLoading = true;
  String? catalogError;

  bool get _isFirebaseReady =>
      widget.firebaseConfigured || (!kIsWeb && Firebase.apps.isNotEmpty);

  void _startCatalogSubscription() {
    if (!_isFirebaseReady) {
      catalogLoading = false;
      catalogError = kIsWeb
          ? 'La configuración Firebase para web todavía no está agregada.'
          : 'No se pudo iniciar Firebase. Revisa la configuración de Android.';
      return;
    }
    catalogSubscription?.cancel();
    catalogLoading = true;
    catalogError = null;
    catalogSubscription = ProductCatalogRepository().watchProducts().listen(
      (items) {
        if (!mounted) return;
        setState(() {
          catalogProducts
            ..clear()
            ..addAll(items);
          catalogLoading = false;
          catalogError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          catalogLoading = false;
          catalogError = 'No se pudo leer la colección productos de Firebase.';
        });
      },
    );
  }

  // ── Fitting Room / AI ────────────────────────────────────────────────────────
  Uint8List? frontPhoto, sidePhoto;
  final picker = ImagePicker();
  FitPredictionResult? fitPredictionResult;
  bool isPredictingFit = false;
  int selectedLook = 0;

  Future<void> _loadSavedBodyMeasurements() async {
    final m = await BodyMeasurements.loadLocal();
    if (m != null && mounted) {
      setState(() {
        fitPredictionResult = FitPredictionResult(
          recommendedSize: m.recommendedSize,
          confidencePercent: (m.confidenceScore * 100).toInt(),
          fitStyle: 'Medidas Guardadas',
          measurements: m,
          explanation: 'Basado en tu última calibración con sensor y silueta.',
        );
      });
    }
  }

  Future<void> _processFitPrediction(Uint8List imageBytes) async {
    final hasConsent = await BodyMeasurements.hasAcceptedPrivacy();
    if (!hasConsent && mounted) {
      final accepted = await PrivacyConsentSheet.show(context);
      if (!accepted) return;
    }
    setState(() => isPredictingFit = true);
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/temp_fit_body_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(imageBytes);
      final result = await const FitPredictorService().predictFromPhoto(
        imageFile: tempFile,
      );
      if (mounted) {
        setState(() {
          fitPredictionResult = result;
          isPredictingFit = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isPredictingFit = false);
    }
  }

  // ── Onboarding Guides ────────────────────────────────────────────────────────
  /// Guides seen per tab (index → prefs key)
  static const _guideKeys = {
    0: 'guide_seen_home',
    1: 'guide_seen_shop',
    2: 'guide_seen_fitting',
    3: 'guide_seen_cart',
    4: 'guide_seen_account',
  };

  Future<void> _checkFirstTimeGuides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('has_seen_welcome_tour') ?? false;
      if (!hasSeen && mounted) {
        await prefs.setBool('has_seen_welcome_tour', true);
        await prefs.setBool(_guideKeys[0]!, true);
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) => WelcomeTourDialog(
              onFinished: () {
                Navigator.of(context).pop();
                _showHomeGuide();
              },
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _checkTabGuide(int tabIndex) async {
    final key = _guideKeys[tabIndex];
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool(key) ?? false;
      if (!hasSeen && mounted) {
        await prefs.setBool(key, true);
        if (tabIndex == 1 && mounted) {
          _showShopGuide();
        } else if (tabIndex == 2 && mounted) {
          _showFittingRoomCoach();
        } else if (tabIndex == 3 && mounted) {
          _showCartGuide();
        } else if (tabIndex == 4 && mounted) {
          _showAccountGuide();
        }
      }
    } catch (_) {}
  }

  void _showWelcomeTour() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const WelcomeTourDialog(),
    );
  }

  void _showHomeGuide() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const HomeTabGuideDialog(),
    );
  }

  void _showShopGuide() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ShopTabGuideDialog(),
    );
  }

  void _showFittingRoomCoach() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const FittingRoomCoachDialog(),
    );
  }

  void _showCartGuide() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CartTabGuideDialog(),
    );
  }

  void _showAccountGuide() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const AccountTabGuideDialog(),
    );
  }

  void _showSwipeToMatchGuide() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SwipeToMatchGuideDialog(),
    );
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadSavedBodyMeasurements();
    _loadFavorites();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstTimeGuides());
    _startCatalogSubscription();
  }

  @override
  void didUpdateWidget(covariant ShopShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.firebaseConfigured && widget.firebaseConfigured) ||
        (catalogProducts.isEmpty &&
            catalogSubscription == null &&
            _isFirebaseReady)) {
      _startCatalogSubscription();
    }
  }

  @override
  void dispose() {
    catalogSubscription?.cancel();
    super.dispose();
  }

  // ── Catalog helpers ──────────────────────────────────────────────────────────
  List<String> get catalogCategories {
    final cats = catalogProducts.map((p) => p.category).toSet().toList()..sort();
    return ['Todo', 'Favoritos', ...cats];
  }

  List<Garment> get visibleProducts {
    if (category == 'Favoritos') {
      return catalogProducts.where((p) => favorites.contains(p.id)).toList();
    }
    if (category == 'Todo') {
      return catalogProducts;
    }
    return catalogProducts.where((p) => p.category == category).toList();
  }

  Future<void> _refreshCatalog() async {
    HapticFeedback.lightImpact();
    setState(() => catalogLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => catalogLoading = false);
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screens = [home(), shop(), fittingRoom(), cart(), accountSettings()];
    final baseTheme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (tab != 0) {
          setState(() => tab = 0);
          return;
        }
        final now = DateTime.now();
        if (lastBackPressTime == null ||
            now.difference(lastBackPressTime!) > const Duration(seconds: 2)) {
          lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Presiona de nuevo para salir de MODO'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: Theme(
        data: baseTheme.copyWith(
          colorScheme: highContrast
              ? ColorScheme.fromSeed(
                  seedColor: ink, surface: paper, contrastLevel: 1)
              : baseTheme.colorScheme,
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(largeText ? 1.15 : 1),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: SafeArea(
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(.035, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ));
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(key: ValueKey(tab), child: screens[tab]),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              height: 68,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFECEAE4),
              selectedIndex: tab,
              onDestinationSelected: (value) {
                HapticFeedback.selectionClick();
                setState(() => tab = value);
                _checkTabGuide(value);
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Inicio',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag_rounded),
                  label: 'Tienda',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome_rounded),
                  label: 'Probador IA',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_basket_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_basket_rounded),
                  ),
                  label: 'Bolsa',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: favorites.isNotEmpty,
                    label: Text('${favorites.length}'),
                    child: const Icon(Icons.person_outline_rounded),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: favorites.isNotEmpty,
                    label: Text('${favorites.length}'),
                    child: const Icon(Icons.person_rounded),
                  ),
                  label: 'Cuenta',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tabs ─────────────────────────────────────────────────────────────────────

  Widget home() => RefreshIndicator(
        color: ink,
        backgroundColor: lime,
        onRefresh: _refreshCatalog,
        child: CustomScrollView(
          physics:
              const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                child: _hero(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: _swipeToMatchBanner(),
              ),
            ),
            SliverToBoxAdapter(
              child: _sectionTitle('Selección de la semana', 'Ver todo', () {
                HapticFeedback.selectionClick();
                setState(() => tab = 1);
              }),
            ),
            ..._homeProductSection(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: _tryBanner(),
              ),
            ),
          ],
        ),
      );

  Widget shop() => RefreshIndicator(
        color: ink,
        backgroundColor: lime,
        onRefresh: _refreshCatalog,
        child: CustomScrollView(
          physics:
              const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Encuentra tu\npróximo favorito.',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                        height: 1.05,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: catalogCategories
                            .map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    avatar: c == 'Favoritos'
                                        ? Icon(
                                            Icons.favorite,
                                            size: 14,
                                            color: category == c
                                                ? lime
                                                : Colors.redAccent,
                                          )
                                        : null,
                                    label: Text(c == 'Favoritos'
                                        ? 'Favoritos (${favorites.length})'
                                        : c),
                                    selected: category == c,
                                    onSelected: (_) {
                                      HapticFeedback.selectionClick();
                                      setState(() => category = c);
                                    },
                                    selectedColor: ink,
                                    labelStyle: TextStyle(
                                      color: category == c
                                          ? Colors.white
                                          : ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: line),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ..._shopProductSection(),
          ],
        ),
      );

  Widget fittingRoom() => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _tag('MODO LAB  /  BETA'),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Ver guía paso a paso del probador',
                        onPressed: _showFittingRoomCoach,
                        icon: const Icon(Icons.help_outline, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu probador\ninteligente.',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.03,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Sube dos fotos y descubre cómo te queda.',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F7E6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD3E7B2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: lime,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.sensors, size: 18, color: ink),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Sensor Acelerómetro activo: calibra el ángulo recto (90°) al tomar la foto.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E5316),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _showFittingRoomCoach,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EFEA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.school_outlined,
                                size: 16, color: ink),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '¿Cómo funciona el probador? Toca aquí para ver la guía con sensor',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _captureCard(true)),
                      const SizedBox(width: 12),
                      Expanded(child: _captureCard(false)),
                    ],
                  ),
                  if (isPredictingFit) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: line),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: ink, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Analizando silueta y prediciendo talle óptimo...',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ink),
                          ),
                        ],
                      ),
                    ),
                  ] else if (fitPredictionResult != null) ...[
                    FitPredictionCard(
                      result: fitPredictionResult!,
                      onRecalibrate: () => _pickCapture(true),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: line),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_outlined, size: 19),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Para un mejor resultado, usa ropa ajustada, buena luz y un fondo despejado.',
                            style: TextStyle(
                                fontSize: 12, height: 1.4, color: muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'ELIGE UNA PRENDA',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 122,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: catalogProducts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => setState(() => selectedLook = i),
                        child: Container(
                          width: 88,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedLook == i ? ink : line,
                              width: selectedLook == i ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            photo(catalogProducts[i].image, width: 220),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.checkroom),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed:
                          frontPhoto != null && sidePhoto != null
                              ? _showPreview
                              : null,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text(
                        'GENERAR MI LOOK',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, letterSpacing: .4),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: ink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFCFCEC8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Center(
                    child: Text(
                      'Tus fotos solo se usan para generar la vista previa.',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget cart() => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tu bolsa.',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1),
                    ),
                  ),
                  Text('$cartCount artículos',
                      style: const TextStyle(color: muted, fontSize: 13)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _cartStepItem('1', 'Elegir prendas', true),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 11, color: muted),
                    _cartStepItem('2', 'Revisar bolsa', cartCount > 0),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 11, color: muted),
                    _cartStepItem('3', 'Boleta digital', false),
                  ],
                ),
              ),
            ),
          ),
          if (cartCount == 0)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag_outlined,
                          size: 54, color: muted),
                      const SizedBox(height: 16),
                      const Text('Tu bolsa está esperando.',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('Descubre prendas que van contigo.',
                          style: TextStyle(color: muted)),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => setState(() => tab = 1),
                        style:
                            FilledButton.styleFrom(backgroundColor: ink),
                        child: const Text('IR A LA TIENDA'),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: line),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿Cómo comprar en 3 pasos simples?',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '1. Entra a "Tienda" y toca una prenda que te guste.\n2. Selecciona tu talla y toca "AÑADIR A LA BOLSA".\n3. Regresa aquí y toca "FINALIZAR COMPRA".',
                              style: TextStyle(
                                  color: muted, fontSize: 11, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ..._cartProductItems(),
                    const Divider(),
                    ListTile(
                      title: const Text('Subtotal'),
                      trailing: Text(
                        formattedCartTotal,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => tab = 1),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              foregroundColor: ink,
                              side: const BorderSide(color: line),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('SEGUIR COMPRANDO'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _showCheckoutDialog,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              backgroundColor: ink,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('FINALIZAR COMPRA'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      );

  Widget accountSettings() => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MI PERFIL',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Mi cuenta',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: lime,
                          foregroundColor: ink,
                          child: Icon(Icons.person_outline_rounded),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nombre de perfil',
                                  style: TextStyle(color: muted, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                widget.customerName.isEmpty
                                    ? 'Usuario MODO'
                                    : widget.customerName,
                                style: const TextStyle(
                                    color: ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Favoritos ──────────────────────────────────────────────
                  if (favorites.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    const Text('Mis favoritos',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: favorites.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final id = favorites.elementAt(i);
                          final g = catalogProducts.firstWhere(
                            (p) => p.id == id,
                            orElse: () => Garment(
                              id: id,
                              name: 'Prenda',
                              category: '',
                              price: '',
                              image: '',
                              tag: '',
                            ),
                          );
                          return GestureDetector(
                            onTap: () => _showProduct(g),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    photo(g.image, width: 200),
                                    width: 86,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 86,
                                      height: 120,
                                      color: const Color(0xFFECEBE5),
                                      child: const Icon(Icons.checkroom,
                                          color: muted),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _toggleFavorite(id),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                            alpha: .9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.favorite,
                                          size: 14, color: ink),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 26),
                  const Text('Ajustes de cuenta',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(Icons.badge_outlined, color: ink),
                    title: Text('Datos del perfil'),
                    subtitle: Text('Consulta el nombre asociado a tu cuenta'),
                  ),
                  const Divider(height: 24),
                  const Text('Accesibilidad',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Texto grande'),
                    subtitle:
                        const Text('Aumenta el tamaño del texto en la app'),
                    value: largeText,
                    onChanged: (v) => setState(() => largeText = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alto contraste'),
                    subtitle:
                        const Text('Refuerza el contraste de los colores'),
                    value: highContrast,
                    onChanged: (v) => setState(() => highContrast = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reducir movimiento'),
                    subtitle:
                        const Text('Limita las animaciones de la interfaz'),
                    value: reduceMotion,
                    onChanged: (v) => setState(() => reduceMotion = v),
                  ),
                  const Divider(height: 24),
                  const Text('Ayuda y Tutoriales',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFECEAE4),
                      foregroundColor: ink,
                      child: Icon(Icons.school_outlined, size: 20),
                    ),
                    title: const Text('Guía interactiva de bienvenida',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Paseo introductorio por la aplicación MODO'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: _showWelcomeTour,
                  ),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFECEAE4),
                      foregroundColor: ink,
                      child: Icon(Icons.shopping_bag_outlined, size: 20),
                    ),
                    title: const Text('Guía de la Tienda y Filtros',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Aprende a buscar prendas, tallas y favoritos'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: _showShopGuide,
                  ),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFECEAE4),
                      foregroundColor: ink,
                      child: Icon(Icons.auto_awesome_rounded, size: 20),
                    ),
                    title: const Text('Guía del Probador Virtual con IA',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle:
                        const Text('Aprende a calibrar el acelerómetro a 90°'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: _showFittingRoomCoach,
                  ),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFECEAE4),
                      foregroundColor: ink,
                      child: Icon(Icons.style_outlined, size: 20),
                    ),
                    title: const Text('Guía de Swipe to Match',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Arma cápsulas combinando prendas con swipe'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: _showSwipeToMatchGuide,
                  ),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFECEAE4),
                      foregroundColor: ink,
                      child: Icon(Icons.receipt_long_outlined, size: 20),
                    ),
                    title: const Text('Guía de la Bolsa y Compra',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Revisa tus pedidos y emite tu boleta digital'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: _showCartGuide,
                  ),
                  const SizedBox(height: 24),
                  if (widget.onSignOut != null) ...[
                    const Divider(),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: widget.onSignOut,
                        icon: const Icon(Icons.logout_rounded,
                            size: 18, color: Colors.redAccent),
                        label: const Text(
                          'CERRAR SESIÓN',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      );

  // ── Helper widgets ────────────────────────────────────────────────────────────

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Row(
          children: [
            const Text(
              'MODO',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3),
            ),
            const SizedBox(width: 7),
            Container(
              width: 7,
              height: 7,
              decoration:
                  const BoxDecoration(color: lime, shape: BoxShape.circle),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Swipe to Match',
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  FadeSlideRoute<void>(
                    builder: (_) => SwipeToMatchScreen(
                      catalog: catalogProducts,
                      onAddOutfitToCart: (top, bottom) => setState(() {
                        cartQuantities[top.id] =
                            (cartQuantities[top.id] ?? 0) + 1;
                        cartQuantities[bottom.id] =
                            (cartQuantities[bottom.id] ?? 0) + 1;
                      }),
                      onTryOutfitInFittingRoom: (top, bottom) =>
                          setState(() => tab = 2),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.style_outlined),
            ),
            IconButton(
              tooltip: 'Guía de esta sección',
              onPressed: () {
                switch (tab) {
                  case 0:
                    _showHomeGuide();
                    break;
                  case 1:
                    _showShopGuide();
                    break;
                  case 2:
                    _showFittingRoomCoach();
                    break;
                  case 3:
                    _showCartGuide();
                    break;
                  case 4:
                    _showAccountGuide();
                    break;
                  default:
                    _showWelcomeTour();
                }
              },
              icon: const Icon(Icons.help_outline_rounded),
            ),
            IconButton(
              tooltip: 'Buscar en tienda',
              onPressed: () => setState(() => tab = 1),
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'Ver mi bolsa',
              onPressed: () => setState(() => tab = 3),
              icon: const Icon(Icons.shopping_basket_outlined),
            ),
          ],
        ),
      );

  Widget _hero() => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 405,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                photo('photo-1539109136881-3be0616acf4b', width: 1000),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) =>
                    Container(color: const Color(0xFFD7D1C8)),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC101010)],
                    stops: [.4, 1],
                  ),
                ),
              ),
              Positioned(top: 18, left: 18, child: _tag('COLECCIÓN  /  01')),
              Positioned(
                left: 22,
                right: 22,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VISTE A TU\nMANERA.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: .98,
                        fontSize: 38,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Piezas para todos tus días.',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => tab = 1),
                      icon: const Icon(Icons.arrow_forward, size: 17),
                      label: const Text('DESCUBRIR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  /// Bug fix: removed "IDEA DISRUPTIVA 1" label from the banner.
  Widget _swipeToMatchBanner() => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            FadeSlideRoute<void>(
              builder: (_) => SwipeToMatchScreen(
                catalog: catalogProducts,
                onAddOutfitToCart: (top, bottom) => setState(() {
                  cartQuantities[top.id] =
                      (cartQuantities[top.id] ?? 0) + 1;
                  cartQuantities[bottom.id] =
                      (cartQuantities[bottom.id] ?? 0) + 1;
                }),
                onTryOutfitInFittingRoom: (top, bottom) =>
                    setState(() => tab = 2),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lime,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.style_outlined, color: ink, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Swipe to Match',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Desliza prendas superiores e inferiores para armar tu cápsula.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white70, size: 14),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String title, String action, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
            ),
            TextButton(
              onPressed: onTap,
              child: Text(action,
                  style: const TextStyle(color: ink)),
            ),
          ],
        ),
      );

  Widget _tryBanner() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRUÉBATE\nANTES DE ELEGIR.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 21,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tu look, visualizado con IA.',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => setState(() => tab = 2),
                    style: FilledButton.styleFrom(
                        backgroundColor: lime, foregroundColor: ink),
                    child: const Text('PROBAR AHORA'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.auto_awesome, size: 54, color: lime),
          ],
        ),
      );

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: lime,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: .8,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
      );

  List<Widget> _homeProductSection() {
    if (catalogLoading) {
      return const [
        ProductGridSkeleton(
            count: 4, padding: EdgeInsets.fromLTRB(20, 0, 20, 8)),
      ];
    }
    if (catalogError != null || catalogProducts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EditorialEmptyState(
            title: catalogError != null
                ? 'Error de conexión'
                : 'Colección en preparación',
            message: catalogError ??
                'Estamos preparando las prendas destacadas de esta semana.',
            actionLabel: 'REINTENTAR',
            onAction: _refreshCatalog,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _productCardItem(catalogProducts[i]),
            childCount:
                catalogProducts.length < 6 ? catalogProducts.length : 6,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: .59,
          ),
        ),
      ),
    ];
  }

  List<Widget> _shopProductSection() {
    if (catalogLoading) {
      return const [
        ProductGridSkeleton(
            count: 6, padding: EdgeInsets.fromLTRB(20, 8, 20, 28)),
      ];
    }
    if (category == 'Favoritos' && visibleProducts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EditorialEmptyState(
            title: 'Sin favoritos guardados',
            message:
                'Toca el icono de corazón en cualquier prenda para agregarla a tus favoritos.',
            actionLabel: 'VER TODAS LAS PRENDAS',
            onAction: () {
              HapticFeedback.selectionClick();
              setState(() => category = 'Todo');
            },
          ),
        ),
      ];
    }
    if (catalogError != null || visibleProducts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EditorialEmptyState(
            title: catalogError != null
                ? 'Error de catálogo'
                : 'No hay prendas disponibles',
            message: catalogError ??
                'Prueba cambiando de categoría o toca abajo para ver todas.',
            actionLabel: 'VER TODAS LAS PRENDAS',
            onAction: () {
              HapticFeedback.selectionClick();
              setState(() => category = 'Todo');
            },
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _productCardItem(visibleProducts[i]),
            childCount: visibleProducts.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: .59,
          ),
        ),
      ),
    ];
  }

  Widget _productCardItem(Garment p) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showProduct(p);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'garment_photo_${p.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      photo(p.image, width: 600),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFE3E0D8),
                        child: const Icon(Icons.checkroom,
                            size: 58, color: muted),
                      ),
                    ),
                  ),
                ),
                Positioned(top: 10, left: 10, child: _tag(p.tag)),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _toggleFavorite(p.id);
                    },
                    icon: Icon(
                      favorites.contains(p.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Colors.white.withValues(alpha: .9),
                      foregroundColor: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            p.category,
            style: const TextStyle(
              fontSize: 9,
              color: muted,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(p.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Text(p.price,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _captureCard(bool front) {
    final bytes = front ? frontPhoto : sidePhoto;
    return GestureDetector(
      onTap: () => _pickCapture(front),
      child: Container(
        height: 212,
        decoration: BoxDecoration(
          color: const Color(0xFFECEBE5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: bytes == null ? line : ink,
            width: bytes == null ? 1 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover)
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    front ? Icons.person_outline : Icons.accessibility_new,
                    size: 42,
                    color: const Color(0xFFB5B3AB),
                  ),
                  const SizedBox(height: 12),
                  Icon(Icons.add_circle, size: 24, color: ink),
                  const SizedBox(height: 8),
                  Text(
                    'Añadir foto\n${front ? 'frontal' : 'lateral'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            Positioned(
              left: 9,
              top: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  front ? '01  FRONTAL' : '02  LATERAL',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6),
                ),
              ),
            ),
            if (bytes != null)
              const Positioned(
                right: 9,
                top: 9,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: lime,
                  child: Icon(Icons.check, size: 14, color: ink),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cartProductItems() {
    if (catalogProducts.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(18),
          child: Text('No se pudo recuperar el detalle de las prendas.'),
        ),
      ];
    }
    final items = <Widget>[];
    for (final entry in cartQuantities.entries) {
      if (entry.value <= 0) continue;
      final product = catalogProducts.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => catalogProducts.first,
      );
      items.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              photo(product.image, width: 160),
              width: 65,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 65,
                height: 80,
                color: const Color(0xFFF0EFEB),
                child: const Icon(Icons.checkroom, color: muted),
              ),
            ),
          ),
          title: Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${product.price} · Cantidad: ${entry.value}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                tooltip: 'Reducir cantidad',
                onPressed: () => setState(() {
                  if ((cartQuantities[product.id] ?? 0) > 1) {
                    cartQuantities[product.id] =
                        cartQuantities[product.id]! - 1;
                  } else {
                    cartQuantities.remove(product.id);
                  }
                }),
              ),
              Text('${entry.value}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                tooltip: 'Aumentar cantidad',
                onPressed: () => setState(() {
                  cartQuantities[product.id] =
                      (cartQuantities[product.id] ?? 0) + 1;
                }),
              ),
            ],
          ),
        ),
      );
    }
    return items;
  }

  Widget _cartStepItem(String num, String label, bool active) => Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: active ? ink : const Color(0xFFECEAE4),
            foregroundColor: active ? lime : muted,
            child: Text(
              num,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: active ? lime : muted,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? ink : muted,
            ),
          ),
        ],
      );

  void _showCheckoutDialog() => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Boleta de Venta',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MODO STORE S.A.C. - RUC 20608976541\nComprobante Electrónico (Demo)',
                style: TextStyle(color: muted, fontSize: 11),
              ),
              const Divider(height: 20),
              Text(
                'Cliente: ${widget.customerName.isEmpty ? 'Usuario MODO' : widget.customerName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text('Prendas en orden: $cartCount artículos'),
              const SizedBox(height: 4),
              Text(
                'Total Pagado: $formattedCartTotal',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 17, color: ink),
              ),
              const SizedBox(height: 12),
              const Text(
                '¡Pago procesado con éxito! Se ha registrado tu orden en el historial.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => cartQuantities.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Compra finalizada exitosamente!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: const Text('ACEPTAR'),
            ),
          ],
        ),
      );

  void _showProduct(Garment product) {
    Navigator.of(context).push(
      FadeSlideRoute<void>(
        builder: (_) => ProductDetailPage(
          product: product,
          catalog: catalogProducts,
          isFavorite: favorites.contains(product.id),
          onToggleFavorite: () => _toggleFavorite(product.id),
          onAddToCart: () => setState(() {
            cartQuantities[product.id] =
                (cartQuantities[product.id] ?? 0) + 1;
          }),
          onOpenCart: () => setState(() => tab = 3),
          onTryWithAi: () => setState(() => tab = 2),
        ),
      ),
    );
  }

  void _showPreview() => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: paper,
          title: const Text('¡Listo para probar!'),
          content: const Text(
            'Tus dos capturas están preparadas. La generación IA se conectará cuando se integre el servicio de probador virtual.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );

  Future<void> _pickCapture(bool front) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: lime,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sensors, size: 22, color: ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          front ? 'Foto Frontal con IA' : 'Foto Lateral con IA',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Usa el acelerómetro para calibrar el ángulo perpendicular a 90°',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text(
                  'Cámara con Sensor IA (Acelerómetro)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final Uint8List? bytes =
                      await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        SensorCameraGuideScreen(front: front, picker: picker),
                  ));
                  if (bytes != null) {
                    setState(() {
                      if (front) {
                        frontPhoto = bytes;
                      } else {
                        sidePhoto = bytes;
                      }
                    });
                    if (front) {
                      _processFitPrediction(bytes);
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: const BorderSide(color: line),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text(
                  'Elegir de la Galería',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final image = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 88,
                  );
                  if (image == null) return;
                  final bytes = await image.readAsBytes();
                  setState(() {
                    if (front) {
                      frontPhoto = bytes;
                    } else {
                      sidePhoto = bytes;
                    }
                  });
                  if (front) {
                    _processFitPrediction(bytes);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

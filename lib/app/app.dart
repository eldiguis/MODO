import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../features/admin/admin_login_barrier.dart';
import '../features/auth/login_screen.dart';
import '../features/shell/shop_shell.dart';

class ModaApp extends StatefulWidget {
  const ModaApp({super.key});

  @override
  State<ModaApp> createState() => _ModaAppState();
}

class _ModaAppState extends State<ModaApp> {
  bool signedIn = false;
  String customerName = '';
  bool firebaseConfigured = false;
  bool checkingSession = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _initFirebase();
    await _loadSavedSession();
    if (mounted) setState(() => checkingSession = false);
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLogged = prefs.getBool('signedIn') ?? false;
      final savedName = prefs.getString('customerName') ?? '';
      if (isLogged && mounted) {
        setState(() {
          signedIn = true;
          customerName =
              savedName.isNotEmpty ? savedName : 'Usuario MODO';
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSignIn(String name) async {
    setState(() {
      customerName = name;
      signedIn = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('signedIn', true);
      await prefs.setString('customerName', name);
    } catch (_) {}
  }

  Future<void> _handleSignOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('signedIn');
      await prefs.remove('customerName');
    } catch (_) {}
    if (mounted) {
      setState(() {
        signedIn = false;
        customerName = '';
      });
    }
  }

  Future<void> _initFirebase() async {
    if (!kIsWeb) {
      try {
        if (Firebase.apps.isEmpty) await Firebase.initializeApp();
        if (mounted) setState(() => firebaseConfigured = true);
      } catch (error, stackTrace) {
        debugPrint('Firebase initialization failed: $error\n$stackTrace');
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MODO',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: paper,
          colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: paper),
          fontFamily: 'Roboto',
        ),
        routes: {
          '/admin': (context) => const AdminLoginBarrier(),
        },
        home: checkingSession
            ? const Scaffold(
                backgroundColor: paper,
                body: Center(
                  child: CircularProgressIndicator(color: ink),
                ),
              )
            : kIsWeb
                ? const AdminLoginBarrier()
                : signedIn
                    ? ShopShell(
                        customerName: customerName,
                        firebaseConfigured: firebaseConfigured,
                        onSignOut: _handleSignOut,
                      )
                    : LoginScreen(onAuthenticated: _handleSignIn),
      );
}

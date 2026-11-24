import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../features/admin/admin_login_barrier.dart';
import '../features/auth/data/auth_repository.dart';
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
  String customerEmail = '';
  bool isGoogleAuth = false;
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
      if (firebaseConfigured || Firebase.apps.isNotEmpty) {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null && mounted) {
          final email = firebaseUser.email ?? '';
          final isGoogle = firebaseUser.providerData
              .any((p) => p.providerId == 'google.com');
          String name = firebaseUser.displayName ?? '';
          if (name.isEmpty && email.isNotEmpty) {
            name = email.split('@').first;
          }
          setState(() {
            signedIn = true;
            customerName = name.isNotEmpty ? name : 'Usuario MODO';
            customerEmail = email;
            isGoogleAuth = isGoogle;
          });
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final isLogged = prefs.getBool('signedIn') ?? false;
      final savedName = prefs.getString('customerName') ?? '';
      final savedEmail = prefs.getString('customerEmail') ?? '';
      final savedGoogle = prefs.getBool('isGoogleAuth') ?? false;
      if (isLogged && mounted) {
        setState(() {
          signedIn = true;
          customerName =
              savedName.isNotEmpty ? savedName : 'Usuario MODO';
          customerEmail = savedEmail;
          isGoogleAuth = savedGoogle;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSignIn(
    String name, {
    String email = '',
    bool isGoogle = false,
  }) async {
    setState(() {
      customerName = name;
      customerEmail = email;
      isGoogleAuth = isGoogle;
      signedIn = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('signedIn', true);
      await prefs.setString('customerName', name);
      await prefs.setString('customerEmail', email);
      await prefs.setBool('isGoogleAuth', isGoogle);
    } catch (_) {}
  }

  Future<void> _handleSignOut() async {
    try {
      await AuthRepository().signOut();
    } catch (_) {}
    if (mounted) {
      setState(() {
        signedIn = false;
        customerName = '';
        customerEmail = '';
        isGoogleAuth = false;
      });
    }
  }

  Future<void> _initFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: "AIzaSyBoSe_Wp83gBdFgq4Je-w3zQRnKT4iqHiw",
              authDomain: "modo-31d0e.firebaseapp.com",
              projectId: "modo-31d0e",
              storageBucket: "modo-31d0e.firebasestorage.app",
              messagingSenderId: "1061048654903",
              appId: "1:1061048654903:web:4276630759dfb5f2deb3b2",
            ),
          );
        } else {
          await Firebase.initializeApp();
        }
      }
      if (mounted) setState(() => firebaseConfigured = true);
    } catch (error, stackTrace) {
      debugPrint('Firebase initialization status: $error\n$stackTrace');
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
                        customerEmail: customerEmail,
                        isGoogleAuth: isGoogleAuth,
                        firebaseConfigured: firebaseConfigured,
                        onSignOut: _handleSignOut,
                      )
                    : LoginScreen(onAuthenticated: _handleSignIn),
      );
}

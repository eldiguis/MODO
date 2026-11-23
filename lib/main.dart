import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'core/network/http_overrides.dart';

// Re-export so test files that import package:flutter_application_1/main.dart
// can still reference ModaApp and ShopShell without changing their imports.
export 'app/app.dart' show ModaApp;
export 'features/shell/shop_shell.dart' show ShopShell;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = WikimediaFriendlyHttpOverrides();
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (e, stack) {
      debugPrint('Firebase init in main failed: $e\n$stack');
    }
  }
  runApp(const ModaApp());
}

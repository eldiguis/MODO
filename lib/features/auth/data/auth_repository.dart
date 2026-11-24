import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final String uid;
  final String name;
  final String email;
  final bool isGoogle;

  const AuthUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.isGoogle,
  });
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No se pudo obtener la información del usuario.',
      );
    }

    String name = user.displayName ?? '';
    if (name.isEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          name = (doc.data()?['name'] as String?) ?? '';
        }
      } catch (_) {}
    }
    if (name.isEmpty) {
      name = user.email?.split('@').first ?? 'Usuario MODO';
    }

    final authUser = AuthUser(
      uid: user.uid,
      name: name,
      email: user.email ?? email.trim(),
      isGoogle: false,
    );
    await _persistLocalSession(authUser);
    return authUser;
  }

  Future<AuthUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanName =
        name.trim().isNotEmpty ? name.trim() : cleanEmail.split('@').first;

    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No se pudo registrar el usuario.',
      );
    }

    try {
      await user.updateDisplayName(cleanName);
    } catch (_) {}

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': cleanName,
        'email': cleanEmail,
        'provider': 'password',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AuthRepository] Firestore profile save warning: $e');
    }

    final authUser = AuthUser(
      uid: user.uid,
      name: cleanName,
      email: cleanEmail,
      isGoogle: false,
    );
    await _persistLocalSession(authUser);
    return authUser;
  }

  Future<AuthUser> signInWithGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    final auth = account.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Error al iniciar sesión con Firebase usando Google.',
      );
    }

    final email = user.email ?? account.email;
    final name = user.displayName ??
        account.displayName ??
        (email.isNotEmpty ? email.split('@').first : 'Usuario Google');

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'photoUrl': user.photoURL ?? account.photoUrl,
        'provider': 'google',
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AuthRepository] Firestore Google profile save warning: $e');
    }

    final authUser = AuthUser(
      uid: user.uid,
      name: name,
      email: email,
      isGoogle: true,
    );
    await _persistLocalSession(authUser);
    return authUser;
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('signedIn');
      await prefs.remove('customerName');
      await prefs.remove('customerEmail');
      await prefs.remove('isGoogleAuth');
      await prefs.remove('uid');
    } catch (_) {}
  }

  Future<void> _persistLocalSession(AuthUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('signedIn', true);
      await prefs.setString('customerName', user.name);
      await prefs.setString('customerEmail', user.email);
      await prefs.setBool('isGoogleAuth', user.isGoogle);
      await prefs.setString('uid', user.uid);
    } catch (_) {}
  }

  static String formatAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Correo o contraseña incorrectos.';
        case 'email-already-in-use':
          return 'Este correo ya está registrado. Inicia sesión.';
        case 'weak-password':
          return 'La contraseña debe tener al menos 6 caracteres.';
        case 'invalid-email':
          return 'El formato de correo no es válido.';
        case 'network-request-failed':
          return 'Error de red. Revisa tu conexión a internet.';
        case 'too-many-requests':
          return 'Demasiados intentos fallidos. Intenta más tarde.';
        default:
          return error.message ?? 'Error de autenticación (${error.code}).';
      }
    }
    return 'Ocurrió un error inesperado al autenticar: $error';
  }
}

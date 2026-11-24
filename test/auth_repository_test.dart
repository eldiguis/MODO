import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/data/auth_repository.dart';

void main() {
  group('AuthRepository Error Formatting', () {
    test('formats user-not-found error correctly', () {
      final error = FirebaseAuthException(code: 'user-not-found');
      final msg = AuthRepository.formatAuthError(error);
      expect(msg, 'Correo o contraseña incorrectos.');
    });

    test('formats wrong-password error correctly', () {
      final error = FirebaseAuthException(code: 'wrong-password');
      final msg = AuthRepository.formatAuthError(error);
      expect(msg, 'Correo o contraseña incorrectos.');
    });

    test('formats invalid-credential error correctly', () {
      final error = FirebaseAuthException(code: 'invalid-credential');
      final msg = AuthRepository.formatAuthError(error);
      expect(msg, 'Correo o contraseña incorrectos.');
    });

    test('formats email-already-in-use error correctly', () {
      final error = FirebaseAuthException(code: 'email-already-in-use');
      final msg = AuthRepository.formatAuthError(error);
      expect(msg, 'Este correo ya está registrado. Inicia sesión.');
    });

    test('formats weak-password error correctly', () {
      final error = FirebaseAuthException(code: 'weak-password');
      final msg = AuthRepository.formatAuthError(error);
      expect(msg, 'La contraseña debe tener al menos 6 caracteres.');
    });

    test('formats invalid-email error correctly', () {
      final error = FirebaseAuthException(code: 'invalid-email');
      final msg = AuthRepository.formatAuthError(error);
      expect(msg, 'El formato de correo no es válido.');
    });

    test('formats network-request-failed error correctly', () {
      final error = FirebaseAuthException(code: 'network-request-failed');
      final msg = AuthRepository.formatAuthError(error);
      expect(msg, 'Error de red. Revisa tu conexión a internet.');
    });

    test('formats unknown errors safely', () {
      final error = Exception('Algo falló');
      final msg = AuthRepository.formatAuthError(error);
      expect(msg, contains('error inesperado'));
    });
  });
}

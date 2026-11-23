import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de datos para las medidas corporales del usuario y estado de privacidad.
class BodyMeasurements {
  final double heightCm;
  final double shoulderWidthCm;
  final double chestCm;
  final double waistCm;
  final double hipCm;
  final String recommendedSize;
  final double confidenceScore;
  final DateTime capturedAt;
  final bool privacyConsentAccepted;

  const BodyMeasurements({
    required this.heightCm,
    required this.shoulderWidthCm,
    required this.chestCm,
    required this.waistCm,
    required this.hipCm,
    required this.recommendedSize,
    required this.confidenceScore,
    required this.capturedAt,
    required this.privacyConsentAccepted,
  });

  Map<String, dynamic> toMap() => {
    'heightCm': heightCm,
    'shoulderWidthCm': shoulderWidthCm,
    'chestCm': chestCm,
    'waistCm': waistCm,
    'hipCm': hipCm,
    'recommendedSize': recommendedSize,
    'confidenceScore': confidenceScore,
    'capturedAt': capturedAt.toIso8601String(),
    'privacyConsentAccepted': privacyConsentAccepted,
  };

  factory BodyMeasurements.fromMap(Map<String, dynamic> map) => BodyMeasurements(
    heightCm: (map['heightCm'] as num?)?.toDouble() ?? 170.0,
    shoulderWidthCm: (map['shoulderWidthCm'] as num?)?.toDouble() ?? 42.0,
    chestCm: (map['chestCm'] as num?)?.toDouble() ?? 96.0,
    waistCm: (map['waistCm'] as num?)?.toDouble() ?? 80.0,
    hipCm: (map['hipCm'] as num?)?.toDouble() ?? 98.0,
    recommendedSize: map['recommendedSize'] as String? ?? 'M',
    confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.90,
    capturedAt: map['capturedAt'] != null
        ? DateTime.tryParse(map['capturedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    privacyConsentAccepted: map['privacyConsentAccepted'] as bool? ?? false,
  );

  static const String _prefKey = 'user_body_measurements_v1';
  static const String _consentKey = 'body_privacy_consent_accepted';

  /// Guarda las medidas en SharedPreferences locales.
  Future<void> saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(toMap()));
    await prefs.setBool(_consentKey, privacyConsentAccepted);
  }

  /// Carga las últimas medidas guardadas.
  static Future<BodyMeasurements?> loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return null;
      return BodyMeasurements.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Consulta si el usuario ya aprobó la política de privacidad biométrica.
  static Future<bool> hasAcceptedPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }
}

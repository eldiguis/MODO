import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/fitting_room/models/body_measurements.dart';
import 'package:flutter_application_1/features/fitting_room/services/fit_predictor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BodyMeasurements Model & Persistence Tests', () {
    test('Serializes and deserializes correctly', () {
      final now = DateTime.now();
      final original = BodyMeasurements(
        heightCm: 175.0,
        shoulderWidthCm: 44.0,
        chestCm: 98.0,
        waistCm: 82.0,
        hipCm: 99.0,
        recommendedSize: 'M',
        confidenceScore: 0.95,
        capturedAt: now,
        privacyConsentAccepted: true,
      );

      final map = original.toMap();
      final restored = BodyMeasurements.fromMap(map);

      expect(restored.heightCm, 175.0);
      expect(restored.shoulderWidthCm, 44.0);
      expect(restored.chestCm, 98.0);
      expect(restored.recommendedSize, 'M');
      expect(restored.privacyConsentAccepted, isTrue);
    });

    test('Saves and loads from SharedPreferences', () async {
      final sample = BodyMeasurements(
        heightCm: 180.0,
        shoulderWidthCm: 46.5,
        chestCm: 104.0,
        waistCm: 86.0,
        hipCm: 102.0,
        recommendedSize: 'L',
        confidenceScore: 0.93,
        capturedAt: DateTime.now(),
        privacyConsentAccepted: true,
      );

      await sample.saveLocal();

      final hasConsent = await BodyMeasurements.hasAcceptedPrivacy();
      expect(hasConsent, isTrue);

      final loaded = await BodyMeasurements.loadLocal();
      expect(loaded, isNotNull);
      expect(loaded!.recommendedSize, 'L');
      expect(loaded.chestCm, 104.0);
    });
  });

  group('FitPredictorService Algorithm Tests', () {
    test('Predicts size and generates accurate BodyMeasurements from image', () async {
      const service = FitPredictorService();

      // Creamos un archivo temporal simulando la foto capturada
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/test_fit_photo.jpg');
      await tempFile.writeAsBytes(List.generate(1500, (i) => (i % 256)));

      final result = await service.predictFromPhoto(
        imageFile: tempFile,
        userBaseHeightCm: 174.0,
        sensorAngleTilt: 1.5,
      );

      expect(result.recommendedSize, isIn(['S', 'M', 'L', 'XL']));
      expect(result.confidencePercent, inInclusiveRange(80, 100));
      expect(result.measurements.shoulderWidthCm, greaterThan(35.0));
      expect(result.measurements.chestCm, greaterThan(80.0));
      expect(result.measurements.privacyConsentAccepted, isTrue);

      // Limpieza
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });
  });
}

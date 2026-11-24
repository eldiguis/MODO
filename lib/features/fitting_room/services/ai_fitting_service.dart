import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/garment.dart';

enum AiProvider {
  aiStudio,
  nanoBanana,
}

class AiApiConfig {
  final AiProvider provider;
  final String apiKey;
  final String endpoint;

  const AiApiConfig({
    required this.provider,
    required this.apiKey,
    this.endpoint = '',
  });

  bool get isConfigured => apiKey.trim().isNotEmpty;
}

class AiGenerationResult {
  final bool success;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? description;
  final String? errorMessage;
  final String providerName;

  const AiGenerationResult({
    required this.success,
    this.imageUrl,
    this.imageBytes,
    this.description,
    this.errorMessage,
    required this.providerName,
  });
}

class AiFittingService {
  static const String _keyProvider = 'modo_ai_provider';
  static const String _keyAiStudioKey = 'modo_ai_studio_api_key';
  static const String _keyNanoBananaKey = 'modo_ai_nanobanana_api_key';
  static const String _keyNanoBananaEndpoint = 'modo_ai_nanobanana_endpoint';

  static const String defaultNanoBananaEndpoint =
      'https://api.nanobanana.com/v1/generate';

  const AiFittingService();

  Future<AiApiConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final providerStr = prefs.getString(_keyProvider) ?? 'aistudio';
      final provider = providerStr == 'nanobanana'
          ? AiProvider.nanoBanana
          : AiProvider.aiStudio;

      final apiKey = provider == AiProvider.nanoBanana
          ? (prefs.getString(_keyNanoBananaKey) ?? '')
          : (prefs.getString(_keyAiStudioKey) ?? '');

      final endpoint = prefs.getString(_keyNanoBananaEndpoint) ??
          defaultNanoBananaEndpoint;

      return AiApiConfig(
        provider: provider,
        apiKey: apiKey,
        endpoint: endpoint,
      );
    } catch (_) {
      return const AiApiConfig(
        provider: AiProvider.aiStudio,
        apiKey: '',
      );
    }
  }

  Future<void> saveConfig({
    required AiProvider provider,
    required String apiKey,
    String? endpoint,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyProvider,
      provider == AiProvider.nanoBanana ? 'nanobanana' : 'aistudio',
    );

    if (provider == AiProvider.nanoBanana) {
      await prefs.setString(_keyNanoBananaKey, apiKey.trim());
      if (endpoint != null && endpoint.trim().isNotEmpty) {
        await prefs.setString(_keyNanoBananaEndpoint, endpoint.trim());
      }
    } else {
      await prefs.setString(_keyAiStudioKey, apiKey.trim());
    }
  }

  Future<AiGenerationResult> generateLook({
    required Garment garment,
    Garment? bottomGarment,
    File? frontPhoto,
    File? sidePhoto,
  }) async {
    final config = await loadConfig();

    if (!config.isConfigured) {
      return const AiGenerationResult(
        success: false,
        errorMessage:
            'No has configurado tu API Key de Google AI Studio o NanoBanana. Ingresa tu clave para continuar.',
        providerName: 'Sin configurar',
      );
    }

    final outfitDesc = bottomGarment != null
        ? '${garment.name} (${garment.category}) combinado con ${bottomGarment.name} (${bottomGarment.category})'
        : '${garment.name} (${garment.category}, ${garment.tag})';

    try {
      if (config.provider == AiProvider.aiStudio) {
        return await _callAiStudio(config.apiKey, outfitDesc, frontPhoto, garment);
      } else {
        return await _callNanoBanana(
          config.apiKey,
          config.endpoint,
          outfitDesc,
          frontPhoto,
          garment,
        );
      }
    } catch (e) {
      debugPrint('[AiFittingService] Error: $e');
      return AiGenerationResult(
        success: false,
        errorMessage: 'Error al contactar la API de IA: $e',
        providerName: config.provider == AiProvider.aiStudio
            ? 'Google AI Studio'
            : 'NanoBanana',
      );
    }
  }

  Future<AiGenerationResult> _callAiStudio(
    String apiKey,
    String outfitDesc,
    File? userPhoto,
    Garment garment,
  ) async {
    // 1. Endpoint Gemini generateContent en Google AI Studio
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );

    final parts = <Map<String, dynamic>>[];

    // Si el usuario tiene foto frontal, adjuntamos como inline_data base64
    if (userPhoto != null && await userPhoto.exists()) {
      try {
        final bytes = await userPhoto.readAsBytes();
        final base64Image = base64Encode(bytes);
        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Image,
          }
        });
      } catch (_) {}
    }

    parts.add({
      'text':
          'Actúa como estilista de alta costura de MODO. Analiza la silueta del usuario y genera una descripción detallada de cómo le quedará esta prenda: "$outfitDesc". Da recomendaciones de calce, postura y estilo en un párrafo profesional y elegante.',
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 500,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      String text = 'Look generado con éxito por Google AI Studio.';
      if (candidates != null && candidates.isNotEmpty) {
        final partsList = candidates[0]['content']?['parts'] as List?;
        if (partsList != null && partsList.isNotEmpty) {
          text = partsList[0]['text'] ?? text;
        }
      }

      return AiGenerationResult(
        success: true,
        imageUrl: garment.image,
        description: text,
        providerName: 'Google AI Studio (Gemini 2.0)',
      );
    } else {
      final errorJson = jsonDecode(response.body);
      final message = errorJson['error']?['message'] ??
          'Código de error ${response.statusCode} de AI Studio.';
      return AiGenerationResult(
        success: false,
        errorMessage: 'Google AI Studio: $message',
        providerName: 'Google AI Studio',
      );
    }
  }

  Future<AiGenerationResult> _callNanoBanana(
    String apiKey,
    String endpoint,
    String outfitDesc,
    File? userPhoto,
    Garment garment,
  ) async {
    final url = Uri.parse(endpoint.isEmpty ? defaultNanoBananaEndpoint : endpoint);

    final Map<String, dynamic> body = {
      'prompt': 'Virtual try-on fashion lookbook: $outfitDesc',
      'garment_id': garment.id,
      'garment_name': garment.name,
      'garment_image': garment.image,
    };

    if (userPhoto != null && await userPhoto.exists()) {
      try {
        final bytes = await userPhoto.readAsBytes();
        body['user_image_base64'] = base64Encode(bytes);
      } catch (_) {}
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final imgUrl = data['image_url'] ?? data['output_url'] ?? garment.image;
      final desc = data['description'] ?? 'Generación completada con NanoBanana API.';

      return AiGenerationResult(
        success: true,
        imageUrl: imgUrl as String?,
        description: desc as String?,
        providerName: 'NanoBanana AI',
      );
    } else {
      return AiGenerationResult(
        success: false,
        errorMessage:
            'NanoBanana API error (${response.statusCode}): ${response.body}',
        providerName: 'NanoBanana AI',
      );
    }
  }
}

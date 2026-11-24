import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../services/ai_fitting_service.dart';

class AiConfigDialog extends StatefulWidget {
  final AiApiConfig initialConfig;
  final ValueChanged<AiApiConfig> onSaved;

  const AiConfigDialog({
    super.key,
    required this.initialConfig,
    required this.onSaved,
  });

  @override
  State<AiConfigDialog> createState() => _AiConfigDialogState();
}

class _AiConfigDialogState extends State<AiConfigDialog> {
  late AiProvider _provider;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _endpointCtrl;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _provider = widget.initialConfig.provider;
    _apiKeyCtrl = TextEditingController(text: widget.initialConfig.apiKey);
    _endpointCtrl = TextEditingController(
      text: widget.initialConfig.endpoint.isEmpty
          ? AiFittingService.defaultNanoBananaEndpoint
          : widget.initialConfig.endpoint,
    );
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _endpointCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final apiKey = _apiKeyCtrl.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa una API Key válida.')),
      );
      return;
    }

    final newConfig = AiApiConfig(
      provider: _provider,
      apiKey: apiKey,
      endpoint: _endpointCtrl.text.trim(),
    );

    widget.onSaved(newConfig);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: lime,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.key, size: 20, color: ink),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Configurar API de IA',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona el motor para la generación de imágenes en el probador:',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 14),

            // Selector de proveedor
            SegmentedButton<AiProvider>(
              segments: const [
                ButtonSegment(
                  value: AiProvider.aiStudio,
                  label: Text('AI Studio'),
                  icon: Icon(Icons.auto_awesome, size: 16),
                ),
                ButtonSegment(
                  value: AiProvider.nanoBanana,
                  label: Text('NanoBanana'),
                  icon: Icon(Icons.bolt, size: 16),
                ),
              ],
              selected: {_provider},
              onSelectionChanged: (set) {
                setState(() => _provider = set.first);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? ink : Colors.white,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? Colors.white : ink,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Información del proveedor
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD8EAA2)),
              ),
              child: Text(
                _provider == AiProvider.aiStudio
                    ? '💡 Con Google AI Studio (Gemini 2.0 / Imagen 3) obtén tu API key gratuita en aistudio.google.com.'
                    : '🍌 NanoBanana API permite generar renders de alta fidelidad para catálogos de moda.',
                style: const TextStyle(fontSize: 11, color: ink, height: 1.3),
              ),
            ),
            const SizedBox(height: 16),

            // Campo API Key
            const Text(
              'API Key',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _apiKeyCtrl,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                hintText: _provider == AiProvider.aiStudio
                    ? 'AIzaSy...'
                    : 'nb_live_...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: line),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureKey ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: muted,
                      ),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste, size: 18, color: ink),
                      tooltip: 'Pegar del portapapeles',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data != null && data.text != null) {
                          _apiKeyCtrl.text = data.text!.trim();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            if (_provider == AiProvider.nanoBanana) ...[
              const SizedBox(height: 14),
              const Text(
                'Endpoint NanoBanana (opcional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _endpointCtrl,
                decoration: InputDecoration(
                  hintText: AiFittingService.defaultNanoBananaEndpoint,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: line),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR', style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('GUARDAR CLAVE', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

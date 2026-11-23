import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _ink = Color(0xFF171717);
const Color _paper = Color(0xFFFAF9F6);
const Color _lime = Color(0xFFD7FF55);
const Color _line = Color(0xFFE6E4DE);
const Color _muted = Color(0xFF898780);

/// Bottom sheet para aceptar términos de privacidad y procesamiento de medidas corporales.
class PrivacyConsentSheet extends StatefulWidget {
  const PrivacyConsentSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PrivacyConsentSheet(),
    );
    return result ?? false;
  }

  @override
  State<PrivacyConsentSheet> createState() => _PrivacyConsentSheetState();
}

class _PrivacyConsentSheetState extends State<PrivacyConsentSheet> {
  bool _understandTerms = true;
  bool _allowSaving = true;

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('body_privacy_consent_accepted', true);
    await prefs.setString(
      'body_privacy_consent_timestamp',
      DateTime.now().toIso8601String(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: _line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _lime.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.privacy_tip_outlined, color: _ink, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Políticas de Privacidad',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    Text(
                      'Tratamiento de Medidas y Predictor de Talles',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Cómo usamos tus datos de imagen?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _ink),
                ),
                SizedBox(height: 6),
                Text(
                  '• El análisis de silueta para estimar contornos (hombros, pecho y cadera) se ejecuta para predecir tu talle recomendado.\n'
                  '• Tu fotografía se procesa exclusivamente en tu dispositivo.\n'
                  '• Podés borrar tus medidas guardadas en cualquier momento desde tu perfil.',
                  style: TextStyle(fontSize: 12, color: _ink, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CheckboxListTile(
            value: _understandTerms,
            activeColor: _ink,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Acepto los términos de procesamiento visual para predicción de talle.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _ink),
            ),
            onChanged: (val) => setState(() => _understandTerms = val ?? false),
          ),
          CheckboxListTile(
            value: _allowSaving,
            activeColor: _ink,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Guardar mis medidas calculadas para futuras compras.',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
            onChanged: (val) => setState(() => _allowSaving = val ?? false),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _line),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancelar', style: TextStyle(color: _muted)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _understandTerms ? _accept : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _line,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Aceptar y Continuar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

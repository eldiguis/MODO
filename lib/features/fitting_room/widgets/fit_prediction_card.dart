import 'package:flutter/material.dart';
import '../services/fit_predictor_service.dart';

const Color _ink = Color(0xFF171717);
const Color _paper = Color(0xFFFAF9F6);
const Color _lime = Color(0xFFD7FF55);
const Color _line = Color(0xFFE6E4DE);
const Color _muted = Color(0xFF898780);

class FitPredictionCard extends StatelessWidget {
  final FitPredictionResult result;
  final VoidCallback onRecalibrate;

  const FitPredictionCard({
    super.key,
    required this.result,
    required this.onRecalibrate,
  });

  @override
  Widget build(BuildContext context) {
    final m = result.measurements;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ink, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 13, color: _ink),
                    SizedBox(width: 4),
                    Text(
                      'FIT PREDICTOR IA',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${result.confidencePercent}% coincidencia',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Talle Recomendado: ',
                style: TextStyle(fontSize: 14, color: _muted),
              ),
              Text(
                result.recommendedSize,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _line),
                ),
                child: Text(
                  result.fitStyle,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.explanation,
            style: const TextStyle(fontSize: 12, color: _ink, height: 1.3),
          ),
          const SizedBox(height: 14),
          const Divider(color: _line, height: 1),
          const SizedBox(height: 12),
          // Resumen de medidas corporales estimadas
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _metricChip('Hombros', '${m.shoulderWidthCm} cm'),
              _metricChip('Pecho', '${m.chestCm} cm'),
              _metricChip('Cintura', '${m.waistCm} cm'),
              _metricChip('Cadera', '${m.hipCm} cm'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_outline, size: 12, color: _muted),
                  SizedBox(width: 4),
                  Text(
                    'Medidas guardadas bajo tu consentimiento',
                    style: TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onRecalibrate,
                child: const Text(
                  'Recalibrar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ink)),
      ],
    );
  }
}

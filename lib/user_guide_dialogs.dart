import 'package:flutter/material.dart';

const Color _kInk = Color(0xFF171717);
const Color _kLime = Color(0xFFD7FF55);
const Color _kPaper = Color(0xFFFAF9F6);
const Color _kMuted = Color(0xFF898780);
const Color _kLine = Color(0xFFE6E4DE);

/// ============================================================================
/// 1. MODAL DE BIENVENIDA / TOUR DE LA APP (Paso a paso para principiantes)
/// ============================================================================
class WelcomeTourDialog extends StatefulWidget {
  const WelcomeTourDialog({super.key});

  @override
  State<WelcomeTourDialog> createState() => _WelcomeTourDialogState();
}

class _WelcomeTourDialogState extends State<WelcomeTourDialog> {
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'badge': 'PASO 1 DE 4',
      'icon': Icons.storefront_rounded,
      'title': '¡Bienvenido a MODO!',
      'subtitle': 'Tu tienda de moda inteligente y accesible',
      'desc':
          'Diseñada para que cualquier persona pueda comprar y probar ropa de forma sencilla, intuitiva y sin complicaciones.',
      'tip':
          'Usa la barra inferior de navegación para moverte fácilmente entre Inicio, Tienda, Probador IA, Bolsa y Cuenta.',
    },
    {
      'badge': 'PASO 2 DE 4',
      'icon': Icons.checkroom_rounded,
      'title': 'Catálogo con 50 Prendas',
      'subtitle': 'Explora 5 categorías organizadas',
      'desc':
          'En la pestaña "Tienda" encontrarás 50 artículos clasificados en Hombre, Mujer, Niños, Calzado y Accesorios con filtros rápidos.',
      'tip':
          'Toca cualquier prenda para elegir tu talla (S a XXL), ver imágenes y comprobar stock en sucursales físicas.',
    },
    {
      'badge': 'PASO 3 DE 4',
      'icon': Icons.auto_awesome_rounded,
      'title': 'Probador Virtual con Sensor IA',
      'subtitle': 'Pruébate la ropa antes de comprar',
      'desc':
          '¿Dudas con tu talla? El probador virtual utiliza el acelerómetro de tu teléfono para calibrar la postura exacta a 90° con siluetas guía.',
      'tip':
          'Sostén el celular derecho a la altura del pecho. El marco se iluminará en verde cuando esté alineado para la foto.',
    },
    {
      'badge': 'PASO 4 DE 4',
      'icon': Icons.shopping_bag_rounded,
      'title': 'Tiendas Físicas y Compra Rápida',
      'subtitle': 'Stock con GPS y Boleta electrónica',
      'desc':
          'Consulta en segundos qué tienda física cercana tiene stock de tu prenda (Jockey Plaza, Salaverry o San Miguel) y genera tu boleta de prueba.',
      'tip':
          'En "Bolsa" podrás revisar tus artículos en 3 simples pasos y finalizar tu compra con comprobante digital.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera superior con acento
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              color: _kInk,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _kLime,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      step['badge'] as String,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _kInk,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Contenido del paso
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono ilustrado
                  Center(
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: _kPaper,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kLine, width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          step['icon'] as IconData,
                          size: 38,
                          color: _kInk,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Center(
                    child: Text(
                      step['title'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                        color: _kInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  Center(
                    child: Text(
                      step['subtitle'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    step['desc'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF3A3A3A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Caja de consejo útil
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7E8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD6E8B0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 18,
                          color: Color(0xFF385E18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step['tip'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E4E14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Indicador de puntos (Dots)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentStep == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentStep == i ? _kInk : _kLine,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Botones de acción inferior
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _kLine)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: TextButton.styleFrom(foregroundColor: _kMuted),
                      child: const Text('Anterior'),
                    )
                  else
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: _kMuted),
                      child: const Text('Saltar'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (isLast) {
                        Navigator.pop(context);
                      } else {
                        setState(() => _currentStep++);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _kInk,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      isLast ? '¡COMENZAR A EXPLORAR!' : 'Siguiente',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 2. GUÍA INTERACTIVA DEL PROBADOR IA (Spotlight con Fondo Opaco)
/// ============================================================================
class FittingRoomCoachDialog extends StatefulWidget {
  const FittingRoomCoachDialog({super.key});

  @override
  State<FittingRoomCoachDialog> createState() => _FittingRoomCoachDialogState();
}

class _FittingRoomCoachDialogState extends State<FittingRoomCoachDialog> {
  int _coachStep = 0;

  final List<Map<String, dynamic>> _coachSteps = [
    {
      'stepNum': 'PASO 1 DE 4',
      'title': '1. Elige tu prenda favorita',
      'action': 'Selección de Prenda',
      'instruction':
          'En la parte inferior de la pantalla encontrarás el carrusel de prendas. Toca una prenda para que el probador sepa qué ropa vas a probarte.',
      'spotlightType': 'garments',
    },
    {
      'stepNum': 'PASO 2 DE 4',
      'title': '2. Foto Frontal con Acelerómetro a 90°',
      'action': 'Captura Frontal Asistida',
      'instruction':
          'Toca el recuadro "01 FRONTAL". Al abrir la cámara, sostén el celular recto frente a ti a la altura del pecho. La mira de burbuja se centrará y el marco cambiará a VERDE LIMA cuando alcances 90° exactos.',
      'spotlightType': 'front',
    },
    {
      'stepNum': 'PASO 3 DE 4',
      'title': '3. Foto Lateral de Perfil',
      'action': 'Captura Lateral 3D',
      'instruction':
          'Toca el recuadro "02 LATERAL". Gira 90° de perfil para que la IA capture tu contorno completo y pueda calcular la caída real de la prenda.',
      'spotlightType': 'side',
    },
    {
      'stepNum': 'PASO 4 DE 4',
      'title': '4. Generar mi Look con IA',
      'action': 'Procesamiento Inteligente',
      'instruction':
          'Cuando ambas fotos tengan el check verde, el botón "GENERAR MI LOOK" se encenderá. Tócalo y la IA procesará tu fitting virtual listo para compartir o añadir a la bolsa.',
      'spotlightType': 'generate',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final step = _coachSteps[_coachStep];
    final isLast = _coachStep == _coachSteps.length - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xF2141414), // Fondo oscuro translúcido
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _kLime, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _kLime.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barra superior de foco
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _kLime,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          step['stepNum'] as String,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _kInk,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        step['action'] as String,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Representación visual con Foco (Spotlight Simulator)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: _buildSpotlightVisual(step['spotlightType'] as String),
                ),

                // Texto explicativo amigable
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    children: [
                      Text(
                        step['title'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step['instruction'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Indicador de puntos
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _coachSteps.length,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _coachStep == i ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _coachStep == i ? _kLime : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botones de avance
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
                  ),
                  child: Row(
                    children: [
                      if (_coachStep > 0)
                        TextButton(
                          onPressed: () => setState(() => _coachStep--),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white60,
                          ),
                          child: const Text('Anterior'),
                        )
                      else
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white60,
                          ),
                          child: const Text('Omitir'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          if (isLast) {
                            Navigator.pop(context);
                          } else {
                            setState(() => _coachStep++);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _kLime,
                          foregroundColor: _kInk,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        icon: Icon(
                          isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                          size: 16,
                          color: _kInk,
                        ),
                        label: Text(
                          isLast ? '¡ENTENDIDO, PROBAR AHORA!' : 'Siguiente paso',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotlightVisual(String type) {
    switch (type) {
      case 'garments':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kLime, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _garmentThumb(true, 'Seleccionada'),
              const SizedBox(width: 10),
              _garmentThumb(false, 'Opción 2'),
              const SizedBox(width: 10),
              _garmentThumb(false, 'Opción 3'),
            ],
          ),
        );

      case 'front':
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kLime, width: 2),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kLime,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.sensors, color: _kInk, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Acelerómetro 90° Activo',
                    style: TextStyle(
                      color: _kLime,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Icon(Icons.person_outline, size: 54, color: Colors.white),
              const SizedBox(height: 6),
              const Text(
                '01 FRONTAL (Cuerpo recto)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

      case 'side':
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kLime, width: 2),
          ),
          child: const Column(
            children: [
              Icon(Icons.accessibility_new_rounded, size: 54, color: _kLime),
              SizedBox(height: 8),
              Text(
                '02 LATERAL (Giro de perfil)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Permite a la IA simular volumen y ajuste lateral',
                style: TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ],
          ),
        );

      case 'generate':
      default:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kLime, width: 2),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, color: _kLime, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Foto Frontal Lista',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  SizedBox(width: 14),
                  Icon(Icons.check_circle, color: _kLime, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Foto Lateral Lista',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _kLime,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: _kInk, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'GENERAR MI LOOK',
                      style: TextStyle(
                        color: _kInk,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _garmentThumb(bool selected, String label) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: selected ? const Color(0x33D7FF55) : const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? _kLime : Colors.white24,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checkroom_rounded,
            size: 28,
            color: selected ? _kLime : Colors.white60,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: selected ? _kLime : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

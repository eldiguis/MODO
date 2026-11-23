import 'package:flutter/material.dart';

const Color _kInk = Color(0xFF171717);
const Color _kLime = Color(0xFFD7FF55);
const Color _kMuted = Color(0xFF898780);
const Color _kLine = Color(0xFFE6E4DE);

/// ============================================================================
/// Base reusable guide dialog card with concise steps
/// ============================================================================
class _ModularGuideDialog extends StatefulWidget {
  final String categoryBadge;
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> steps;
  final VoidCallback? onFinished;

  const _ModularGuideDialog({
    required this.categoryBadge,
    required this.title,
    required this.subtitle,
    required this.steps,
    this.onFinished,
  });

  @override
  State<_ModularGuideDialog> createState() => _ModularGuideDialogState();
}

class _ModularGuideDialogState extends State<_ModularGuideDialog> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final isLast = _currentStep == widget.steps.length - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
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
            // Header
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
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.categoryBadge,
                      style: const TextStyle(
                        color: _kInk,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_currentStep + 1} de ${widget.steps.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    tooltip: 'Cerrar',
                    onPressed: () {
                      if (widget.onFinished != null) {
                        widget.onFinished!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFF3F2EE),
                    foregroundColor: _kInk,
                    child: Icon(step['icon'] as IconData, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    step['title'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step['desc'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kMuted,
                      height: 1.45,
                    ),
                  ),
                  if (step['tip'] != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F6F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kLine),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: _kInk),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step['tip'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _kInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Navigation indicator & buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      widget.steps.length,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: index == _currentStep ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: index == _currentStep ? _kInk : _kLine,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('ATRÁS', style: TextStyle(color: _kMuted, fontSize: 12)),
                    ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: () {
                      if (isLast) {
                        if (widget.onFinished != null) {
                          widget.onFinished!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      } else {
                        setState(() => _currentStep++);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _kInk,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      isLast ? 'ENTENDIDO' : 'SIGUIENTE',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
/// 1. MODAL DE BIENVENIDA A LA APP (Corto y al grano)
/// ============================================================================
class WelcomeTourDialog extends StatelessWidget {
  final VoidCallback? onFinished;
  const WelcomeTourDialog({super.key, this.onFinished});

  @override
  Widget build(BuildContext context) {
    return _ModularGuideDialog(
      categoryBadge: 'BIENVENIDO',
      title: '¡Te damos la bienvenida a MODO!',
      subtitle: 'Tu tienda de moda inteligente',
      onFinished: onFinished,
      steps: const [
        {
          'icon': Icons.storefront_rounded,
          'title': 'Moda a tu manera',
          'desc':
              'Explora colecciones exclusivas, prueba combinaciones con IA y compra en segundos.',
          'tip': 'Muévete entre las pestañas inferiores para descubrir todas las funciones.',
        },
        {
          'icon': Icons.auto_awesome_rounded,
          'title': 'Experiencia completa',
          'desc':
              'Tienes a tu disposición el catálogo, probador con sensor y sincronización de tiendas.',
          'tip': 'Te mostraremos una breve guía en cada sección cuando la visites por primera vez.',
        },
      ],
    );
  }
}

/// ============================================================================
/// 2. GUÍA DE LA PÁGINA PRINCIPAL (INICIO)
/// ============================================================================
class HomeTabGuideDialog extends StatelessWidget {
  final VoidCallback? onFinished;
  const HomeTabGuideDialog({super.key, this.onFinished});

  @override
  Widget build(BuildContext context) {
    return _ModularGuideDialog(
      categoryBadge: 'INICIO',
      title: 'Pantalla de Inicio',
      subtitle: 'Lo más destacado de la semana',
      onFinished: onFinished,
      steps: const [
        {
          'icon': Icons.grid_view_rounded,
          'title': 'Selección de la semana',
          'desc':
              'Revisa las prendas en tendencia. Toca el corazón en cualquier tarjeta para guardarla en tus favoritos.',
          'tip': 'Toca cualquier prenda para ver detalles, disponibilidad y stock en tiendas.',
        },
        {
          'icon': Icons.style_outlined,
          'title': 'Swipe to Match',
          'desc':
              'Toca el banner superior para abrir el creador interactivo de conjuntos deslizando prendas.',
          'tip': 'Puedes crear looks en segundos y pasarlos directo a tu bolsa.',
        },
      ],
    );
  }
}

/// ============================================================================
/// 3. GUÍA DE LA TIENDA / CATÁLOGO
/// ============================================================================
class ShopTabGuideDialog extends StatelessWidget {
  final VoidCallback? onFinished;
  const ShopTabGuideDialog({super.key, this.onFinished});

  @override
  Widget build(BuildContext context) {
    return _ModularGuideDialog(
      categoryBadge: 'TIENDA',
      title: 'Catálogo y Filtros',
      subtitle: 'Explora toda la colección',
      onFinished: onFinished,
      steps: const [
        {
          'icon': Icons.filter_list_rounded,
          'title': 'Filtros por categoría',
          'desc':
              'Usa las pastillas superiores para ver Sacos, Pantalones, Calzado, Accesorios o tus Favoritos.',
          'tip': 'Las tallas se adaptan automáticamente al tipo de prenda que estés viendo.',
        },
        {
          'icon': Icons.favorite_rounded,
          'title': 'Tus Favoritos',
          'desc':
              'Marca las prendas que más te gusten con el corazón. Se guardan en tu dispositivo para verlas cuando quieras.',
          'tip': 'Filtra por "Favoritos" para ver rápidamente solo lo que guardaste.',
        },
      ],
    );
  }
}

/// ============================================================================
/// 4. GUÍA DEL PROBADOR IA (CON SENSOR ACELERÓMETRO)
/// ============================================================================
class FittingRoomCoachDialog extends StatelessWidget {
  final VoidCallback? onFinished;
  const FittingRoomCoachDialog({super.key, this.onFinished});

  @override
  Widget build(BuildContext context) {
    return _ModularGuideDialog(
      categoryBadge: 'PROBADOR IA',
      title: 'Probador Virtual con Sensor',
      subtitle: 'Calibra tu silueta a 90°',
      onFinished: onFinished,
      steps: const [
        {
          'icon': Icons.sensors_rounded,
          'title': 'Calibración con acelerómetro',
          'desc':
              'Sostén el celular recto frente a tu pecho. El sensor detecta la postura a 90° para una captura precisa.',
          'tip': 'El marco se iluminará en verde cuando alcances el ángulo perpendicular.',
        },
        {
          'icon': Icons.auto_awesome_rounded,
          'title': 'Foto frontal y lateral',
          'desc':
              'Toma una foto de frente y otra de perfil. La IA predecirá tu talla óptima recomendada.',
          'tip': 'Tus capturas son privadas y solo se procesan localmente para tu look.',
        },
      ],
    );
  }
}

/// ============================================================================
/// 5. GUÍA DE LA BOLSA DE COMPRAS
/// ============================================================================
class CartTabGuideDialog extends StatelessWidget {
  final VoidCallback? onFinished;
  const CartTabGuideDialog({super.key, this.onFinished});

  @override
  Widget build(BuildContext context) {
    return _ModularGuideDialog(
      categoryBadge: 'BOLSA',
      title: 'Tu Bolsa de Compras',
      subtitle: '3 pasos simples para comprar',
      onFinished: onFinished,
      steps: const [
        {
          'icon': Icons.shopping_basket_rounded,
          'title': 'Control de cantidades',
          'desc':
              'Aumenta o reduce unidades de cada prenda. El subtotal se recalcula en tiempo real.',
          'tip': 'Toca "Seguir Comprando" para volver a la tienda en cualquier momento.',
        },
        {
          'icon': Icons.receipt_long_rounded,
          'title': 'Boleta electrónica',
          'desc':
              'Toca "Finalizar Compra" para emitir tu comprobante digital con número de pedido oficial.',
          'tip': 'El proceso de demostración confirma tu pedido sin cargos reales.',
        },
      ],
    );
  }
}

/// ============================================================================
/// 6. GUÍA DE LA CUENTA Y AJUSTES
/// ============================================================================
class AccountTabGuideDialog extends StatelessWidget {
  final VoidCallback? onFinished;
  const AccountTabGuideDialog({super.key, this.onFinished});

  @override
  Widget build(BuildContext context) {
    return _ModularGuideDialog(
      categoryBadge: 'MI CUENTA',
      title: 'Perfil y Accesibilidad',
      subtitle: 'Configura la app a tu estilo',
      onFinished: onFinished,
      steps: const [
        {
          'icon': Icons.favorite_border_rounded,
          'title': 'Prendas guardadas',
          'desc':
              'Accede a tu carrusel de favoritos y consulta las prendas que reservaste.',
          'tip': 'Puedes tocar cualquier favorito para ver detalles o añadirlo a la bolsa.',
        },
        {
          'icon': Icons.accessibility_new_rounded,
          'title': 'Opciones de accesibilidad',
          'desc':
              'Activa texto grande, alto contraste o reducción de movimiento cuando lo necesites.',
          'tip': 'También puedes reabrir los tutoriales e instructivos desde la sección de ayuda.',
        },
      ],
    );
  }
}

/// ============================================================================
/// 7. GUÍA DE SWIPE TO MATCH
/// ============================================================================
class SwipeToMatchGuideDialog extends StatelessWidget {
  final VoidCallback? onFinished;
  const SwipeToMatchGuideDialog({super.key, this.onFinished});

  @override
  Widget build(BuildContext context) {
    return _ModularGuideDialog(
      categoryBadge: 'SWIPE TO MATCH',
      title: 'Outfit Matcher',
      subtitle: 'Arma tu cápsula en segundos',
      onFinished: onFinished,
      steps: const [
        {
          'icon': Icons.swipe_rounded,
          'title': 'Desliza para combinar',
          'desc':
              'Desliza horizontalmente la prenda superior o inferior para probar distintos estilos.',
          'tip': 'El indicador de armonía y el precio total se actualizan en vivo.',
        },
        {
          'icon': Icons.lock_outline_rounded,
          'title': 'Candado y Dado',
          'desc':
              'Bloquea con el candado una prenda favorita para cambiar solo la otra, o presiona el dado para un look aleatorio.',
          'tip': 'Agrega el conjunto completo a la bolsa o pruébalo con 1 solo toque.',
        },
      ],
    );
  }
}

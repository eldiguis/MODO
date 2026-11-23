import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';

const Color _kDarkBg = Color(0xFF141414);
const Color _kLime = Color(0xFFD7FF55);

/// Pantalla con cámara en vivo integrada (in-app) y guía de postura
/// superpuesta en tiempo real mediante el sensor Acelerómetro.
class SensorCameraGuideScreen extends StatefulWidget {
  final bool front;
  final ImagePicker picker;

  const SensorCameraGuideScreen({
    super.key,
    required this.front,
    required this.picker,
  });

  @override
  State<SensorCameraGuideScreen> createState() => _SensorCameraGuideScreenState();
}

class _SensorCameraGuideScreenState extends State<SensorCameraGuideScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitializing = true;
  String? _cameraErrorMessage;
  bool _isTakingPhoto = false;

  StreamSubscription<AccelerometerEvent>? _sensorSubscription;

  double _x = 0;
  double _y = 9.8;
  double _z = 0;

  double _pitch = 0; // Inclinación adelante/atrás (-90° a +90°)
  double _roll = 0;  // Inclinación lateral izquierda/derecha (-90° a +90°)
  bool _isAligned = false;
  bool _hasHapticFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAccelerometer();
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameras.isNotEmpty) {
        _startCameraController(_cameras[_selectedCameraIndex]);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensorSubscription?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ==========================================
  // INICIALIZACIÓN DE CÁMARA (SOLICITA PERMISOS AL ENTRAR)
  // ==========================================
  Future<void> _initCamera() async {
    setState(() {
      _isCameraInitializing = true;
      _cameraErrorMessage = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isCameraInitializing = false;
          _cameraErrorMessage =
              'No se detectaron cámaras en el dispositivo.';
        });
        return;
      }

      // Preferir cámara trasera por defecto para fotos de cuerpo completo,
      // o la primera si no se encuentra.
      int initialIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (initialIndex == -1) initialIndex = 0;
      _selectedCameraIndex = initialIndex;

      await _startCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        _cameraErrorMessage = 'Permiso denegado o error de cámara: $e';
      });
    }
  }

  Future<void> _startCameraController(CameraDescription cameraDescription) async {
    final oldController = _cameraController;
    if (oldController != null) {
      _cameraController = null;
      await oldController.dispose();
    }

    // Al inicializar el controller con enableAudio=false, Android solicita
    // de inmediato el permiso de CÁMARA en pantalla.
    final CameraController controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        _cameraErrorMessage = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        if (e.code == 'CameraAccessDenied' ||
            e.code == 'CameraAccessDeniedWithoutPrompt') {
          _cameraErrorMessage =
              'Se requiere permiso de acceso a la cámara para la guía en vivo.';
        } else {
          _cameraErrorMessage = 'Error de cámara (${e.code}): ${e.description}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        _cameraErrorMessage = 'Error al iniciar la cámara: $e';
      });
    }
  }

  Future<void> _toggleCameraLens() async {
    if (_cameras.length < 2 || _cameraController == null) return;
    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _selectedCameraIndex = nextIndex;
    setState(() => _isCameraInitializing = true);
    await _startCameraController(_cameras[_selectedCameraIndex]);
  }

  // ==========================================
  // INICIALIZACIÓN DEL ACELERÓMETRO
  // ==========================================
  void _initAccelerometer() {
    try {
      _sensorSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          if (!mounted) return;

          // En modo vertical:
          // Y mide gravedad hacia la base (~9.8 m/s²)
          // Z mide perpendicularidad a la pantalla (0 cuando está vertical)
          // X mide inclinación lateral
          final yAbs = event.y.abs().clamp(0.1, 100.0);
          final pitchVal = math.atan2(event.z, yAbs) * (180.0 / math.pi);
          final rollVal = math.atan2(event.x, yAbs) * (180.0 / math.pi);

          // Celular sostenido erguido: Y > 3.8 m/s², Pitch en +/-9° y Roll en +/-8°
          final isUpright = event.y > 3.8;
          final aligned =
              isUpright && (pitchVal.abs() <= 9.0) && (rollVal.abs() <= 8.0);

          if (aligned && !_hasHapticFired) {
            HapticFeedback.selectionClick();
            _hasHapticFired = true;
          } else if (!aligned) {
            _hasHapticFired = false;
          }

          setState(() {
            _x = event.x;
            _y = event.y;
            _z = event.z;
            _pitch = pitchVal;
            _roll = rollVal;
            _isAligned = aligned;
          });
        },
        onError: (e) {
          debugPrint('Error en acelerómetro: $e');
        },
      );
    } catch (e) {
      debugPrint('Excepción al suscribirse al acelerómetro: $e');
    }
  }

  // ==========================================
  // CAPTURA DE FOTO DIRECTA EN LA CÁMARA IN-APP
  // ==========================================
  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPhoto) {
      return;
    }

    try {
      setState(() => _isTakingPhoto = true);
      HapticFeedback.mediumImpact();

      final XFile photo = await controller.takePicture();
      final Uint8List bytes = await photo.readAsBytes();

      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar foto: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isTakingPhoto = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? file = await widget.picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (file != null) {
        final Uint8List bytes = await file.readAsBytes();
        if (!mounted) return;
        Navigator.of(context).pop(bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir la galería: $e')),
      );
    }
  }

  String _getGuidanceText() {
    if (_y <= 3.8) {
      return 'Coloca el celular de pie (vertical)';
    }
    if (_isAligned) {
      return '¡Ángulo óptimo (90°)! Presiona disparar';
    }
    if (_pitch > 9.0) {
      return 'Inclina el celular hacia adelante ⬇';
    }
    if (_pitch < -9.0) {
      return 'Inclina el celular hacia atrás ⬆';
    }
    if (_roll > 8.0) {
      return 'Endereza hacia la izquierda ↺';
    }
    if (_roll < -8.0) {
      return 'Endereza hacia la derecha ↻';
    }
    return 'Calibrando ángulo...';
  }

  @override
  Widget build(BuildContext context) {
    // Coordenadas para la burbuja de nivel
    final bubbleX = (_roll / 22.0).clamp(-1.0, 1.0) * 32.0;
    final bubbleY = (_pitch / 22.0).clamp(-1.0, 1.0) * 32.0;
    final stateColor = _isAligned ? _kLime : const Color(0xFFFFB74D);

    final bool isCameraReady =
        _cameraController != null && _cameraController!.value.isInitialized;

    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SENSOR DE POSTURA IA',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              widget.front ? '01 · CAPTURA FRONTAL' : '02 · CAPTURA LATERAL',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFB0B0B0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_cameras.length > 1 && isCameraReady)
            IconButton(
              icon: const Icon(Icons.flip_camera_android, color: Colors.white),
              tooltip: 'Cambiar cámara',
              onPressed: _toggleCameraLens,
            ),
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isAligned
                  ? const Color(0x33D7FF55)
                  : const Color(0x33FFB74D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: stateColor, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sensors,
                  size: 15,
                  color: stateColor,
                ),
                const SizedBox(width: 5),
                Text(
                  _isAligned ? 'ALINEADO' : 'AJUSTAR',
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // VISOR CON CÁMARA EN VIVO + GUÍA SUPERPUESTA
            // ==========================================
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAligned ? _kLime : const Color(0xFF333333),
                      width: _isAligned ? 2.5 : 1.0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      // 1. CÁMARA EN VIVO DE FONDO
                      if (isCameraReady)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize != null
                                ? _cameraController!.value.previewSize!.height
                                : 1080,
                            height: _cameraController!.value.previewSize != null
                                ? _cameraController!.value.previewSize!.width
                                : 1920,
                            child: CameraPreview(_cameraController!),
                          ),
                        )
                      else if (_cameraErrorMessage != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.videocam_off_outlined,
                                  size: 48,
                                  color: Colors.white54,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _cameraErrorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _initCamera,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reintentar permisos'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _kLime,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_isCameraInitializing || !isCameraReady)
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: _kLime),
                              SizedBox(height: 16),
                              Text(
                                'Iniciando cámara y sensor...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 2. SILUETA HUMANA DE REFERENCIA (SUPERPUESTA ENCIMA DE LA CÁMARA)
                      Center(
                        child: Opacity(
                          opacity: _isAligned ? 0.38 : 0.22,
                          child: Icon(
                            widget.front
                                ? Icons.person_outline
                                : Icons.accessibility_new_rounded,
                            size: 270,
                            color: _isAligned ? _kLime : Colors.white,
                          ),
                        ),
                      ),

                      // 3. LÍNEAS DE ENCUADRE TIPO VIEWFINDER
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: CustomPaint(
                            painter: _ViewfinderOverlayPainter(
                              isAligned: _isAligned,
                              color: stateColor,
                            ),
                          ),
                        ),
                      ),

                      // 4. NIVELADOR DE BURBUJA CENTRAL (ACELERÓMETRO)
                      Center(
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isAligned ? _kLime : Colors.white30,
                              width: 1.5,
                            ),
                            color: Colors.black38,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isAligned ? _kLime : Colors.white38,
                                    width: 1,
                                  ),
                                ),
                              ),
                              Container(width: 80, height: 1, color: Colors.white24),
                              Container(width: 1, height: 80, color: Colors.white24),
                              Transform.translate(
                                offset: Offset(bubbleX, bubbleY),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: stateColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: stateColor.withValues(alpha: 0.6),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: _isAligned
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.black,
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 5. LECTURAS EN TIEMPO REAL DEL ACELERÓMETRO
                      Positioned(
                        bottom: 12,
                        left: 10,
                        right: 10,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              'Pitch: ${_pitch.toStringAsFixed(1)}° | Roll: ${_roll.toStringAsFixed(1)}° | Accel: (${_x.toStringAsFixed(1)}, ${_y.toStringAsFixed(1)}, ${_z.toStringAsFixed(1)})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 6. FLASH BLANCO AL DISPARAR
                      if (_isTakingPhoto)
                        Positioned.fill(
                          child: Container(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // BARRA DE RETROALIMENTACIÓN DE POSTURA
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _isAligned
                      ? const Color(0x1AD7FF55)
                      : const Color(0x1AFFB74D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: stateColor, width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAligned
                          ? Icons.check_circle_outline
                          : Icons.rotate_right_outlined,
                      color: stateColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGuidanceText(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: _isAligned
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isAligned
                                ? 'La IA obtendrá las proporciones más precisas de tu prenda.'
                                : 'Mantén el celular erguido frente a ti a la altura del pecho.',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================
            // CONTROLES DE DISPARO IN-APP
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botón Galería
                  IconButton(
                    onPressed: _pickFromGallery,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white70,
                      size: 28,
                    ),
                    tooltip: 'Elegir de galería',
                  ),

                  // Botón Obturador Principal
                  GestureDetector(
                    onTap: isCameraReady && !_isTakingPhoto ? _capturePhoto : null,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isAligned ? _kLime : Colors.white,
                          width: 4,
                        ),
                        color: _isAligned ? _kLime : Colors.white24,
                        boxShadow: _isAligned
                            ? [
                                BoxShadow(
                                  color: _kLime.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  spreadRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: _isTakingPhoto
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt,
                                size: 34,
                                color: _isAligned ? Colors.black : Colors.white,
                              ),
                      ),
                    ),
                  ),

                  // Botón Cerrar
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 28,
                    ),
                    tooltip: 'Cancelar',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// Dibuja las esquinas de encuadre en el visor
class _ViewfinderOverlayPainter extends CustomPainter {
  final bool isAligned;
  final Color color;

  _ViewfinderOverlayPainter({required this.isAligned, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: isAligned ? 0.9 : 0.4)
      ..strokeWidth = isAligned ? 3.0 : 2.0
      ..style = PaintingStyle.stroke;

    const cornerLength = 22.0;

    // Superior Izquierda
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Superior Derecha
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Inferior Izquierda
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Inferior Derecha
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.isAligned != isAligned || oldDelegate.color != color;
  }
}

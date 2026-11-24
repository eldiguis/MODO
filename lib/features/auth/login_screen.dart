import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_colors.dart';
import '../../core/network/google_sign_in_web_stub.dart' as google_web
    if (dart.library.html) 'package:google_sign_in_web/web_only.dart';
import 'data/auth_repository.dart';

const String defaultGoogleClientId =
    '1061048654903-sgviubjufffv1b1j8ukj3f9b2j9cq2sa.apps.googleusercontent.com';

const String googleClientId = String.fromEnvironment(
  'GOOGLE_SIGN_IN_CLIENT_ID',
  defaultValue: defaultGoogleClientId,
);

/// Returns a Unsplash CDN URL for a photo [source] slug, or returns [source]
/// as-is if it already starts with http(s).
String photo(String source, {int width = 800}) {
  if (source.startsWith('https://') || source.startsWith('http://')) {
    return source;
  }
  return 'https://images.unsplash.com/$source?auto=format&fit=crop&w=$width&q=85';
}

typedef AuthSuccessCallback = void Function(
  String name, {
  String email,
  bool isGoogle,
});

class LoginScreen extends StatefulWidget {
  final AuthSuccessCallback onAuthenticated;
  final AuthRepository authRepository;

  LoginScreen({
    super.key,
    required this.onAuthenticated,
    AuthRepository? authRepository,
  }) : authRepository = authRepository ?? AuthRepository();

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  StreamSubscription<GoogleSignInAuthenticationEvent>? googleSubscription;
  bool registering = false;
  bool googleReady = false;
  bool obscurePassword = true;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    _initializeGoogle();
  }

  Future<void> _initializeGoogle() async {
    if (googleClientId.isEmpty) return;
    try {
      await GoogleSignIn.instance.initialize(clientId: googleClientId);
      googleSubscription = GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            final email = event.user.email;
            final name = event.user.displayName ??
                (email.isNotEmpty ? email.split('@').first : 'Usuario Google');
            widget.onAuthenticated(
              name,
              email: email,
              isGoogle: true,
            );
          }
        },
        onError: (Object error) => _message(
          'No se pudo iniciar con Google. Revisa la configuración OAuth.',
        ),
      );
      if (mounted) setState(() => googleReady = true);
    } catch (_) {
      if (mounted) setState(() => googleReady = false);
    }
  }

  @override
  void dispose() {
    googleSubscription?.cancel();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _continueWithGoogle() async {
    if (googleClientId.isEmpty) {
      _message('Falta configurar el OAuth Client ID de Google para esta app.');
      return;
    }
    if (kIsWeb) return;
    if (submitting) return;

    setState(() => submitting = true);
    try {
      final user = await widget.authRepository.signInWithGoogle();
      widget.onAuthenticated(
        user.name,
        email: user.email,
        isGoogle: true,
      );
    } catch (e, st) {
      debugPrint('Google Sign In error: $e\n$st');
      final msg = AuthRepository.formatAuthError(e);
      _message(msg);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (submitting) return;

    setState(() => submitting = true);
    final email = emailController.text.trim();
    final name = nameController.text.trim();
    final password = passwordController.text;

    try {
      final AuthUser user;
      if (registering) {
        user = await widget.authRepository.registerWithEmail(
          name: name,
          email: email,
          password: password,
        );
      } else {
        user = await widget.authRepository.signInWithEmail(
          email: email,
          password: password,
        );
      }
      widget.onAuthenticated(
        user.name,
        email: user.email,
        isGoogle: user.isGoogle,
      );
    } catch (e, st) {
      debugPrint('Email/Password Auth error: $e\n$st');
      final msg = AuthRepository.formatAuthError(e);
      _message(msg);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 760;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 28 : 16),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(wide ? 24 : 18),
                        border: Border.all(color: line),
                      ),
                      child: wide
                          ? Row(
                              children: [
                                Expanded(flex: 11, child: _welcomeVisual()),
                                Expanded(flex: 9, child: _formPanel()),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _welcomeVisual(compact: true),
                                ),
                                Expanded(
                                  flex: 7,
                                  child: SingleChildScrollView(
                                    child: _formPanel(compact: true),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

  Widget _welcomeVisual({bool compact = false}) => Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photo('photo-1539109136881-3be0616acf4b', width: 1100),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => Container(color: const Color(0xFFECEAE4)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xAA000000)],
                stops: [.35, 1],
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 20,
            child: Row(
              children: [
                const Text(
                  'MODO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    fontSize: 23,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 26,
            right: 24,
            bottom: compact ? 18 : 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compact
                      ? 'Tu estilo,\na tu manera.'
                      : 'Explore the\nbest collections.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.02,
                    letterSpacing: -1,
                    fontSize: compact ? 25 : 38,
                  ),
                ),
                const SizedBox(height: 8),
                if (!compact)
                  const Text(
                    'Descubre prendas pensadas para ti.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _formPanel({bool compact = false}) => Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 22 : 42,
          compact ? 20 : 42,
          compact ? 22 : 42,
          compact ? 20 : 34,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                registering ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                registering
                    ? 'Únete a MODO y encuentra tu próximo look.'
                    : 'Inicia sesión para continuar descubriendo.',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              SizedBox(height: compact ? 18 : 26),
              if (registering) ...[
                _input(
                  nameController,
                  'Nombre completo',
                  Icons.person_outline,
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Escribe tu nombre' : null,
                ),
                const SizedBox(height: 12),
              ],
              _input(
                emailController,
                'Correo electrónico',
                Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Escribe un correo válido' : null,
              ),
              const SizedBox(height: 12),
              _input(
                passwordController,
                'Contraseña',
                Icons.lock_outline,
                obscure: obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: muted,
                  ),
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Usa al menos 6 caracteres' : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          registering ? 'CREAR CUENTA' : 'INICIAR SESIÓN',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: .6,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider(color: line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'o continúa con',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                  const Expanded(child: Divider(color: line)),
                ],
              ),
              const SizedBox(height: 14),
              if (kIsWeb && googleClientId.isNotEmpty && googleReady)
                Center(
                  child: google_web.renderButton(
                    configuration: google_web.GSIButtonConfiguration(
                      theme: google_web.GSIButtonTheme.outline,
                      shape: google_web.GSIButtonShape.pill,
                      size: google_web.GSIButtonSize.large,
                      text: google_web.GSIButtonText.continueWith,
                      locale: 'es',
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: submitting ? null : _continueWithGoogle,
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    label: const Text('Continuar con Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ink,
                      side: const BorderSide(color: line),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      registering
                          ? '¿Ya tienes cuenta? '
                          : '¿No tienes una cuenta? ',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => registering = !registering),
                      child: Text(
                        registering ? 'Inicia sesión' : 'Regístrate',
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/admin'),
                    icon: const Icon(Icons.shield_outlined,
                        size: 14, color: muted),
                    label: const Text(
                      'Acceso Backoffice Administrador',
                      style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _input(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 19),
          suffixIcon: suffixIcon,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFFAFAF8),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: ink, width: 1.2),
          ),
          errorStyle: const TextStyle(fontSize: 10),
        ),
      );
}

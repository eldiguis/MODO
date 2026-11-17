import 'package:flutter/widgets.dart';

enum GSIButtonTheme { outline, filledBlue, filledBlack }

enum GSIButtonShape { rectangular, pill }

enum GSIButtonSize { large, medium, small }

enum GSIButtonText { signinWith, signupWith, continueWith, signin }

class GSIButtonConfiguration {
  const GSIButtonConfiguration({
    this.theme,
    this.shape,
    this.size,
    this.text,
    this.locale,
  });

  final GSIButtonTheme? theme;
  final GSIButtonShape? shape;
  final GSIButtonSize? size;
  final GSIButtonText? text;
  final String? locale;
}

Widget renderButton({GSIButtonConfiguration? configuration}) =>
    const SizedBox.shrink();

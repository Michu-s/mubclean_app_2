/// ============================================================================
/// mp_theme.dart
/// Constantes de diseño "Mercado Pago-inspired" para el módulo customer.
/// Material 3 con colores suaves, espaciados consistentes y tipografía clara.
/// ============================================================================

import 'package:flutter/material.dart';

/// Colores principales del tema
class MpColors {
  /// Azul primario para botones y elementos destacados
  static const Color primaryBlue = Color(0xFF1565C0);

  /// Fondo del scaffold - gris muy suave
  static const Color bgScaffold = Color(0xFFF7F9FC);

  /// Fondo de cards - blanco puro
  static const Color cardBg = Colors.white;

  /// Color de texto principal
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// Color de texto secundario/helper
  static const Color textSecondary = Color(0xFF6B7280);

  /// Color de texto deshabilitado
  static const Color textDisabled = Color(0xFF9CA3AF);

  /// Borde sutil para cards
  static const Color borderLight = Color(0xFFE5E7EB);

  /// Color de éxito/check
  static const Color success = Color(0xFF10B981);

  /// Color de error
  static const Color error = Color(0xFFEF4444);

  /// Color de warning
  static const Color warning = Color(0xFFF59E0B);
}

/// Espaciados consistentes (whitespace)
class MpSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Radios de borde para cards y botones
class MpRadius {
  static const double card = 16.0;
  static const double button = 12.0;
  static const double input = 12.0;
  static const double chip = 20.0;
}

/// Sombras sutiles para cards
class MpShadows {
  /// Sombra suave para cards
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  /// Sombra para elementos elevados (modals, etc)
  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Estilos de texto reutilizables
class MpTextStyles {
  /// Título de sección grande
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: MpColors.textPrimary,
    letterSpacing: -0.3,
  );

  /// Título de card
  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: MpColors.textPrimary,
  );

  /// Texto de cuerpo
  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: MpColors.textPrimary,
    height: 1.4,
  );

  /// Texto helper/caption
  static const TextStyle helper = TextStyle(
    fontSize: 13,
    color: MpColors.textSecondary,
    height: 1.3,
  );

  /// Texto de label pequeño
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: MpColors.textSecondary,
  );

  /// Texto de botón primario
  static const TextStyle buttonPrimary = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.3,
  );
}

/// Decoración común para InputFields
class MpInputDecoration {
  /// Decoración estándar para TextFields
  static InputDecoration standard({
    required String label,
    String? hint,
    IconData? prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: MpColors.primaryBlue, size: 22)
          : null,
      suffix: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MpSpacing.lg,
        vertical: MpSpacing.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MpRadius.input),
        borderSide: const BorderSide(color: MpColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MpRadius.input),
        borderSide: const BorderSide(color: MpColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MpRadius.input),
        borderSide: const BorderSide(color: MpColors.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MpRadius.input),
        borderSide: const BorderSide(color: MpColors.error),
      ),
      labelStyle: const TextStyle(color: MpColors.textSecondary),
      hintStyle: TextStyle(color: MpColors.textSecondary.withOpacity(0.6)),
    );
  }
}

/// ============================================================================
/// mp_cta_footer.dart
/// Barra inferior fija (sticky footer) con CTAs primario y secundario.
/// Incluye validaciones, helper text y estado loading.
/// ============================================================================

import 'package:flutter/material.dart';
import 'mp_theme.dart';

/// Footer fijo con botones de acción para el wizard
class MpCtaFooter extends StatelessWidget {
  /// Texto del botón primario
  final String primaryLabel;

  /// Callback del botón primario
  final VoidCallback? onPrimaryPressed;

  /// Si el botón primario está habilitado
  final bool isPrimaryEnabled;

  /// Si está en estado loading
  final bool isLoading;

  /// Si muestra el botón "Atrás"
  final bool showBack;

  /// Callback del botón "Atrás"
  final VoidCallback? onBackPressed;

  /// Helper text cuando está deshabilitado (ej: "Completa la dirección para continuar")
  final String? helperText;

  const MpCtaFooter({
    super.key,
    required this.primaryLabel,
    this.onPrimaryPressed,
    this.isPrimaryEnabled = true,
    this.isLoading = false,
    this.showBack = false,
    this.onBackPressed,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    // Determinar si mostrar el helper text
    final showHelper = !isPrimaryEnabled && helperText != null && !isLoading;

    return Container(
      padding: EdgeInsets.only(
        left: MpSpacing.lg,
        right: MpSpacing.lg,
        top: MpSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + MpSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: MpColors.cardBg,
        border: const Border(
          top: BorderSide(color: MpColors.borderLight, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Helper text (cuando está deshabilitado)
            if (showHelper)
              Padding(
                padding: const EdgeInsets.only(bottom: MpSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: MpColors.warning),
                    const SizedBox(width: MpSpacing.xs),
                    Flexible(
                      child: Text(
                        helperText!,
                        style: MpTextStyles.helper.copyWith(
                          color: MpColors.warning,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

            // Fila de botones
            Row(
              children: [
                // Botón "Atrás" (si aplica)
                if (showBack) ...[
                  TextButton(
                    onPressed: isLoading ? null : onBackPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: MpColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: MpSpacing.xl,
                        vertical: MpSpacing.lg,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios, size: 16),
                        SizedBox(width: MpSpacing.xs),
                        Text(
                          'Atrás',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MpSpacing.md),
                ],

                // Botón primario (expandido)
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (isPrimaryEnabled && !isLoading)
                          ? onPrimaryPressed
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MpColors.primaryBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: MpColors.primaryBlue
                            .withOpacity(0.4),
                        disabledForegroundColor: Colors.white.withOpacity(0.7),
                        elevation: isPrimaryEnabled ? 3 : 0,
                        shadowColor: MpColors.primaryBlue.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MpRadius.button),
                        ),
                      ),
                      child: isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: MpSpacing.md),
                                Text(
                                  'Enviando...',
                                  style: MpTextStyles.buttonPrimary,
                                ),
                              ],
                            )
                          : Text(
                              primaryLabel,
                              style: MpTextStyles.buttonPrimary,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

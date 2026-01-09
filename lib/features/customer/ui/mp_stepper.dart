/// ============================================================================
/// mp_stepper.dart
/// Stepper horizontal moderno de 3 pasos para el wizard de Nueva Solicitud.
/// Diseño "Mercado Pago-inspired" con círculos numerados, checks y líneas.
/// ============================================================================

import 'package:flutter/material.dart';
import 'mp_theme.dart';

/// Stepper horizontal moderno de 3 pasos
class MpStepper extends StatelessWidget {
  /// Paso actual (0, 1 o 2)
  final int currentStep;

  /// Labels de cada paso
  final List<String> labels;

  /// Texto helper debajo del stepper
  final String? helperText;

  const MpStepper({
    super.key,
    required this.currentStep,
    this.labels = const ['Dirección', 'Muebles', 'Confirmar'],
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MpSpacing.lg,
        vertical: MpSpacing.xl,
      ),
      color: MpColors.cardBg,
      child: Column(
        children: [
          // Fila del stepper
          Row(
            children: List.generate(labels.length * 2 - 1, (index) {
              // Índices pares = círculos, impares = líneas
              if (index.isEven) {
                final stepIndex = index ~/ 2;
                return _buildStepCircle(stepIndex);
              } else {
                final prevStep = index ~/ 2;
                return _buildStepLine(prevStep);
              }
            }),
          ),

          const SizedBox(height: MpSpacing.md),

          // Labels debajo de los círculos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              final isActive = index == currentStep;
              final isCompleted = index < currentStep;

              return Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive || isCompleted
                        ? MpColors.primaryBlue
                        : MpColors.textDisabled,
                  ),
                ),
              );
            }).toList(),
          ),

          // Helper text opcional
          if (helperText != null) ...[
            const SizedBox(height: MpSpacing.lg),
            Text(
              helperText!,
              style: MpTextStyles.helper.copyWith(fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Construye el círculo de un paso
  Widget _buildStepCircle(int stepIndex) {
    final isActive = stepIndex == currentStep;
    final isCompleted = stepIndex < currentStep;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? MpColors.success
            : isActive
            ? MpColors.primaryBlue
            : MpColors.borderLight,
        border: isActive
            ? Border.all(color: MpColors.primaryBlue.withOpacity(0.3), width: 3)
            : null,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text(
                '${stepIndex + 1}',
                style: TextStyle(
                  color: isActive ? Colors.white : MpColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  /// Construye la línea entre pasos
  Widget _buildStepLine(int prevStep) {
    final isCompleted = prevStep < currentStep;

    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: MpSpacing.sm),
        decoration: BoxDecoration(
          color: isCompleted ? MpColors.success : MpColors.borderLight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

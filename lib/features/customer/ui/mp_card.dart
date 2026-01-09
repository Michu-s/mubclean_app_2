/// ============================================================================
/// mp_card.dart
/// Card blanca estándar con radio 16, sombra suave y padding consistente.
/// Diseño "Mercado Pago-inspired".
/// ============================================================================

import 'package:flutter/material.dart';
import 'mp_theme.dart';

/// Widget de Card reutilizable con estilos del tema MP
class MpCard extends StatelessWidget {
  /// Contenido de la card
  final Widget child;

  /// Padding interno (default: 20)
  final EdgeInsetsGeometry? padding;

  /// Margen externo (default: none)
  final EdgeInsetsGeometry? margin;

  /// Título opcional en la parte superior de la card
  final String? title;

  /// Widget opcional al lado derecho del título
  final Widget? titleAction;

  const MpCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.title,
    this.titleAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: MpColors.cardBg,
        borderRadius: BorderRadius.circular(MpRadius.card),
        boxShadow: MpShadows.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MpRadius.card),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(20),
          child: title != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header de la card con título
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title!, style: MpTextStyles.cardTitle),
                        if (titleAction != null) titleAction!,
                      ],
                    ),
                    const SizedBox(height: MpSpacing.lg),
                    // Contenido principal
                    child,
                  ],
                )
              : child,
        ),
      ),
    );
  }
}

/// Variante de card para items de lista (muebles agregados)
class MpItemCard extends StatelessWidget {
  /// Badge de cantidad (ej: "2x")
  final String badge;

  /// Título del item
  final String title;

  /// Subtítulo/detalles (opcional)
  final String? subtitle;

  /// Si tiene foto adjunta
  final bool hasPhoto;

  /// Callback para editar
  final VoidCallback? onEdit;

  /// Callback para eliminar
  final VoidCallback? onDelete;

  const MpItemCard({
    super.key,
    required this.badge,
    required this.title,
    this.subtitle,
    this.hasPhoto = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: MpSpacing.md),
      decoration: BoxDecoration(
        color: MpColors.cardBg,
        borderRadius: BorderRadius.circular(MpRadius.card),
        boxShadow: MpShadows.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(MpSpacing.lg),
        child: Row(
          children: [
            // Badge de cantidad
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MpSpacing.md,
                vertical: MpSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: MpColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(MpSpacing.sm),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: MpColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: MpSpacing.lg),

            // Contenido principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),

                  // Subtítulo (si existe)
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: MpSpacing.xs),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MpTextStyles.helper,
                    ),
                  ],

                  // Tag de foto (si existe)
                  if (hasPhoto) ...[
                    const SizedBox(height: MpSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MpSpacing.sm,
                        vertical: MpSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: MpColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(MpSpacing.xs),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 12,
                            color: MpColors.success,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Incluye foto',
                            style: TextStyle(
                              fontSize: 11,
                              color: MpColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Acciones
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: MpColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: MpColors.error,
                      size: 20,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Eliminar',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

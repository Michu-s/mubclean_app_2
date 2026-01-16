/// ============================================================================
/// customer_wizard_screen.dart
/// Wizard de 3 pasos para crear una nueva solicitud de servicio.
/// Rediseño completo con estilo "Mercado Pago-inspired".
///
/// Paso 1: Dirección del servicio + Fecha
/// Paso 2: Agregar muebles/servicios
/// Paso 3: Confirmar y enviar
///
/// NOTA: Toda la lógica de negocio (Supabase, carrito) se mantiene intacta.
/// Solo se rediseña la UI.
///
/// FIX: Corregido para Flutter Web - usar XFile en lugar de File
/// FIX: Agregado MaterialLocalizations para DatePicker
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../../shared/models/marketplace_models.dart';
import 'ui/mp_theme.dart';
import 'ui/mp_card.dart';
import 'ui/mp_stepper.dart';
import 'ui/mp_cta_footer.dart';

/// Modelo para items en el carrito (borrador de muebles/servicios)
/// CORREGIDO: Usar XFile en lugar de File para compatibilidad con Flutter Web
class ItemBorrador {
  String servicioCatalogoId;
  String nombreServicio;
  String descripcion;
  int cantidad;
  List<XFile> fotos; // Cambiado de List<File> a List<XFile>

  ItemBorrador({
    required this.servicioCatalogoId,
    required this.nombreServicio,
    this.descripcion = '',
    this.cantidad = 1,
    required this.fotos,
  });
}

/// Pantalla principal del wizard de nueva solicitud
class CustomerWizardScreen extends StatefulWidget {
  final Negocio negocioSeleccionado;

  const CustomerWizardScreen({super.key, required this.negocioSeleccionado});

  @override
  State<CustomerWizardScreen> createState() => _CustomerWizardScreenState();
}

class _CustomerWizardScreenState extends State<CustomerWizardScreen> {
  // ============================================================================
  // VARIABLES DE ESTADO
  // ============================================================================

  final _supabase = Supabase.instance.client;

  /// Paso actual del wizard (0, 1 o 2)
  int _currentStep = 0;

  /// Estado de carga al enviar solicitud
  bool _isLoading = false;

  // Controladores de texto para Paso 1 (Dirección)
  final _calleCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _coloniaCtrl = TextEditingController();
  final _referenciasCtrl = TextEditingController();

  /// Fecha seleccionada para el servicio (default: mañana)
  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));

  /// Catálogo de servicios del negocio
  List<dynamic> _catalogo = [];

  /// Carrito de muebles/servicios agregados
  final List<ItemBorrador> _carrito = [];

  // ============================================================================
  // LIFECYCLE
  // ============================================================================

  @override
  void initState() {
    super.initState();
    // Inicializar formateo de fechas en español
    initializeDateFormatting('es', null);
    // Cargar catálogo de servicios del negocio
    _loadCatalogo();
  }

  @override
  void dispose() {
    // Limpiar controladores
    _calleCtrl.dispose();
    _numeroCtrl.dispose();
    _coloniaCtrl.dispose();
    _referenciasCtrl.dispose();
    super.dispose();
  }

  // ============================================================================
  // LÓGICA DE NEGOCIO (Actualizada para Flutter Web)
  // ============================================================================

  /// Carga el catálogo de servicios del negocio desde Supabase
  Future<void> _loadCatalogo() async {
    try {
      final res = await _supabase
          .from('servicios_catalogo')
          .select()
          .eq('negocio_id', widget.negocioSeleccionado.id)
          .eq('activo', true);
      if (mounted) {
        setState(() {
          _catalogo = res as List<dynamic>;
        });
      }
    } catch (e) {
      debugPrint("Error cargando catálogo: $e");
    }
  }

  /// Envía la solicitud completa a Supabase
  /// CORREGIDO: Usar bytes para subir archivos (compatible con Web)
  Future<void> _enviarSolicitud() async {
    // Validaciones previas
    if (_calleCtrl.text.isEmpty) {
      _showErrorSnackBar("Falta la dirección");
      return;
    }
    if (_carrito.isEmpty) {
      _showErrorSnackBar("Agrega al menos un mueble");
      return;
    }

    setState(() => _isLoading = true);

    final userId = _supabase.auth.currentUser!.id;
    final direccionCompleta =
        "${_calleCtrl.text} #${_numeroCtrl.text}, Col. ${_coloniaCtrl.text}. ${_referenciasCtrl.text}";

    try {
      // 1. Crear solicitud principal
      final solRes = await _supabase
          .from('solicitudes')
          .insert({
            'cliente_id': userId,
            'negocio_id': widget.negocioSeleccionado.id,
            'direccion_servicio': direccionCompleta,
            'fecha_solicitada_cliente': DateFormat(
              'yyyy-MM-dd',
            ).format(_fechaSeleccionada),
            'estado': 'pendiente',
          })
          .select()
          .single();
      final solicitudId = solRes['id'];

      // 2. Insertar cada item del carrito
      for (var item in _carrito) {
        final itemRes = await _supabase
            .from('items_solicitud')
            .insert({
              'solicitud_id': solicitudId,
              'servicio_catalogo_id': item.servicioCatalogoId,
              'descripcion_item': item.descripcion,
              'cantidad': item.cantidad,
            })
            .select()
            .single();
        final itemId = itemRes['id'];

        // 3. Subir fotos asociadas al item (CORREGIDO para Web)
        for (var i = 0; i < item.fotos.length; i++) {
          final xFile = item.fotos[i];
          final extension = xFile.name.split('.').last;
          final fileName = '$solicitudId/${itemId}_$i.$extension';

          // Leer bytes del archivo (funciona en Web y Mobile)
          final bytes = await xFile.readAsBytes();

          await _supabase.storage
              .from('muebles')
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(contentType: 'image/$extension'),
              );

          await _supabase.from('fotos_solicitud').insert({
            'item_solicitud_id': itemId,
            'foto_url': _supabase.storage
                .from('muebles')
                .getPublicUrl(fileName),
          });
        }
      }

      // Navegar de vuelta al home con mensaje de éxito
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Solicitud enviada! Te confirmaremos pronto."),
          backgroundColor: MpColors.success,
        ),
      );
    } catch (e) {
      debugPrint("Error enviando solicitud: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Error al enviar. Intenta de nuevo.");
      }
    }
  }

  /// Muestra un snackbar de error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: MpColors.error),
    );
  }

  // ============================================================================
  // VALIDACIONES
  // ============================================================================

  /// Valida si el Paso 1 está completo
  bool get _isStep1Valid =>
      _calleCtrl.text.isNotEmpty &&
      _numeroCtrl.text.isNotEmpty &&
      _coloniaCtrl.text.isNotEmpty;

  /// Valida si el Paso 2 está completo
  bool get _isStep2Valid => _carrito.isNotEmpty;

  /// Obtiene el helper text según el paso actual
  String? get _currentHelperText {
    switch (_currentStep) {
      case 0:
        return !_isStep1Valid ? 'Completa la dirección para continuar' : null;
      case 1:
        return !_isStep2Valid
            ? 'Agrega al menos un mueble para continuar'
            : null;
      default:
        return null;
    }
  }

  /// Determina si el botón primario está habilitado
  bool get _isPrimaryEnabled {
    switch (_currentStep) {
      case 0:
        return _isStep1Valid;
      case 1:
        return _isStep2Valid;
      case 2:
        return true;
      default:
        return false;
    }
  }

  // ============================================================================
  // NAVEGACIÓN DEL WIZARD
  // ============================================================================

  /// Avanza al siguiente paso o envía la solicitud
  void _onNextPressed() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _enviarSolicitud();
    }
  }

  /// Retrocede al paso anterior
  void _onBackPressed() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // ============================================================================
  // UI PRINCIPAL
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpColors.bgScaffold,

      // AppBar simple y limpio
      appBar: AppBar(
        title: const Text(
          'Nueva Solicitud',
          style: TextStyle(
            color: MpColors.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: MpColors.cardBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: MpColors.primaryBlue),
      ),

      // Body con scroll y contenido responsive
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Determinar si es desktop/tablet (ancho mayor a 600)
          final isWideScreen = constraints.maxWidth > 600;
          final contentWidth = isWideScreen ? 820.0 : constraints.maxWidth;

          return Column(
            children: [
              // Stepper horizontal fijo en la parte superior
              MpStepper(
                currentStep: _currentStep,
                helperText: 'Toma 1 minuto. Puedes editar antes de enviar.',
              ),

              // Contenido scrollable del paso actual
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWideScreen
                        ? (constraints.maxWidth - contentWidth) / 2
                        : MpSpacing.lg,
                    vertical: MpSpacing.lg,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: _buildStepContent(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // Footer fijo con CTAs
      bottomNavigationBar: MpCtaFooter(
        primaryLabel: _currentStep == 2 ? 'Enviar solicitud' : 'Siguiente',
        onPrimaryPressed: _onNextPressed,
        isPrimaryEnabled: _isPrimaryEnabled,
        isLoading: _isLoading,
        showBack: _currentStep > 0,
        onBackPressed: _onBackPressed,
        helperText: _currentHelperText,
      ),
    );
  }

  /// Construye el contenido del paso actual
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Direccion();
      case 1:
        return _buildStep2Muebles();
      case 2:
        return _buildStep3Confirmar();
      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================================
  // PASO 1: DIRECCIÓN DEL SERVICIO
  // ============================================================================

  Widget _buildStep1Direccion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card A: Dirección del servicio
        MpCard(
          title: 'Dirección del servicio',
          child: Column(
            children: [
              // Campo: Calle
              TextField(
                controller: _calleCtrl,
                onChanged: (_) => setState(() {}), // Actualizar validaciones
                decoration: MpInputDecoration.standard(
                  label: 'Calle',
                  prefixIcon: Icons.add_road,
                ),
              ),
              const SizedBox(height: MpSpacing.lg),

              // Row: Número + Colonia (responsive)
              LayoutBuilder(
                builder: (context, constraints) {
                  // En móvil (< 500): uno debajo del otro
                  final isNarrow = constraints.maxWidth < 500;

                  if (isNarrow) {
                    return Column(
                      children: [
                        TextField(
                          controller: _numeroCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.text,
                          maxLength: 5,
                          decoration: MpInputDecoration.standard(
                            label: 'Número',
                            prefixIcon: Icons.numbers,
                          ),
                        ),
                        const SizedBox(height: MpSpacing.lg),
                        TextField(
                          controller: _coloniaCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: MpInputDecoration.standard(
                            label: 'Colonia',
                            prefixIcon: Icons.location_city,
                          ),
                        ),
                      ],
                    );
                  }

                  // En desktop: lado a lado
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _numeroCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.text,
                          maxLength: 5,
                          decoration: MpInputDecoration.standard(
                            label: 'Número',
                            prefixIcon: Icons.numbers,
                          ),
                        ),
                      ),
                      const SizedBox(width: MpSpacing.lg),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _coloniaCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: MpInputDecoration.standard(
                            label: 'Colonia',
                            prefixIcon: Icons.location_city,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: MpSpacing.lg),

              // Campo: Referencias (multiline) - máximo 300 palabras
              TextField(
                controller: _referenciasCtrl,
                maxLines: 2,
                maxLength:
                    1500, // ~300 palabras aprox (5 caracteres promedio por palabra)
                decoration: MpInputDecoration.standard(
                  label: 'Referencias',
                  hint: 'Ej. casa blanca, reja negra, entre calles...',
                  prefixIcon: Icons.info_outline,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: MpSpacing.lg),

        // Card B: Fecha del servicio
        MpCard(
          title: 'Fecha del servicio',
          child: Column(
            children: [
              // Selector de fecha
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(MpRadius.input),
                child: Container(
                  padding: const EdgeInsets.all(MpSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: MpColors.borderLight),
                    borderRadius: BorderRadius.circular(MpRadius.input),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: MpColors.primaryBlue,
                        size: 24,
                      ),
                      const SizedBox(width: MpSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fecha seleccionada',
                              style: MpTextStyles.label,
                            ),
                            const SizedBox(height: MpSpacing.xs),
                            Text(
                              DateFormat(
                                'EEEE, d MMMM yyyy',
                                'es',
                              ).format(_fechaSeleccionada),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: MpColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: MpColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: MpSpacing.sm),
              // Helper text
              const Text(
                'Puedes cambiarla después',
                style: MpTextStyles.helper,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Abre el selector de fecha con MaterialLocalizations incluidas
  /// CORREGIDO: Agregar Localizations.override para incluir localizaciones de Material
  Future<void> _selectDate() async {
    // Mostrar DatePicker con localizaciones envueltas
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      // Usar el contexto actual para las localizaciones
      builder: (context, child) {
        // Envolver en Localizations para asegurar que MaterialLocalizations esté disponible
        return Localizations(
          locale: const Locale('es', 'ES'),
          delegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _fechaSeleccionada = date);
    }
  }

  // ============================================================================
  // PASO 2: MUEBLES
  // ============================================================================

  Widget _buildStep2Muebles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chip contador de muebles
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MpSpacing.lg,
            vertical: MpSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _carrito.isEmpty
                ? MpColors.borderLight
                : MpColors.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(MpRadius.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chair_outlined,
                size: 18,
                color: _carrito.isEmpty
                    ? MpColors.textSecondary
                    : MpColors.primaryBlue,
              ),
              const SizedBox(width: MpSpacing.sm),
              Text(
                _carrito.isEmpty
                    ? '0 muebles agregados'
                    : _carrito.length == 1
                    ? '1 mueble agregado'
                    : '${_carrito.length} muebles agregados',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _carrito.isEmpty
                      ? MpColors.textSecondary
                      : MpColors.primaryBlue,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: MpSpacing.xl),

        // Estado vacío o lista de items
        if (_carrito.isEmpty) _buildEmptyState() else _buildItemsList(),

        const SizedBox(height: MpSpacing.lg),

        // Botón agregar mueble (siempre visible)
        OutlinedButton.icon(
          onPressed: _abrirModalAgregarMueble,
          icon: const Icon(Icons.add),
          label: Text(
            _carrito.isEmpty ? 'Agregar mueble' : '+ Agregar otro mueble',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: MpColors.primaryBlue,
            side: const BorderSide(color: MpColors.primaryBlue),
            padding: const EdgeInsets.symmetric(vertical: MpSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MpRadius.button),
            ),
          ),
        ),
      ],
    );
  }

  /// Estado vacío cuando no hay muebles agregados
  Widget _buildEmptyState() {
    return MpCard(
      padding: const EdgeInsets.all(MpSpacing.xxl),
      child: Column(
        children: [
          // Ícono grande
          Container(
            padding: const EdgeInsets.all(MpSpacing.xl),
            decoration: BoxDecoration(
              color: MpColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.weekend_outlined,
              size: 48,
              color: MpColors.primaryBlue,
            ),
          ),
          const SizedBox(height: MpSpacing.xl),

          // Título
          const Text(
            'Agrega lo que deseas limpiar',
            style: MpTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MpSpacing.lg),

          // Bullets informativos
          _buildBulletPoint('Añade muebles o servicios al pedido'),
          _buildBulletPoint('Puedes subir foto (opcional)'),
          _buildBulletPoint('Confirmas todo en el último paso'),
        ],
      ),
    );
  }

  /// Bullet point individual
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MpSpacing.xs),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: MpColors.success,
          ),
          const SizedBox(width: MpSpacing.sm),
          Expanded(child: Text(text, style: MpTextStyles.body)),
        ],
      ),
    );
  }

  /// Lista de items del carrito
  Widget _buildItemsList() {
    return Column(
      children: _carrito.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return MpItemCard(
          badge: '${item.cantidad}x',
          title: item.nombreServicio,
          subtitle: item.descripcion,
          hasPhoto: item.fotos.isNotEmpty,
          onEdit: () => _editarItem(index),
          onDelete: () => _confirmarEliminarItem(index),
        );
      }).toList(),
    );
  }

  /// Confirma eliminación de un item
  void _confirmarEliminarItem(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MpRadius.card),
        ),
        title: const Text('¿Eliminar mueble?'),
        content: Text(
          'Se eliminará "${_carrito[index].nombreServicio}" del pedido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _carrito.removeAt(index));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MpColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  /// Edita un item existente (reabre el modal con datos precargados)
  void _editarItem(int index) {
    // Por simplicidad, abrimos el modal de agregar
    // En una implementación más completa, se precargarían los datos
    _abrirModalAgregarMueble(editIndex: index);
  }

  // ============================================================================
  // MODAL: AGREGAR MUEBLE
  // ============================================================================

  /// Abre el modal para agregar un mueble/servicio
  void _abrirModalAgregarMueble({int? editIndex}) {
    // Variables locales del modal
    dynamic selectedService;
    final notaCtrl = TextEditingController();
    int cantidad = 1;
    List<XFile> fotosTemporales = []; // Cambiado a XFile

    // Si estamos editando, precargar datos
    if (editIndex != null && editIndex < _carrito.length) {
      final item = _carrito[editIndex];
      selectedService = _catalogo.firstWhere(
        (s) => s['id'] == item.servicioCatalogoId,
        orElse: () => null,
      );
      notaCtrl.text = item.descripcion;
      cantidad = item.cantidad;
      fotosTemporales = List.from(item.fotos);
    }

    // Verificar que hay servicios disponibles
    if (_catalogo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este negocio aún no tiene servicios configurados.'),
          backgroundColor: MpColors.warning,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => Container(
          decoration: const BoxDecoration(
            color: MpColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + MpSpacing.lg,
            top: MpSpacing.sm,
            left: MpSpacing.xl,
            right: MpSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MpColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: MpSpacing.lg),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      editIndex != null ? 'Editar mueble' : 'Agregar mueble',
                      style: MpTextStyles.sectionTitle.copyWith(
                        color: MpColors.primaryBlue,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: MpColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MpSpacing.xl),

                // 1. Tipo de mueble (dropdown)
                DropdownButtonFormField(
                  isExpanded: true,
                  value: selectedService,
                  decoration: MpInputDecoration.standard(
                    label: 'Tipo de mueble',
                    prefixIcon: Icons.chair_outlined,
                  ),
                  items: _catalogo
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e['nombre'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setSt(() => selectedService = val),
                ),
                const SizedBox(height: MpSpacing.lg),

                // 2. Cantidad con +/-
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cantidad:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: MpSpacing.lg),
                    // Wrap con IntrinsicWidth o un Container fijo para evitar overflow si crece mucho
                    Container(
                      decoration: BoxDecoration(
                        color: MpColors.bgScaffold,
                        borderRadius: BorderRadius.circular(MpRadius.button),
                        border: Border.all(color: MpColors.borderLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: cantidad > 1
                                ? () => setSt(() => cantidad--)
                                : null,
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 40),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: MpSpacing.sm,
                            ),
                            child: Text(
                              '$cantidad',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: MpColors.primaryBlue,
                            ),
                            onPressed: () => setSt(() => cantidad++),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MpSpacing.lg),

                // 3. Detalles (multiline) - máximo 200 palabras
                TextField(
                  controller: notaCtrl,
                  maxLines: 2,
                  maxLength: 1000,
                  decoration: MpInputDecoration.standard(
                    label: 'Detalles (manchas, tela...)',
                    hint: 'Describe el estado o características',
                    prefixIcon: Icons.info_outline,
                  ),
                ),
                const SizedBox(height: MpSpacing.lg),

                // 4. Agregar foto (OBLIGATORIO)
                const Text(
                  "Evidencias visuales (Obligatorio)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 50,
                        );
                        if (image != null) {
                          setSt(() => fotosTemporales.add(image));
                        }
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Adjuntar foto'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MpColors.primaryBlue,
                        side: const BorderSide(color: MpColors.primaryBlue),
                      ),
                    ),
                    const SizedBox(width: MpSpacing.md),
                    const Flexible(
                      child: Text(
                        'Necesario para cotizar correctamente',
                        style: MpTextStyles.helper,
                      ),
                    ),
                  ],
                ),

                // Preview de fotos (CORREGIDO para Web)
                if (fotosTemporales.isNotEmpty) ...[
                  const SizedBox(height: MpSpacing.lg),
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: fotosTemporales.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(
                                right: MpSpacing.sm,
                              ),
                              width: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  MpSpacing.sm,
                                ),
                                color: Colors.grey[200],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  MpSpacing.sm,
                                ),
                                // Usar FutureBuilder para cargar imagen async
                                child: FutureBuilder<Widget>(
                                  future: _buildImagePreview(
                                    fotosTemporales[index],
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return snapshot.data!;
                                    }
                                    return const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setSt(
                                  () => fotosTemporales.removeAt(index),
                                ),
                                child: const CircleAvatar(
                                  backgroundColor: MpColors.error,
                                  radius: 10,
                                  child: Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: MpSpacing.xl),

                // Botón primario: Agregar al pedido
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selectedService == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Selecciona un tipo de mueble'),
                            backgroundColor: MpColors.error,
                          ),
                        );
                        return;
                      }

                      // VALIDACIÓN: FOTO OBLIGATORIA
                      if (fotosTemporales.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Debes adjuntar al menos una foto'),
                            backgroundColor: MpColors.error,
                          ),
                        );
                        return;
                      }

                      final nuevoItem = ItemBorrador(
                        servicioCatalogoId: selectedService['id'],
                        nombreServicio: selectedService['nombre'],
                        descripcion: notaCtrl.text,
                        cantidad: cantidad,
                        fotos: List.from(fotosTemporales),
                      );

                      setState(() {
                        if (editIndex != null) {
                          _carrito[editIndex] = nuevoItem;
                        } else {
                          _carrito.add(nuevoItem);
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MpColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MpRadius.button),
                      ),
                    ),
                    child: Text(
                      editIndex != null
                          ? 'Guardar cambios'
                          : 'Agregar al pedido',
                      style: MpTextStyles.buttonPrimary,
                    ),
                  ),
                ),

                // Botón secundario: Agregar y añadir otro
                if (editIndex == null) ...[
                  const SizedBox(height: MpSpacing.md),
                  TextButton(
                    onPressed: () {
                      if (selectedService == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Selecciona un tipo de mueble'),
                            backgroundColor: MpColors.error,
                          ),
                        );
                        return;
                      }

                      setState(() {
                        _carrito.add(
                          ItemBorrador(
                            servicioCatalogoId: selectedService['id'],
                            nombreServicio: selectedService['nombre'],
                            descripcion: notaCtrl.text,
                            cantidad: cantidad,
                            fotos: List.from(fotosTemporales),
                          ),
                        );
                      });

                      // Limpiar campos para agregar otro
                      setSt(() {
                        selectedService = null;
                        notaCtrl.clear();
                        cantidad = 1;
                        fotosTemporales.clear();
                      });

                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('¡Agregado! Añade otro mueble'),
                          backgroundColor: MpColors.success,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Text(
                      'Agregar y añadir otro',
                      style: TextStyle(
                        color: MpColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: MpSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye el preview de imagen compatible con Web y Mobile
  Future<Widget> _buildImagePreview(XFile xFile) async {
    if (kIsWeb) {
      // En Web, usar bytes
      final bytes = await xFile.readAsBytes();
      return Image.memory(bytes, fit: BoxFit.cover, width: 70, height: 70);
    } else {
      // En Mobile, usar path
      return Image.network(
        xFile.path,
        fit: BoxFit.cover,
        width: 70,
        height: 70,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.image, color: Colors.grey);
        },
      );
    }
  }

  // ============================================================================
  // PASO 3: CONFIRMAR
  // ============================================================================

  Widget _buildStep3Confirmar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card: Resumen del pedido
        MpCard(
          title: 'Resumen del pedido',
          titleAction: TextButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: const Text(
              'Editar',
              style: TextStyle(
                color: MpColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dirección
              _buildSummaryRow(
                Icons.location_on_outlined,
                'Dirección',
                '${_calleCtrl.text} #${_numeroCtrl.text}, Col. ${_coloniaCtrl.text}',
              ),

              if (_referenciasCtrl.text.isNotEmpty) ...[
                const SizedBox(height: MpSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    'Ref: ${_referenciasCtrl.text}',
                    style: MpTextStyles.helper,
                  ),
                ),
              ],

              const Divider(height: MpSpacing.xl),

              // Fecha
              _buildSummaryRow(
                Icons.calendar_today_outlined,
                'Fecha',
                DateFormat(
                  'EEEE, d MMMM yyyy',
                  'es',
                ).format(_fechaSeleccionada),
              ),

              const Divider(height: MpSpacing.xl),

              // Lista de muebles
              const Text(
                'Muebles a limpiar:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: MpColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: MpSpacing.sm),

              ...List.generate(_carrito.length, (index) {
                final item = _carrito[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: MpSpacing.xs),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MpSpacing.sm,
                          vertical: MpSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: MpColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(MpSpacing.xs),
                        ),
                        child: Text(
                          '${item.cantidad}x',
                          style: const TextStyle(
                            color: MpColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: MpSpacing.md),
                      Expanded(
                        child: Text(
                          item.nombreServicio,
                          style: MpTextStyles.body,
                        ),
                      ),
                      if (item.fotos.isNotEmpty)
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: 16,
                          color: MpColors.success,
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: MpSpacing.lg),

        // Trust block
        MpCard(
          padding: const EdgeInsets.all(MpSpacing.lg),
          child: Row(
            children: [
              _buildTrustBadge(
                Icons.verified_user_outlined,
                'Técnicos\nverificados',
              ),
              _buildTrustBadge(
                Icons.support_agent_outlined,
                'Soporte\ndisponible',
              ),
              _buildTrustBadge(
                Icons.check_circle_outline,
                'Confirmación\nal enviar',
              ),
            ],
          ),
        ),

        const SizedBox(height: MpSpacing.lg),

        // Nota final
        Container(
          padding: const EdgeInsets.all(MpSpacing.lg),
          decoration: BoxDecoration(
            color: MpColors.primaryBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(MpRadius.card),
            border: Border.all(
              color: MpColors.primaryBlue.withValues(alpha: 0.2),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: MpColors.primaryBlue, size: 20),
              SizedBox(width: MpSpacing.md),
              Expanded(
                child: Text(
                  'Recibirás confirmación cuando el equipo revise tu solicitud.',
                  style: TextStyle(
                    color: MpColors.primaryBlue,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Fila de resumen con ícono, label y valor
  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: MpColors.textSecondary),
        const SizedBox(width: MpSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: MpTextStyles.label),
              const SizedBox(height: MpSpacing.xs),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Badge de confianza
  Widget _buildTrustBadge(IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: MpColors.success, size: 28),
          const SizedBox(height: MpSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: MpColors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

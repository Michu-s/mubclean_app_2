import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Importante para fechas en español
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../shared/models/marketplace_models.dart';

// Modelo auxiliar local mejorado
class ItemBorrador {
  String servicioCatalogoId;
  String nombreServicio;
  String descripcion;
  int cantidad;
  List<File> fotos; // Lista de fotos locales

  ItemBorrador({
    required this.servicioCatalogoId,
    required this.nombreServicio,
    this.descripcion = '',
    this.cantidad = 1,
    required this.fotos,
  });
}

class CustomerWizardScreen extends StatefulWidget {
  final Negocio negocioSeleccionado;

  const CustomerWizardScreen({super.key, required this.negocioSeleccionado});

  @override
  State<CustomerWizardScreen> createState() => _CustomerWizardScreenState();
}

class _CustomerWizardScreenState extends State<CustomerWizardScreen> {
  final _supabase = Supabase.instance.client;
  int _currentStep = 0;
  bool _isLoading = false;

  // Paso 1: Datos Generales (Estructurados)
  final _calleCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _coloniaCtrl = TextEditingController();
  final _referenciasCtrl = TextEditingController();
  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));

  // Paso 2: Carrito de Compras
  List<dynamic> _catalogo = [];
  final List<ItemBorrador> _carrito = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null);
    _loadCatalogo();
  }

  Future<void> _loadCatalogo() async {
    try {
      final res = await _supabase
          .from('servicios_catalogo')
          .select()
          .eq('negocio_id', widget.negocioSeleccionado.id)
          .eq('activo', true);

      if (mounted)
        setState(() {
          _catalogo = res as List<dynamic>;
        });
    } catch (e) {
      debugPrint("Error cargando catálogo: $e");
    }
  }

  // --- DIÁLOGO PARA AGREGAR MUEBLE (CORREGIDO OVERFLOW) ---
  void _agregarItemDialog() {
    dynamic selectedService;
    final notaCtrl = TextEditingController();
    int cantidad = 1;
    List<File> fotosTemporales = [];

    // Validamos si hay catálogo antes de abrir
    if (_catalogo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Este negocio aún no tiene servicios configurados."),
        ),
      );
      _loadCatalogo();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el modal crezca con el teclado
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => Padding(
          padding: EdgeInsets.only(
            // Esto empuja el contenido hacia arriba cuando sale el teclado
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            // <--- AQUÍ ESTÁ LA SOLUCIÓN DEL OVERFLOW
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Agregar Mueble",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. Selector de Servicio
                if (_catalogo.isNotEmpty)
                  DropdownButtonFormField(
                    decoration: InputDecoration(
                      labelText: "Tipo de Mueble",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.chair),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
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
                  )
                else
                  const Center(
                    child: Text(
                      "Cargando lista de muebles...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),

                const SizedBox(height: 15),

                // 2. Descripción
                TextField(
                  controller: notaCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: "Detalles del mueble",
                    hintText: "Ej: Color beige, mancha de vino...",
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.info_outline),
                  ),
                ),
                const SizedBox(height: 15),

                // 3. Cantidad y Fotos
                Row(
                  children: [
                    const Text(
                      "Cantidad:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 20),
                            onPressed: () =>
                                cantidad > 1 ? setSt(() => cantidad--) : null,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                          Text(
                            "$cantidad",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            onPressed: () => setSt(() => cantidad++),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Botón Agregar Foto
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final source = await showDialog<ImageSource>(
                          context: context,
                          builder: (ctx) => SimpleDialog(
                            title: const Text("Seleccionar origen"),
                            children: [
                              SimpleDialogOption(
                                onPressed: () =>
                                    Navigator.pop(ctx, ImageSource.camera),
                                child: const Text("📷 Cámara"),
                              ),
                              SimpleDialogOption(
                                onPressed: () =>
                                    Navigator.pop(ctx, ImageSource.gallery),
                                child: const Text("🖼️ Galería"),
                              ),
                            ],
                          ),
                        );

                        if (source != null) {
                          final XFile? image = await picker.pickImage(
                            source: source,
                            imageQuality: 50,
                          );
                          if (image != null) {
                            setSt(() => fotosTemporales.add(File(image.path)));
                          }
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("FOTO"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[800],
                        elevation: 0,
                      ),
                    ),
                  ],
                ),

                // 4. Previsualización de Fotos
                if (fotosTemporales.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  const Text(
                    "Fotos agregadas:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: fotosTemporales.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                                image: DecorationImage(
                                  image: FileImage(fotosTemporales[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setSt(
                                  () => fotosTemporales.removeAt(index),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
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

                const SizedBox(height: 20),

                // Botón Guardar
                ElevatedButton(
                  onPressed: () {
                    if (selectedService != null) {
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
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text("⚠️ Selecciona un tipo de mueble"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text("AGREGAR AL PEDIDO"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- LÓGICA DE ENVÍO CON FOTOS ---
  Future<void> _enviarSolicitud() async {
    // Validación de campos individuales
    if (_calleCtrl.text.isEmpty ||
        _coloniaCtrl.text.isEmpty ||
        _numeroCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Completa la dirección (Calle, Número y Colonia)"),
        ),
      );
      return;
    }
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega al menos un mueble")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser!.id;

    final direccionCompleta =
        "${_calleCtrl.text.trim()} #${_numeroCtrl.text.trim()}, Col. ${_coloniaCtrl.text.trim()}. ${_referenciasCtrl.text.isNotEmpty ? 'Ref: ${_referenciasCtrl.text.trim()}' : ''}";

    try {
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

        for (var i = 0; i < item.fotos.length; i++) {
          final file = item.fotos[i];
          final fileExt = file.path.split('.').last;
          final fileName = '${solicitudId}/${itemId}_$i.$fileExt';

          await _supabase.storage.from('muebles').upload(fileName, file);
          final publicUrl = _supabase.storage
              .from('muebles')
              .getPublicUrl(fileName);

          await _supabase.from('fotos_solicitud').insert({
            'item_solicitud_id': itemId,
            'foto_url': publicUrl,
          });
        }
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 50),
              SizedBox(height: 10),
              Text("¡Solicitud Enviada!"),
            ],
          ),
          content: const Text(
            "El negocio revisará tus fotos y detalles para enviarte una cotización.",
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Entendido"),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Error envío: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al enviar: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pedir a ${widget.negocioSeleccionado.nombre}"),
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep++);
          } else {
            _enviarSolicitud();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _currentStep == 2
                                ? "ENVIAR SOLICITUD"
                                : "SIGUIENTE",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text("ATRÁS"),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          // PASO 1: DATOS
          Step(
            title: const Text("Ubicación"),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Ingresa los datos de tu domicilio",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 15),
                // Calle y Número
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _calleCtrl,
                        decoration: InputDecoration(
                          labelText: "Calle",
                          hintText: "Av. Reforma",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.add_road),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _numeroCtrl,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: "No. Ext/Int",
                          hintText: "123-A",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Colonia
                TextField(
                  controller: _coloniaCtrl,
                  decoration: InputDecoration(
                    labelText: "Colonia / Barrio",
                    hintText: "Ej. Centro",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.location_city),
                  ),
                ),
                const SizedBox(height: 15),
                // Referencias
                TextField(
                  controller: _referenciasCtrl,
                  decoration: InputDecoration(
                    labelText: "Referencias del domicilio",
                    hintText: "Casa azul, portón negro, frente al parque...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.directions),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                // Fecha
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: const Text("Fecha deseada del servicio"),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy', 'es').format(_fechaSeleccionada),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.calendar_today,
                      color: Colors.blue,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _fechaSeleccionada,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2026),
                        // locale: const Locale('es'), // Comentado para evitar error si no carga
                      );
                      if (d != null) setState(() => _fechaSeleccionada = d);
                    },
                  ),
                ),
              ],
            ),
          ),

          // PASO 2: MUEBLES (CARRITO)
          Step(
            title: const Text("Muebles"),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
            content: Column(
              children: [
                if (_carrito.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(30),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          Icons.weekend_outlined,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "No has agregado muebles",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const Text(
                          "Presiona el botón para agregar uno.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                ..._carrito.map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Badge(
                                label: Text("${item.cantidad}"),
                                backgroundColor: Colors.blue[800],
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.chair,
                                    size: 24,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nombreServicio,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (item.descripcion.isNotEmpty)
                                      Text(
                                        item.descripcion,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    setState(() => _carrito.remove(item)),
                              ),
                            ],
                          ),
                          if (item.fotos.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: item.fotos.length,
                                itemBuilder: (context, i) => Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                    image: DecorationImage(
                                      image: FileImage(item.fotos[i]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _agregarItemDialog,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("AGREGAR MUEBLE AL PEDIDO"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.blue[800]!, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // PASO 3: CONFIRMACIÓN
          Step(
            title: const Text("Confirmar"),
            isActive: _currentStep >= 2,
            content: Card(
              elevation: 0,
              color: Colors.grey[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.blue[800]),
                        const SizedBox(width: 10),
                        const Text(
                          "RESUMEN",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    const Text(
                      "📍 Dirección de Servicio",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_calleCtrl.text} #${_numeroCtrl.text}, Col. ${_coloniaCtrl.text}",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (_referenciasCtrl.text.isNotEmpty)
                      Text(
                        "Ref: ${_referenciasCtrl.text}",
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),

                    const SizedBox(height: 20),
                    const Text(
                      "📅 Fecha Programada",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'dd MMMM yyyy',
                        'es',
                      ).format(_fechaSeleccionada),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      "🛋️ Muebles a cotizar",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 5),
                    ..._carrito.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${e.cantidad}x ${e.nombreServicio}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (e.fotos.isNotEmpty)
                              Text(
                                " • ${e.fotos.length} fotos",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../shared/models/marketplace_models.dart';

class ItemBorrador {
  String servicioCatalogoId;
  String nombreServicio;
  String descripcion;
  int cantidad;
  List<File> fotos;

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

  final _calleCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _coloniaCtrl = TextEditingController();
  final _referenciasCtrl = TextEditingController();
  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));

  List<dynamic> _catalogo = [];
  final List<ItemBorrador> _carrito = [];

  // Colores Corporativos
  final Color _primaryBlue = const Color(0xFF1565C0);
  final Color _bgLight = const Color(0xFFF5F9FF);

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
      debugPrint("Error catálogo: $e");
    }
  }

  void _agregarItemDialog() {
    dynamic selectedService;
    final notaCtrl = TextEditingController();
    int cantidad = 1;
    List<File> fotosTemporales = [];

    if (_catalogo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Este negocio aún no tiene servicios configurados."),
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
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 25,
            left: 25,
            right: 25,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Agregar Mueble",
                      style: TextStyle(
                        color: _primaryBlue,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField(
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: "Tipo de Mueble",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.chair, color: _primaryBlue),
                    filled: true,
                    fillColor: _bgLight,
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
                const SizedBox(height: 15),

                TextField(
                  controller: notaCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: "Detalles (Manchas, tela...)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.info_outline, color: _primaryBlue),
                    filled: true,
                    fillColor: _bgLight,
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    const Text(
                      "Cantidad:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Container(
                      decoration: BoxDecoration(
                        color: _bgLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () =>
                                cantidad > 1 ? setSt(() => cantidad--) : null,
                          ),
                          Text(
                            "$cantidad",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, color: _primaryBlue),
                            onPressed: () => setSt(() => cantidad++),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 50,
                        );
                        if (image != null)
                          setSt(() => fotosTemporales.add(File(image.path)));
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("FOTO"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: _primaryBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),

                if (fotosTemporales.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: fotosTemporales.length,
                      itemBuilder: (context, index) => Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(fotosTemporales[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 14,
                            child: GestureDetector(
                              onTap: () =>
                                  setSt(() => fotosTemporales.removeAt(index)),
                              child: const CircleAvatar(
                                backgroundColor: Colors.red,
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
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
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
                            content: Text("Selecciona un tipo de mueble"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      "AGREGAR AL PEDIDO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _enviarSolicitud() async {
    if (_calleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Falta dirección")));
      return;
    }
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega al menos un servicio")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser!.id;
    final direccionCompleta =
        "${_calleCtrl.text} #${_numeroCtrl.text}, Col. ${_coloniaCtrl.text}. ${_referenciasCtrl.text}";

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
          final fileName =
              '${solicitudId}/${itemId}_$i.${item.fotos[i].path.split('.').last}';
          await _supabase.storage
              .from('muebles')
              .upload(fileName, item.fotos[i]);
          await _supabase.from('fotos_solicitud').insert({
            'item_solicitud_id': itemId,
            'foto_url': _supabase.storage
                .from('muebles')
                .getPublicUrl(fileName),
          });
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Solicitud Enviada"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text(
          "Nueva Solicitud",
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _primaryBlue),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: _primaryBlue),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryBlue, width: 2),
            ),
          ),
        ),
        child: Stepper(
          type: StepperType.horizontal,
          elevation: 0,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2)
              setState(() => _currentStep++);
            else
              _enviarSolicitud();
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 25),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: _primaryBlue.withOpacity(0.4),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentStep == 2
                                  ? "ENVIAR SOLICITUD"
                                  : "SIGUIENTE",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 15),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text(
                        "ATRÁS",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text("Ubicación"),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.editing,
              content: Column(
                children: [
                  TextField(
                    controller: _calleCtrl,
                    decoration: const InputDecoration(
                      labelText: "Calle",
                      prefixIcon: Icon(Icons.add_road),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _numeroCtrl,
                          decoration: const InputDecoration(
                            labelText: "Número",
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _coloniaCtrl,
                          decoration: const InputDecoration(
                            labelText: "Colonia",
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _referenciasCtrl,
                    decoration: const InputDecoration(labelText: "Referencias"),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Fecha del servicio",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      subtitle: Text(
                        DateFormat(
                          'dd MMMM yyyy',
                          'es',
                        ).format(_fechaSeleccionada),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Icon(Icons.calendar_today, color: _primaryBlue),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _fechaSeleccionada,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2026),
                        );
                        if (d != null) setState(() => _fechaSeleccionada = d);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text("Muebles"),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.editing,
              content: Column(
                children: [
                  if (_carrito.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Tu carrito está vacío",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ..._carrito.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${item.cantidad}x",
                            style: TextStyle(
                              color: _primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          item.nombreServicio,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          item.descripcion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              setState(() => _carrito.remove(item)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _agregarItemDialog,
                      icon: const Icon(Icons.add),
                      label: const Text("AGREGAR MUEBLE"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: _primaryBlue),
                        foregroundColor: _primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text("Fin"),
              isActive: _currentStep >= 2,
              content: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "RESUMEN DEL PEDIDO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    const Divider(height: 30),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "${_calleCtrl.text} #${_numeroCtrl.text}",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat(
                            'dd MMMM yyyy',
                            'es',
                          ).format(_fechaSeleccionada),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(
                          Icons.chair_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${_carrito.length} muebles agregados",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

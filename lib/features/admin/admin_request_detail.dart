import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../shared/models/marketplace_models.dart';

class AdminRequestDetail extends StatefulWidget {
  final Solicitud solicitud;

  const AdminRequestDetail({super.key, required this.solicitud});

  @override
  State<AdminRequestDetail> createState() => _AdminRequestDetailState();
}

class _AdminRequestDetailState extends State<AdminRequestDetail> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Datos
  late Solicitud _solicitudActual; // Usamos esto para tener datos frescos
  List<Map<String, dynamic>> _items = [];
  List<dynamic> _empleados = [];
  Map<String, dynamic>? _evidenciaFinal;

  // Controladores Cotización
  final Map<String, TextEditingController> _preciosControllers = {};
  double _totalCalculado = 0.0;

  // Controladores Agenda
  String? _empleadoSeleccionadoId;
  DateTime? _fechaAgenda;
  TimeOfDay? _horaAgenda;

  @override
  void initState() {
    super.initState();
    _solicitudActual = widget.solicitud; // Inicializar con lo que viene
    _fechaAgenda = widget.solicitud.fechaSolicitada;
    _horaAgenda = const TimeOfDay(hour: 9, minute: 0);
    _fetchCompleteDetails();
  }

  Future<void> _fetchCompleteDetails() async {
    try {
      debugPrint("🔍 Actualizando detalles...");

      // 1. REFRESCAR LA SOLICITUD (Para ver si el cliente ya aceptó)
      final solicitudFresca = await _supabase
          .from('solicitudes')
          .select()
          .eq('id', widget.solicitud.id)
          .single();

      // 2. Cargar Items + Fotos
      final itemsRes = await _supabase
          .from('items_solicitud')
          .select('*, servicios_catalogo(nombre), fotos_solicitud(foto_url)')
          .eq('solicitud_id', widget.solicitud.id);

      // 3. Cargar Empleados (Solo si el estado FRESCO es 'aceptada')
      // Convertimos el estado de texto a Enum para comparar
      final estadoFresco = EstadoSolicitud.values.firstWhere(
        (e) => e.name == solicitudFresca['estado'],
      );

      if (estadoFresco == EstadoSolicitud.aceptada) {
        final empsRes = await _supabase
            .from('empleados_negocio')
            .select('id, perfiles(nombre_completo)')
            .eq('negocio_id', widget.solicitud.negocioId)
            .eq('activo', true);
        _empleados = empsRes as List<dynamic>;
      }

      // 4. Cargar Evidencia
      if (estadoFresco == EstadoSolicitud.completada) {
        final eviRes = await _supabase
            .from('evidencia_final')
            .select()
            .eq('solicitud_id', widget.solicitud.id)
            .maybeSingle();
        _evidenciaFinal = eviRes;
      }

      if (mounted) {
        setState(() {
          _solicitudActual = Solicitud.fromJson(
            solicitudFresca,
          ); // Actualizamos la UI
          _items = List<Map<String, dynamic>>.from(itemsRes);

          for (var item in _items) {
            final precio = item['precio_unitario'] ?? 0;
            _preciosControllers[item['id']] = TextEditingController(
              text: precio > 0 ? precio.toString() : '',
            );
          }
          _calcularTotal();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ ERROR CARGANDO DETALLES: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calcularTotal() {
    double suma = 0;
    _preciosControllers.forEach((key, ctrl) {
      suma += double.tryParse(ctrl.text) ?? 0;
    });
    setState(() => _totalCalculado = suma);
  }

  // --- ACCIONES ---

  // 1. Enviar Cotización
  Future<void> _enviarCotizacion() async {
    if (_totalCalculado <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("El total no puede ser 0")));
      return;
    }
    setState(() => _isLoading = true);
    try {
      for (var itemId in _preciosControllers.keys) {
        final precio = double.tryParse(_preciosControllers[itemId]!.text) ?? 0;
        await _supabase
            .from('items_solicitud')
            .update({'precio_unitario': precio})
            .eq('id', itemId);
      }
      await _supabase
          .from('solicitudes')
          .update({'precio_total': _totalCalculado, 'estado': 'cotizada'})
          .eq('id', widget.solicitud.id);

      // Recargar para reflejar cambio de estado
      await _fetchCompleteDetails();

      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Cotización enviada")));
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Agendar Cita
  Future<void> _agendarCita() async {
    if (_empleadoSeleccionadoId == null ||
        _fechaAgenda == null ||
        _horaAgenda == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona técnico, fecha y hora")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('solicitudes')
          .update({
            'tecnico_asignado_id': _empleadoSeleccionadoId,
            'fecha_agendada_final': DateFormat(
              'yyyy-MM-dd',
            ).format(_fechaAgenda!),
            'hora_agendada_final':
                '${_horaAgenda!.hour}:${_horaAgenda!.minute}:00',
            'estado': 'agendada',
          })
          .eq('id', widget.solicitud.id);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Cita Agendada y Técnico Notificado!")),
      );
    } catch (e) {
      debugPrint("Error agendando: $e");
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Helper para seleccionar Fecha/Hora
  Future<void> _seleccionarFechaHora() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaAgenda ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _horaAgenda ?? TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _fechaAgenda = date;
          _horaAgenda = time;
        });
      }
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    // IMPORTANTE: Usamos _solicitudActual en lugar de widget.solicitud
    final estado = _solicitudActual.estado;
    final esModoCotizar = estado == EstadoSolicitud.pendiente;

    return Scaffold(
      appBar: AppBar(
        title: Text("Gestión #${_solicitudActual.id.substring(0, 4)}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCompleteDetails,
            tooltip: "Actualizar estado",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info del Estado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Estado: ${estado.name.toUpperCase()}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Info Dirección
                  const Text(
                    "📍 Dirección",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    _solicitudActual.direccion,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Divider(),

                  // ITEMS Y COTIZACIÓN
                  const Text(
                    "Muebles a Cotizar",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),

                  ..._items.map((item) {
                    final fotos =
                        item['fotos_solicitud'] as List<dynamic>? ?? [];
                    final controller = _preciosControllers[item['id']];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${item['cantidad']}x ${item['servicios_catalogo']['nombre']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (item['descripcion_item'] != null)
                              Text(
                                item['descripcion_item'],
                                style: TextStyle(color: Colors.grey[700]),
                              ),

                            const SizedBox(height: 10),

                            // Visor de Fotos
                            if (fotos.isNotEmpty)
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: fotos.length,
                                  itemBuilder: (ctx, i) {
                                    final url = fotos[i]['foto_url'];
                                    return GestureDetector(
                                      onTap: () => showDialog(
                                        context: context,
                                        builder: (_) =>
                                            Dialog(child: Image.network(url)),
                                      ),
                                      child: Container(
                                        width: 100,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          image: DecorationImage(
                                            image: NetworkImage(url),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            else
                              const Text(
                                "Sin fotos",
                                style: TextStyle(color: Colors.grey),
                              ),

                            const SizedBox(height: 10),

                            // Campo de Precio
                            if (esModoCotizar)
                              TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _calcularTotal(),
                                decoration: const InputDecoration(
                                  prefixText: "\$ ",
                                  labelText: "Precio Unitario",
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              )
                            else
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "\$${item['precio_unitario']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // TOTAL
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "TOTAL:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        "\$${_totalCalculado.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- BOTONES DE ACCIÓN ---

                  // 1. COTIZAR (Si está pendiente)
                  if (esModoCotizar)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _enviarCotizacion,
                        child: const Text("ENVIAR COTIZACIÓN"),
                      ),
                    ),

                  // 2. MENSAJE DE ESPERA (Si ya cotizó pero cliente no ha aceptado)
                  if (estado == EstadoSolicitud.cotizada)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.orange[100],
                      child: const Text(
                        "⏳ Esperando que el cliente acepte la oferta...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                    ),

                  // 3. AGENDAR (Si fue aceptada)
                  if (estado == EstadoSolicitud.aceptada) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.green[100],
                      child: const Text(
                        "✅ ¡El cliente aceptó! Procede a agendar.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "🗓️ Agendar Servicio",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // A. Selector Fecha/Hora
                    InkWell(
                      onTap: _seleccionarFechaHora,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Fecha y Hora de la Cita",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_month),
                        ),
                        child: Text(
                          _fechaAgenda == null
                              ? "Seleccionar..."
                              : "${DateFormat('dd/MM/yyyy').format(_fechaAgenda!)} a las ${_horaAgenda!.format(context)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // B. Selector Técnico
                    if (_empleados.isEmpty)
                      const Text(
                        "⚠️ No tienes técnicos. Ve a 'Mi Equipo' para agregar uno.",
                        style: TextStyle(color: Colors.red),
                      )
                    else
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Asignar Técnico",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        value: _empleadoSeleccionadoId,
                        items: _empleados
                            .map(
                              (emp) => DropdownMenuItem(
                                value: emp['id'].toString(),
                                child: Text(
                                  emp['perfiles']['nombre_completo'] ??
                                      "Sin Nombre",
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _empleadoSeleccionadoId = val),
                      ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _agendarCita,
                        icon: const Icon(Icons.check_circle),
                        label: const Text("CONFIRMAR CITA Y ASIGNAR"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],

                  // 4. VER RESULTADO (Si ya terminó)
                  if (estado == EstadoSolicitud.completada &&
                      _evidenciaFinal != null)
                    Column(
                      children: [
                        const Text(
                          "📸 Trabajo Terminado",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _evidenciaFinal!['foto_url'],
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
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

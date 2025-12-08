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
  late Solicitud _solicitudActual;
  List<Map<String, dynamic>> _items = [];
  List<dynamic> _empleados = [];
  Map<String, dynamic>? _evidenciaFinal;

  final Map<String, TextEditingController> _preciosControllers = {};
  double _totalCalculado = 0.0;

  String? _empleadoSeleccionadoId;
  DateTime? _fechaAgenda;
  TimeOfDay? _horaAgenda;

  final Color _bluePrimary = const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _solicitudActual = widget.solicitud;
    _fechaAgenda = widget.solicitud.fechaSolicitada;
    _horaAgenda = const TimeOfDay(hour: 9, minute: 0);
    _fetchCompleteDetails();
  }

  Future<void> _fetchCompleteDetails() async {
    try {
      final solicitudFresca = await _supabase
          .from('solicitudes')
          .select()
          .eq('id', widget.solicitud.id)
          .single();
      final itemsRes = await _supabase
          .from('items_solicitud')
          .select('*, servicios_catalogo(nombre), fotos_solicitud(foto_url)')
          .eq('solicitud_id', widget.solicitud.id);

      final estadoFresco = EstadoSolicitud.values.firstWhere(
        (e) => e.name == solicitudFresca['estado'],
      );

      // Cargar empleados si el estado es 'aceptada'
      if (estadoFresco == EstadoSolicitud.aceptada) {
        final empsRes = await _supabase
            .from('empleados_negocio')
            .select('id, perfiles(nombre_completo)')
            .eq('negocio_id', widget.solicitud.negocioId)
            .eq('activo', true);
        _empleados = empsRes as List<dynamic>;
      }

      // Cargar evidencia si el estado es 'completada'
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
          _solicitudActual = Solicitud.fromJson(solicitudFresca);
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

  Future<void> _enviarCotizacion() async {
    if (_totalCalculado <= 0) return;
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
      await _fetchCompleteDetails();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Cotización enviada")));
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _agendarCita() async {
    if (_empleadoSeleccionadoId == null) return;
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = _solicitudActual.estado;
    final esModoCotizar = estado == EstadoSolicitud.pendiente;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(
          "Gestión #${_solicitudActual.id.substring(0, 4)}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCompleteDetails,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _bluePrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(estado),
                  const SizedBox(height: 20),

                  // --- SECCIÓN DE EVIDENCIA (Solo si completada) ---
                  if (estado == EstadoSolicitud.completada &&
                      _evidenciaFinal != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 10),
                              Text(
                                "Resultado del Servicio",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 25),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _evidenciaFinal!['foto_url'],
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) =>
                                  progress == null
                                  ? child
                                  : Container(
                                      height: 220,
                                      color: Colors.grey[100],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                            ),
                          ),
                          if (_evidenciaFinal!['comentario_tecnico'] != null &&
                              _evidenciaFinal!['comentario_tecnico']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 15),
                            const Text(
                              "Notas del Técnico:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _evidenciaFinal!['comentario_tecnico'],
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],

                  _buildSectionTitle("Detalles del Cliente"),
                  const SizedBox(height: 10),
                  _buildInfoCard(Icons.location_on, _solicitudActual.direccion),
                  const SizedBox(height: 25),
                  _buildSectionTitle("Muebles & Cotización"),
                  const SizedBox(height: 10),
                  ..._items.map((item) => _buildItemCard(item, esModoCotizar)),
                  const SizedBox(height: 20),
                  _buildTotalFooter(),
                  const SizedBox(height: 30),
                  _buildActionButtons(estado, esModoCotizar),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey[700],
        fontWeight: FontWeight.bold,
        fontSize: 14,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildStatusHeader(EstadoSolicitud estado) {
    Color color = Colors.grey;
    IconData icon = Icons.info_outline;

    switch (estado) {
      case EstadoSolicitud.pendiente:
        color = Colors.orange;
        icon = Icons.notifications_active;
        break;
      case EstadoSolicitud.cotizada:
        color = _bluePrimary;
        icon = Icons.attach_money;
        break;
      case EstadoSolicitud.aceptada:
        color = Colors.teal;
        icon = Icons.check_circle_outline;
        break;
      case EstadoSolicitud.agendada:
        color = Colors.green;
        icon = Icons.event;
        break;
      case EstadoSolicitud.en_proceso:
        color = Colors.purple;
        icon = Icons.cleaning_services;
        break;
      case EstadoSolicitud.completada:
        color = Colors.grey;
        icon = Icons.task_alt;
        break;
      default:
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(
            estado.name.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _bluePrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool esModoCotizar) {
    final fotos = item['fotos_solicitud'] as List<dynamic>? ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _bluePrimary.withOpacity(0.1),
                child: Text(
                  "${item['cantidad']}",
                  style: TextStyle(
                    color: _bluePrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['servicios_catalogo']['nombre'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (item['descripcion_item'] != null)
                      Text(
                        item['descripcion_item'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (fotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: fotos.length,
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) =>
                        Dialog(child: Image.network(fotos[i]['foto_url'])),
                  ),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(fotos[i]['foto_url']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (esModoCotizar)
            TextField(
              controller: _preciosControllers[item['id']],
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
                  fontSize: 18,
                  color: Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bluePrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "TOTAL ESTIMADO",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "\$${_totalCalculado.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(EstadoSolicitud estado, bool esModoCotizar) {
    if (esModoCotizar) {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: _enviarCotizacion,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "ENVIAR COTIZACIÓN",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (estado == EstadoSolicitud.aceptada) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "🗓️ Configurar Cita",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          ListTile(
            title: Text(
              _fechaAgenda == null
                  ? "Seleccionar Fecha"
                  : "${DateFormat('dd/MM/yyyy').format(_fechaAgenda!)} - ${_horaAgenda!.format(context)}",
            ),
            leading: const Icon(Icons.calendar_today),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2025),
              );
              if (date != null && mounted) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null)
                  setState(() {
                    _fechaAgenda = date;
                    _horaAgenda = time;
                  });
              }
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            hint: const Text("Seleccionar Técnico"),
            value: _empleadoSeleccionadoId,
            items: _empleados.map((e) {
              final nombre = e['perfiles'] != null
                  ? e['perfiles']['nombre_completo']
                  : "Sin Nombre";
              return DropdownMenuItem(
                value: e['id'].toString(),
                child: Text(nombre),
              );
            }).toList(),
            onChanged: (v) => setState(() => _empleadoSeleccionadoId = v),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _agendarCita,
              style: ElevatedButton.styleFrom(
                backgroundColor: _bluePrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "CONFIRMAR CITA",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

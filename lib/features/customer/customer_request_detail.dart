import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../shared/models/marketplace_models.dart';

class CustomerRequestDetailScreen extends StatefulWidget {
  final Solicitud solicitud;

  const CustomerRequestDetailScreen({super.key, required this.solicitud});

  @override
  State<CustomerRequestDetailScreen> createState() =>
      _CustomerRequestDetailScreenState();
}

class _CustomerRequestDetailScreenState
    extends State<CustomerRequestDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _items = [];
  Map<String, dynamic>? _evidencia;
  late Solicitud _solicitudActual;

  // Datos de Agenda Confirmada
  DateTime? _fechaConfirmada;
  String? _horaConfirmada;
  String? _nombreTecnico;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null);
    _solicitudActual = widget.solicitud;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      // 1. Items con Fotos
      final itemsRes = await _supabase
          .from('items_solicitud')
          .select('*, servicios_catalogo(nombre), fotos_solicitud(foto_url)')
          .eq('solicitud_id', widget.solicitud.id);

      // 2. Evidencia (si existe)
      dynamic evidenciaRes;
      if (_solicitudActual.estado == EstadoSolicitud.completada) {
        evidenciaRes = await _supabase
            .from('evidencia_final')
            .select()
            .eq('solicitud_id', widget.solicitud.id)
            .maybeSingle();
      }

      // 3. Refrescar solicitud + DATOS DEL TÉCNICO
      final solRes = await _supabase
          .from('solicitudes')
          .select('*, tecnico:tecnico_asignado_id(perfiles(nombre_completo))')
          .eq('id', widget.solicitud.id)
          .single();

      if (mounted) {
        setState(() {
          _items = itemsRes as List<dynamic>;
          _evidencia = evidenciaRes;
          _solicitudActual = Solicitud.fromJson(solRes);

          if (solRes['fecha_agendada_final'] != null) {
            _fechaConfirmada = DateTime.parse(solRes['fecha_agendada_final']);
          }
          if (solRes['hora_agendada_final'] != null) {
            _horaConfirmada = solRes['hora_agendada_final'];
          }

          if (solRes['tecnico'] != null) {
            final tecnicoData = solRes['tecnico'] as Map<String, dynamic>;
            if (tecnicoData['perfiles'] != null) {
              _nombreTecnico = tecnicoData['perfiles']['nombre_completo'];
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Acción de Aceptar/Rechazar
  Future<void> _confirmarRespuesta(bool aceptar) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          aceptar ? "Confirmar y Enviar al Negocio" : "Rechazar Oferta",
        ),
        content: Text(
          aceptar
              ? "Al aceptar, notificaremos al negocio para que proceda a agendar tu cita y asignar un técnico.\n\nTotal acordado: \$${_solicitudActual.precioTotal}"
              : "¿Seguro que deseas cancelar esta solicitud?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _responderCotizacion(aceptar);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: aceptar ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(aceptar ? "Sí, Notificar" : "Sí, Rechazar"),
          ),
        ],
      ),
    );
  }

  Future<void> _responderCotizacion(bool aceptar) async {
    setState(() => _isLoading = true);
    try {
      final nuevoEstado = aceptar ? 'aceptada' : 'cancelada';
      await _supabase
          .from('solicitudes')
          .update({'estado': nuevoEstado})
          .eq('id', _solicitudActual.id);

      await _fetchDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aceptar
                  ? "¡Enviado! El negocio ha recibido tu aprobación."
                  : "Solicitud cancelada.",
            ),
            backgroundColor: aceptar ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Color colorEstado = Colors.grey;
    String textoEstado = _solicitudActual.estado.name.toUpperCase();
    IconData iconoEstado = Icons.info;

    switch (_solicitudActual.estado) {
      case EstadoSolicitud.pendiente:
        colorEstado = Colors.orange;
        iconoEstado = Icons.access_time;
        break;
      case EstadoSolicitud.cotizada:
        colorEstado = Colors.blue;
        iconoEstado = Icons.attach_money;
        break;
      case EstadoSolicitud.aceptada:
        colorEstado = Colors.teal;
        iconoEstado = Icons.check_circle_outline;
        break;
      case EstadoSolicitud.agendada:
        colorEstado = Colors.green;
        iconoEstado = Icons.event_available;
        break;
      case EstadoSolicitud.en_proceso:
        colorEstado = Colors.purple;
        iconoEstado = Icons.cleaning_services;
        break;
      case EstadoSolicitud.completada:
        colorEstado = Colors.grey;
        iconoEstado = Icons.task_alt;
        break;
      default:
        break;
    }

    final estaConfirmada =
        _solicitudActual.estado == EstadoSolicitud.agendada ||
        _solicitudActual.estado == EstadoSolicitud.en_proceso ||
        _solicitudActual.estado == EstadoSolicitud.completada;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle del Pedido"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetails),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER DE ESTADO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorEstado.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(iconoEstado, color: colorEstado, size: 30),
                        const SizedBox(width: 15),
                        Expanded(
                          // <--- EXPANDED PARA EVITAR OVERFLOW DE TEXTO
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Estado del Servicio",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                textoEstado,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorEstado,
                                ),
                                overflow: TextOverflow
                                    .ellipsis, // <--- Evita desbordamiento
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // CONFIRMACIÓN VISUAL (SI ESTÁ ACEPTADA PERO NO AGENDADA)
                  if (_solicitudActual.estado == EstadoSolicitud.aceptada)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.hourglass_bottom,
                            color: Colors.green,
                            size: 40,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "¡Cotización Aceptada!",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            "Esperando que el negocio asigne técnico...",
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  // EVIDENCIA FINAL (Si terminó)
                  if (_solicitudActual.estado == EstadoSolicitud.completada &&
                      _evidencia != null) ...[
                    const Text(
                      "Resultado Final",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _evidencia!['foto_url'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // DATOS DE LA CITA CONFIRMADA
                  if (estaConfirmada && _fechaConfirmada != null)
                    Card(
                      elevation: 2,
                      color: Colors.blue[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              "🗓️ CITA CONFIRMADA",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Divider(color: Colors.blue),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy',
                                        'es',
                                      ).format(_fechaConfirmada!),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _horaConfirmada != null
                                          ? _horaConfirmada!.substring(0, 5)
                                          : "---",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            // --- AQUÍ MOSTRAMOS AL TÉCNICO ---
                            if (_nombreTecnico != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    // Flexible para evitar overflow si el nombre es muy largo
                                    Flexible(
                                      child: Text(
                                        "Técnico: $_nombreTecnico",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // DIRECCIÓN
                  Card(
                    elevation: 0,
                    color: Colors.grey[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.location_on,
                            "Dirección",
                            _solicitudActual.direccion,
                          ),
                          if (!estaConfirmada) ...[
                            const Divider(),
                            _buildInfoRow(
                              Icons.calendar_today,
                              "Fecha Solicitada",
                              DateFormat(
                                'dd MMMM yyyy',
                                'es',
                              ).format(_solicitudActual.fechaSolicitada),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // DESGLOSE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "Detalle de Cotización",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_solicitudActual.precioTotal > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Total: \$${_solicitudActual.precioTotal}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ..._items.map((item) {
                    final fotos =
                        item['fotos_solicitud'] as List<dynamic>? ?? [];
                    final precioUnitario = item['precio_unitario'] ?? 0;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    "${item['cantidad']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (precioUnitario > 0)
                                  Text(
                                    "\$${precioUnitario}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                              ],
                            ),
                            if (fotos.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: fotos.length,
                                  itemBuilder: (ctx, i) => Container(
                                    width: 60,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          fotos[i]['foto_url'],
                                        ),
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
                    );
                  }),

                  const SizedBox(height: 30),

                  // BOTONES
                  if (_solicitudActual.estado == EstadoSolicitud.cotizada) ...[
                    const Text(
                      "El negocio ha enviado una cotización. ¿Deseas proceder?",
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _confirmarRespuesta(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: Colors.red,
                            ),
                            child: const Text("RECHAZAR"),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _confirmarRespuesta(true),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("ACEPTAR OFERTA"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

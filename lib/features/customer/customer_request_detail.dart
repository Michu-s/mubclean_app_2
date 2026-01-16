import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mubclean_marketplace/shared/services/mercadopago_service.dart';
import 'package:uni_links/uni_links.dart';
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
  final _mercadoPagoService = MercadoPagoService();
  bool _isLoading = true;
  List<dynamic> _items = [];
  Map<String, dynamic>? _evidencia;
  late Solicitud _solicitudActual;
  StreamSubscription? _sub;

  // Datos de Agenda Confirmada
  DateTime? _fechaConfirmada;
  String? _horaConfirmada;
  String? _nombreTecnico;

  // Reseña del usuario (si ya calificó)
  Resena? _miResena;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null);
    _solicitudActual = widget.solicitud;
    _fetchDetails();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinkListener() async {
    _sub = uriLinkStream.listen((Uri? uri) {
      if (!mounted || uri == null) return;
      _handleDeepLink(uri);
    }, onError: (err) {
      if (!mounted) return;
      debugPrint('Error en el deep link: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'tuapp') {
      final status = uri.host;
      String message;
      Color color;

      switch (status) {
        case 'success':
          message = "¡Pago aprobado! Tu servicio está en proceso.";
          color = Colors.green;
          break;
        case 'failure':
          message = "El pago fue rechazado. Inténtalo de nuevo.";
          color = Colors.red;
          break;
        case 'pending':
          message = "El pago quedó pendiente de confirmación.";
          color = Colors.orange;
          break;
        default:
          return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
      // Refrescamos el estado para que se actualice la UI
      _fetchDetails();
    }
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      // 1. Items con Fotos
      final itemsRes = await _supabase
          .from('items_solicitud')
          .select('*, servicios_catalogo(nombre), fotos_solicitud(foto_url)')
          .eq('solicitud_id', widget.solicitud.id);

      // 2. Evidencia (si existe y está completada)
      dynamic evidenciaRes;
      if (_solicitudActual.estado == EstadoSolicitud.completada) {
        evidenciaRes = await _supabase
            .from('evidencia_final')
            .select()
            .eq('solicitud_id', widget.solicitud.id)
            .maybeSingle();
      }

      // 3. Refrescar datos de la solicitud y técnico
      final solRes = await _supabase
          .from('solicitudes')
          .select('*, tecnico:tecnico_asignado_id(perfiles(nombre_completo))')
          .eq('id', widget.solicitud.id)
          .single();

      // 4. Buscar reseña existente
      Resena? resenaEnconrada;
      if (solRes['estado'] == 'completada') {
        final resenaData = await _supabase
            .from('resenas')
            .select()
            .eq('solicitud_id', widget.solicitud.id)
            .maybeSingle();

        if (resenaData != null) {
          resenaEnconrada = Resena.fromJson(resenaData);
        }
      }

      if (mounted) {
        setState(() {
          _items = itemsRes as List<dynamic>;
          _evidencia = evidenciaRes;
          _miResena = resenaEnconrada;
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

  Future<void> _handlePayment() async {
    setState(() => _isLoading = true);
    try {
      // Abre la pestaña de pago. Ya no esperamos un resultado directo aquí.
      await _mercadoPagoService.createPreferenceAndOpenCheckout(
        context: context,
        title: 'Servicio de Limpieza MubClean',
        quantity: 1,
        price: _solicitudActual.precioTotal,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Redirigiendo a Mercado Pago... Vuelve a la app para ver el estado."),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Actualización optimista: asumimos que el usuario intentará el pago.
      // La confirmación real del pago debería venir por otros medios (ej. Webhooks).
      await _supabase
          .from('solicitudes')
          .update({'estado': 'en_proceso'})
          .eq('id', _solicitudActual.id);
      
      // Refrescamos para mostrar el nuevo estado 'en_proceso'.
      await _fetchDetails();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al iniciar el pago: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Acción de Aceptar/Rechazar
  Future<void> _confirmarRespuesta(bool aceptar) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // REMOVED PRICE UI: Se eliminó el texto de Total del dialog
        title: Text(aceptar ? "Confirmar y Enviar" : "Rechazar Oferta"),
        content: Text(
          aceptar
              ? "Al aceptar, notificaremos al negocio para que proceda a agendar tu cita."
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
            child: Text(aceptar ? "Sí, Confirmar" : "Sí, Rechazar"),
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

  void _mostrarDialogoCalificar() {
    int estrellas = 5;
    final comentarioCtrl = TextEditingController();
    bool enviando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          return AlertDialog(
            title: const Text("Calificar Servicio"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("¿Qué tal te pareció el servicio?"),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () => setSt(() => estrellas = index + 1),
                      icon: Icon(
                        index < estrellas ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: comentarioCtrl,
                  decoration: const InputDecoration(
                    hintText: "Comentario opcional...",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: enviando ? null : () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: enviando
                    ? null
                    : () async {
                        setSt(() => enviando = true);
                        try {
                          await _supabase.from('resenas').insert({
                            'solicitud_id': widget.solicitud.id,
                            'negocio_id': widget.solicitud.negocioId,
                            'cliente_id': _supabase.auth.currentUser!.id,
                            'calificacion': estrellas,
                            'comentario': comentarioCtrl.text,
                          });
                          if (mounted) {
                            Navigator.pop(ctx);
                            _fetchDetails(); // Recargar para mostrar la reseña
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("¡Gracias por tu calificación!"),
                              ),
                            );
                          }
                        } catch (e) {
                          setSt(() => enviando = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        }
                      },
                child: enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Enviar"),
              ),
            ],
          );
        },
      ),
    );
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
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text("Detalle del Pedido"),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetails),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER DE ESTADO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorEstado.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(iconoEstado, color: colorEstado, size: 28),
                        const SizedBox(width: 15),
                        Expanded(
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
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- EVIDENCIA FINAL Y COMENTARIOS (NUEVO) ---
                  if (_solicitudActual.estado == EstadoSolicitud.completada &&
                      _evidencia != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 10),
                              Text(
                                "Trabajo Terminado",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 25),

                          // FOTO EVIDENCIA
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _evidencia!['foto_url'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) =>
                                  progress == null
                                  ? child
                                  : Container(
                                      height: 200,
                                      color: Colors.grey[100],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                            ),
                          ),

                          // COMENTARIOS DEL TÉCNICO
                          if (_evidencia!['comentario_tecnico'] != null &&
                              _evidencia!['comentario_tecnico']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 15),
                            const Text(
                              "Notas del Técnico:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _evidencia!['comentario_tecnico'],
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

                  // CITA CONFIRMADA
                  if (estaConfirmada && _fechaConfirmada != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
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
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Icon(
                                    Icons.calendar_month,
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
                                    Icons.access_time_filled,
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
                          if (_nombreTecnico != null) ...[
                            const Divider(height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    "Técnico: $_nombreTecnico",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_solicitudActual.estado ==
                              EstadoSolicitud.agendada) ...[
                            const Divider(height: 25),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.payment),
                                label: const Text("PAGAR CON MERCADO PAGO"),
                                onPressed: _handlePayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // DIRECCIÓN
                  _buildSectionContainer(
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.location_on,
                          "Dirección",
                          _solicitudActual.direccion,
                        ),
                        if (!estaConfirmada) ...[
                          const Divider(height: 25),
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
                  const SizedBox(height: 25),

                  // REMOVED PRICE UI: Se eliminó el container con Total
                  // DETALLE DE SERVICIOS (sin precios)
                  const Text(
                    "Detalle de Servicios",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),

                  ..._items.map((item) {
                    final fotos =
                        item['fotos_solicitud'] as List<dynamic>? ?? [];
                    // REMOVED: precioUnitario ya no se usa porque eliminamos la UI de precios

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${item['cantidad']}x",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
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
                                // REMOVED PRICE UI: Se eliminó el texto de precio_unitario  ),
                              ],
                            ),
                            if (fotos.isNotEmpty) ...[
                              const SizedBox(height: 12),
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

                  // BOTONES ACCIÓN
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
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("ACEPTAR OFERTA"),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // --- SECCIÓN DE CALIFICACIÓN (SOLO SI ESTÁ COMPLETADA) ---
                  if (_solicitudActual.estado ==
                      EstadoSolicitud.completada) ...[
                    const SizedBox(height: 30),
                    if (_miResena == null)
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _mostrarDialogoCalificar,
                          icon: const Icon(Icons.star, color: Colors.white),
                          label: const Text(
                            "CALIFICAR SERVICIO",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Tu Calificación",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.brown,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < _miResena!.calificacion
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 30,
                                );
                              }),
                            ),
                            if (_miResena!.comentario != null &&
                                _miResena!.comentario!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                '"${_miResena!.comentario}"',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        const SizedBox(width: 12),
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
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

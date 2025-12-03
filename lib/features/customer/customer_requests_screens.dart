import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../shared/models/marketplace_models.dart';
import 'customer_request_detail.dart'; // <--- Importante

class CustomerRequestsScreen extends StatefulWidget {
  const CustomerRequestsScreen({super.key});

  @override
  State<CustomerRequestsScreen> createState() => _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState extends State<CustomerRequestsScreen> {
  final _supabase = Supabase.instance.client;
  List<Solicitud> _misSolicitudes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMisSolicitudes();
  }

  Future<void> _fetchMisSolicitudes() async {
    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser!.id;

    try {
      final response = await _supabase
          .from('solicitudes')
          .select()
          .eq('cliente_id', userId)
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;

      if (mounted) {
        setState(() {
          _misSolicitudes = data
              .map((json) => Solicitud.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _responderCotizacion(String solicitudId, bool aceptar) async {
    try {
      final nuevoEstado = aceptar ? 'aceptada' : 'cancelada';
      await _supabase
          .from('solicitudes')
          .update({'estado': nuevoEstado})
          .eq('id', solicitudId);
      _fetchMisSolicitudes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aceptar ? "¡Oferta aceptada!" : "Solicitud cancelada.",
            ),
            backgroundColor: aceptar ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Solicitudes")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _misSolicitudes.isEmpty
          ? const Center(child: Text("No has realizado solicitudes aún."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _misSolicitudes.length,
              itemBuilder: (context, index) {
                final solicitud = _misSolicitudes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () {
                      // Navegar al detalle
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerRequestDetailScreen(solicitud: solicitud),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Chip(
                                label: Text(
                                  solicitud.estado.name.toUpperCase(),
                                ),
                                backgroundColor: _getColorEstado(
                                  solicitud.estado,
                                ),
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(solicitud.fechaSolicitada),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            solicitud.direccion,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          if (solicitud.estado == EstadoSolicitud.cotizada) ...[
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    "Precio: \$${solicitud.precioTotal}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _responderCotizacion(
                                            solicitud.id,
                                            false,
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text("RECHAZAR"),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => _responderCotizacion(
                                            solicitud.id,
                                            true,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text("ACEPTAR"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getColorEstado(EstadoSolicitud e) {
    switch (e) {
      case EstadoSolicitud.pendiente:
        return Colors.orange;
      case EstadoSolicitud.cotizada:
        return Colors.blue;
      case EstadoSolicitud.aceptada:
        return Colors.teal;
      case EstadoSolicitud.agendada:
        return Colors.green;
      case EstadoSolicitud.en_proceso:
        return Colors.purple;
      case EstadoSolicitud.completada:
        return Colors.grey;
      case EstadoSolicitud.cancelada:
        return Colors.red;
    }
  }
}

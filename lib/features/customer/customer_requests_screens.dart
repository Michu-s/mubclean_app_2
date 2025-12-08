import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../shared/models/marketplace_models.dart';
import 'customer_request_detail.dart';

class CustomerRequestsScreen extends StatefulWidget {
  const CustomerRequestsScreen({super.key});

  @override
  State<CustomerRequestsScreen> createState() => _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState extends State<CustomerRequestsScreen> {
  final _supabase = Supabase.instance.client;
  List<Solicitud> _misSolicitudes = [];
  bool _isLoading = true;
  final Color _primaryBlue = const Color(0xFF1565C0);

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
      if (mounted)
        setState(() {
          _misSolicitudes = data
              .map((json) => Solicitud.fromJson(json))
              .toList();
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(aceptar ? "Oferta aceptada" : "Solicitud cancelada"),
          ),
        );
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
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(
          "Historial de Pedidos",
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryBlue),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryBlue))
          : _misSolicitudes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text(
                    "Sin historial",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _misSolicitudes.length,
              itemBuilder: (context, index) {
                final s = _misSolicitudes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerRequestDetailScreen(solicitud: s),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getColorEstado(
                                      s.estado,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    s.estado.name.toUpperCase(),
                                    style: TextStyle(
                                      color: _getColorEstado(s.estado),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(s.fechaSolicitada),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    s.direccion,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            if (s.estado == EstadoSolicitud.cotizada) ...[
                              const SizedBox(height: 15),
                              Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F9FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _primaryBlue.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "Cotización: \$${s.precioTotal}",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                _responderCotizacion(
                                                  s.id,
                                                  false,
                                                ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                color: Colors.red,
                                              ),
                                            ),
                                            child: const Text("RECHAZAR"),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _responderCotizacion(
                                                  s.id,
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
        return _primaryBlue;
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

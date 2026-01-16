import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
// Actually standard flutter pub add timeago usually works with `import 'package:timeago/timeago.dart' as timeago;` providing basic.
// But for Spanish, we need `import 'package:timeago/timeago.dart' as timeago;` and usually `timeago.setLocaleMessages`.
// Wait, I should not guess imports too much.

import '../../shared/models/marketplace_models.dart';

class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  final Color _primaryBlue = const Color(0xFF1565C0);

  // Lists
  List<TicketSoporte> _misTickets = [];
  bool _isLoadingTickets = true;

  // Creation State
  int _step = 0; // 0: Classification, 1: Details
  String? _selectedCategory; // 'servicio' or 'general'
  String? _selectedSolicitudId;
  List<Solicitud> _misSolicitudesRecientes = [];

  // Form Controllers
  final _asuntoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('es', timeago.EsMessages());
    _tabController = TabController(length: 2, vsync: this);
    _fetchTickets();
    _fetchPedidosRecientes();
  }

  Future<void> _fetchTickets() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await _supabase
          .from('soporte_tickets')
          .select()
          .eq('cliente_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _misTickets = (res as List)
              .map((json) => TicketSoporte.fromJson(json))
              .toList();
          _isLoadingTickets = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTickets = false);
    }
  }

  Future<void> _fetchPedidosRecientes() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await _supabase
          .from('solicitudes')
          .select()
          .eq('cliente_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _misSolicitudesRecientes = (res as List)
              .map((json) => Solicitud.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      // Silent error
    }
  }

  void _resetCreation() {
    setState(() {
      _step = 0;
      _selectedCategory = null;
      _selectedSolicitudId = null;
      _asuntoCtrl.clear();
      _descripcionCtrl.clear();
    });
  }

  Future<void> _crearTicket() async {
    if (_asuntoCtrl.text.isEmpty || _descripcionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor completa todos los campos")),
      );
      return;
    }

    setState(() => _submitting = true);
    final userId = _supabase.auth.currentUser!.id;

    try {
      String descripcionFinal = _descripcionCtrl.text;
      String asuntoFinal = _asuntoCtrl.text;

      // Append Service ID to description if applicable
      if (_selectedCategory == 'servicio' && _selectedSolicitudId != null) {
        descripcionFinal += "\n\n[Referencia Orden ID: $_selectedSolicitudId]";
        asuntoFinal =
            "[Orden #${_selectedSolicitudId!.substring(0, 4)}] $asuntoFinal";
      }

      await _supabase.from('soporte_tickets').insert({
        'cliente_id': userId,
        'tipo': _selectedCategory == 'servicio' ? 'incidencia' : 'consulta',
        'asunto': asuntoFinal,
        'descripcion': descripcionFinal,
        'estado': 'abierto',
      });

      _resetCreation();
      _fetchTickets();
      _tabController.animateTo(0); // Go back to list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ticket creado exitosamente")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(
          "Centro de Ayuda",
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primaryBlue,
          tabs: const [
            Tab(text: "Mis Tickets"),
            Tab(text: "Solicitar Ayuda"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTicketList(), _buildCreationFlow()],
      ),
    );
  }

  Widget _buildTicketList() {
    if (_isLoadingTickets) {
      return Center(child: CircularProgressIndicator(color: _primaryBlue));
    }
    if (_misTickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            const Text(
              "No tienes tickets abiertos",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _misTickets.length,
      itemBuilder: (context, index) {
        final t = _misTickets[index];
        final isOpen = t.estado != 'resuelto';
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isOpen
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              child: Icon(
                isOpen ? Icons.lock_open : Icons.lock,
                color: isOpen ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
            title: Text(
              t.asunto,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${t.tipo.toUpperCase()} • ${timeago.format(t.createdAt, locale: 'es')}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Descripción:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(t.descripcion),
                    if (t.respuestaAdmin != null) ...[
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Respuesta de Soporte:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(t.respuestaAdmin!),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreationFlow() {
    if (_step == 0) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "¿En qué podemos ayudarte hoy?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Selecciona una categoría para dirigir tu solicitud al equipo correcto.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            _buildCategoryCard(
              icon: Icons.receipt_long,
              title: "Problema con un Servicio",
              subtitle: "Reportar incidencia sobre una orden existente",
              onTap: () {
                setState(() {
                  _selectedCategory = 'servicio';
                  _step = 1;
                });
              },
            ),
            const SizedBox(height: 15),
            _buildCategoryCard(
              icon: Icons.feedback_outlined,
              title: "Comentarios / App",
              subtitle: "Sugerencias, dudas generales o feedback de la app",
              onTap: () {
                setState(() {
                  _selectedCategory = 'general';
                  _step = 1;
                });
              },
            ),
          ],
        ),
      );
    }

    // Step 1: Form Details
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = 0),
              ),
              Text(
                _selectedCategory == 'servicio'
                    ? "Reportar Servicio"
                    : "Comentarios Generales",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_selectedCategory == 'servicio') ...[
            const Text(
              "Selecciona el servicio afectado:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_misSolicitudesRecientes.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "No tienes servicios recientes para reportar.",
                ),
              )
            else
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 15,
                  ),
                ),
                hint: const Text("Seleccionar orden..."),
                value: _selectedSolicitudId,
                items: _misSolicitudesRecientes.map((s) {
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      "Orden #${s.id.substring(0, 4)} - ${s.estado.name.toUpperCase()}",
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedSolicitudId = v),
              ),
            const SizedBox(height: 20),
          ],

          const Text("Asunto:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _asuntoCtrl,
            decoration: InputDecoration(
              hintText: "Ej. Retraso en llegada, Error en app...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            "Descripción detallada:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descripcionCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: "Cuéntanos más detalles para poder ayudarte...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _crearTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "ENVIAR TICKET",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _primaryBlue, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

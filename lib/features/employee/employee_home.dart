import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/marketplace_models.dart';
import 'employee_job_detail.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _misTrabajos = [];
  bool _isLoading = true;
  String? _mensajeError;

  // Paleta de colores local para consistencia
  final Color _bluePrimary = const Color(0xFF1565C0); // Azul oscuro
  final Color _bgLight = const Color(0xFFF5F9FF); // Azul muy claro de fondo

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null);
    _fetchMisAsignaciones();
  }

  Future<void> _fetchMisAsignaciones() async {
    setState(() {
      _isLoading = true;
      _mensajeError = null;
    });

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final empleadoRes = await _supabase
          .from('empleados_negocio')
          .select('id')
          .eq('perfil_id', userId)
          .maybeSingle();

      if (empleadoRes == null) {
        if (mounted)
          setState(() {
            _mensajeError =
                "No se encontró vinculación laboral.\nContacta a tu administrador.";
            _isLoading = false;
          });
        return;
      }

      final miEmpleadoId = empleadoRes['id'];

      final response = await _supabase
          .from('solicitudes')
          .select('*, cliente:cliente_id(nombre_completo)')
          .eq('tecnico_asignado_id', miEmpleadoId)
          .or('estado.eq.agendada,estado.eq.en_proceso')
          .order('fecha_agendada_final', ascending: true);

      if (mounted) {
        setState(() {
          _misTrabajos = response as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _mensajeError = "Error de conexión. Desliza para reintentar.";
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: _bgLight, // Fondo suave
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Mi Agenda",
          style: TextStyle(color: _bluePrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: _bluePrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
            tooltip: "Cerrar Sesión",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMisAsignaciones,
        color: _bluePrimary,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _bluePrimary))
            : _mensajeError != null
            ? _buildErrorView()
            : _misTrabajos.isEmpty
            ? _buildEmptyView()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                itemCount: _misTrabajos.length,
                itemBuilder: (context, index) =>
                    _buildJobCard(_misTrabajos[index]),
              ),
      ),
    );
  }

  Widget _buildJobCard(dynamic trabajoMap) {
    final trabajo = Solicitud.fromJson(trabajoMap);
    final nombreCliente =
        trabajoMap['cliente']?['nombre_completo'] ?? 'Cliente';
    final fechaMostrar = trabajo
        .fechaSolicitada; // Idealmente usar fecha_agendada_final si existe
    final esHoy = isSameDay(fechaMostrar, DateTime.now());
    final enProceso = trabajo.estado == EstadoSolicitud.en_proceso;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: enProceso ? Border.all(color: Colors.orange, width: 2) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmployeeJobDetail(solicitud: trabajo),
              ),
            );
            _fetchMisAsignaciones();
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment
                  .start, // Alineación superior para textos largos
              children: [
                // 1. FECHA (Estilo Calendario)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: esHoy ? _bluePrimary : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('dd').format(fechaMostrar),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: esHoy ? Colors.white : _bluePrimary,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'MMM',
                          'es',
                        ).format(fechaMostrar).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: esHoy
                              ? Colors.white.withOpacity(0.9)
                              : _bluePrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // 2. DETALLES (Con Expanded para evitar overflow)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge de Estado
                      if (enProceso)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "EN PROCESO",
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (esHoy)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "PARA HOY",
                            style: TextStyle(
                              color: Colors.green[800],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      // Nombre Cliente
                      Text(
                        nombreCliente,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Dirección (Flexible para que baje de línea si es necesario)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trabajo.direccion,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. FLECHA
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 10),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(Icons.task_alt, size: 60, color: Colors.green[300]),
              ),
              const SizedBox(height: 20),
              Text(
                "¡Todo al día!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _bluePrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "No tienes servicios pendientes por ahora.",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              _mensajeError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _fetchMisAsignaciones,
              icon: const Icon(Icons.refresh),
              label: const Text("REINTENTAR"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _bluePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

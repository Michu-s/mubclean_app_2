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
  // Usamos dynamic para traer datos anidados (nombre del cliente)
  List<dynamic> _misTrabajos = [];
  bool _isLoading = true;
  String? _mensajeError;

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
      // 1. Averiguar mi ID de Empleado (enlace entre auth.uid y el negocio)
      final empleadoRes = await _supabase
          .from('empleados_negocio')
          .select('id')
          .eq('perfil_id', userId)
          .maybeSingle();

      if (empleadoRes == null) {
        if (mounted)
          setState(() {
            _mensajeError =
                "No se encontró vinculación laboral.\n\nSi el Admin ya te agregó, es posible que falte refrescar permisos.";
            _isLoading = false;
          });
        return;
      }

      final miEmpleadoId = empleadoRes['id'];

      // 2. Buscar trabajos asignados (Agendados o En Proceso)
      final response = await _supabase
          .from('solicitudes')
          .select('*, cliente:cliente_id(nombre_completo)')
          .eq('tecnico_asignado_id', miEmpleadoId)
          .or('estado.eq.agendada,estado.eq.en_proceso')
          .order('fecha_agendada_final', ascending: true);

      final data = response as List<dynamic>;

      if (mounted) {
        setState(() {
          _misTrabajos = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error agenda: $e");
      if (mounted) {
        setState(() {
          _mensajeError = "Error de conexión o permisos: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Ruta"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMisAsignaciones,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMisAsignaciones,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _mensajeError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 60,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _mensajeError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _fetchMisAsignaciones,
                        icon: const Icon(Icons.refresh),
                        label: const Text("REINTENTAR CONEXIÓN"),
                      ),
                    ],
                  ),
                ),
              )
            : _misTrabajos.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: Colors.green,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "¡Todo limpio!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "No tienes trabajos pendientes hoy.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _misTrabajos.length,
                itemBuilder: (context, index) {
                  final trabajoMap = _misTrabajos[index];
                  final trabajo = Solicitud.fromJson(trabajoMap);

                  // Extraemos nombre del cliente
                  final nombreCliente =
                      trabajoMap['cliente']?['nombre_completo'] ?? 'Cliente';

                  // Fechas
                  final fechaMostrar = trabajo.fechaSolicitada;
                  final esHoy = isSameDay(fechaMostrar, DateTime.now());

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EmployeeJobDetail(solicitud: trabajo),
                          ),
                        );
                        _fetchMisAsignaciones();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // Fecha
                            Column(
                              children: [
                                Text(
                                  DateFormat('dd').format(fechaMostrar),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'MMM',
                                    'es',
                                  ).format(fechaMostrar).toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Container(
                              width: 1,
                              height: 50,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(width: 16),

                            // Detalles
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (trabajo.estado ==
                                      EstadoSolicitud.en_proceso)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 5),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "EN PROCESO",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                  Text(
                                    nombreCliente,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),

                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          trabajo.direccion,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 4),
                                  Text(
                                    esHoy ? "¡Es para hoy!" : "Programado",
                                    style: TextStyle(
                                      color: esHoy ? Colors.green : Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

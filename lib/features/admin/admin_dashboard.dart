import 'package:flutter/material.dart';
import 'package:mubclean_marketplace/features/admin/admin_employees_screens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/marketplace_models.dart';
import 'admin_request_detail.dart';
import 'admin_services_screen.dart';
import './admin_business_edit_screen.dart';
import 'admin_business_edit_screen.dart'; // <--- Importante
import '../profile/user_profile_screen.dart'; // <--- Importante

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  bool _isLoading = true;
  bool _tieneNegocio = false;
  String? _errorMessage;

  List<Solicitud> _nuevas = [];
  List<Solicitud> _activas = [];
  List<Solicitud> _historial = [];

  final _nombreNegocioCtrl = TextEditingController();
  final _descNegocioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNegocioExistente();
    });
  }

  Future<void> _checkNegocioExistente() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final res = await _supabase
          .from('negocios')
          .select()
          .eq('owner_id', userId)
          .maybeSingle();

      if (res != null) {
        if (mounted) {
          setState(() {
            _tieneNegocio = true;
            _errorMessage = null;
          });
          await _fetchSolicitudes(res['id']);
        }
      } else {
        if (mounted) {
          setState(() {
            _tieneNegocio = false;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      }
    } on PostgrestException catch (pgError) {
      debugPrint("Error Supabase: ${pgError.message}");
      if (mounted)
        setState(() {
          _isLoading = false;
          if (pgError.code != 'PGRST116') {
            _errorMessage = "Error de base de datos: ${pgError.message}";
          }
        });
    } catch (e) {
      debugPrint("Error genérico: $e");
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  Future<void> _fetchSolicitudes(String negocioId) async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('solicitudes')
          .select()
          .eq('negocio_id', negocioId)
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      final todas = data.map((json) => Solicitud.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _nuevas = todas
              .where(
                (s) =>
                    s.estado == EstadoSolicitud.pendiente ||
                    s.estado == EstadoSolicitud.cotizada,
              )
              .toList();
          _activas = todas
              .where(
                (s) =>
                    s.estado == EstadoSolicitud.aceptada ||
                    s.estado == EstadoSolicitud.agendada ||
                    s.estado == EstadoSolicitud.en_proceso,
              )
              .toList();
          _historial = todas
              .where(
                (s) =>
                    s.estado == EstadoSolicitud.completada ||
                    s.estado == EstadoSolicitud.cancelada,
              )
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error solicitudes: $e");
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorMessage = "No se pudieron cargar las solicitudes";
        });
    }
  }

  Future<void> _crearNegocio() async {
    if (_nombreNegocioCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      await _supabase.from('negocios').insert({
        'owner_id': userId,
        'nombre': _nombreNegocioCtrl.text,
        'descripcion': _descNegocioCtrl.text,
        'activo': true,
      });

      await _checkNegocioExistente();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Error"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => auth.signOut(),
            ),
          ],
        ),
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (!_isLoading && !_tieneNegocio) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Bienvenido Socio"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => auth.signOut(),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "¡Casi listo!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Registra tu empresa para empezar a recibir pedidos.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _nombreNegocioCtrl,
                decoration: const InputDecoration(
                  labelText: "Nombre del Negocio",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _descNegocioCtrl,
                decoration: const InputDecoration(
                  labelText: "Descripción breve",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _crearNegocio,
                  child: const Text("CREAR MI NEGOCIO"),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de Control"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _checkNegocioExistente(),
          ),

          // GESTIÓN DE EQUIPO
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: "Mi Equipo",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminEmployeesScreen()),
            ),
          ),

          // GESTIÓN DE SERVICIOS
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: "Gestionar Servicios",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminServicesScreen()),
            ),
          ),

          // MENÚ DE USUARIO (Perfil, Negocio, Salir)
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'perfil') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                );
              } else if (value == 'negocio') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminBusinessEditScreen(),
                  ),
                );
              } else if (value == 'salir') {
                auth.signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'perfil',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text("Mi Perfil"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'negocio',
                child: ListTile(
                  leading: Icon(Icons.store),
                  title: Text("Editar Negocio"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'salir',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    "Cerrar Sesión",
                    style: TextStyle(color: Colors.red),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Nuevas (${_nuevas.length})"),
            Tab(text: "Activas (${_activas.length})"),
            Tab(text: "Historial"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_nuevas, isNew: true),
                _buildList(_activas),
                _buildList(_historial),
              ],
            ),
    );
  }

  Widget _buildList(List<Solicitud> list, {bool isNew = false}) {
    if (list.isEmpty)
      return const Center(child: Text("Sin actividad reciente"));

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final s = list[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getColorEstado(s.estado),
              child: Icon(
                _getIconEstado(s.estado),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(s.direccion, maxLines: 1),
            subtitle: Text("Estado: ${s.estado.name.toUpperCase()}"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminRequestDetail(solicitud: s),
                ),
              );
              _checkNegocioExistente();
            },
          ),
        );
      },
    );
  }

  Color _getColorEstado(EstadoSolicitud e) {
    switch (e) {
      case EstadoSolicitud.pendiente:
        return Colors.orange;
      case EstadoSolicitud.cotizada:
        return Colors.blue;
      case EstadoSolicitud.aceptada:
        return Colors.green;
      case EstadoSolicitud.en_proceso:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconEstado(EstadoSolicitud e) {
    switch (e) {
      case EstadoSolicitud.pendiente:
        return Icons.notification_important;
      case EstadoSolicitud.en_proceso:
        return Icons.cleaning_services;
      default:
        return Icons.info;
    }
  }
}

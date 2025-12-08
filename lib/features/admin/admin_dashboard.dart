import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/marketplace_models.dart';
import 'admin_request_detail.dart';
import 'admin_services_screen.dart';
import './admin_employees_screens.dart';
import 'admin_business_edit_screen.dart';
import '../profile/user_profile_screen.dart';

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

  // Colores de Diseño
  final Color _primaryBlue = const Color(0xFF1565C0);
  final Color _bgLight = const Color(0xFFF5F9FF);

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
      if (mounted)
        setState(() {
          _isLoading = false;
          if (pgError.code != 'PGRST116') {
            _errorMessage = "Error de base de datos: ${pgError.message}";
          }
        });
    } catch (e) {
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
        backgroundColor: _bgLight,
        appBar: AppBar(
          title: const Text("Error"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.red,
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
        backgroundColor: _bgLight,
        appBar: AppBar(
          title: const Text("Bienvenido Socio"),
          centerTitle: true,
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.store_mall_directory, size: 80, color: _primaryBlue),
                const SizedBox(height: 20),
                const Text(
                  "Registra tu Negocio",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Empieza a recibir pedidos hoy mismo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _nombreNegocioCtrl,
                  decoration: InputDecoration(
                    labelText: "Nombre Comercial",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _descNegocioCtrl,
                  decoration: InputDecoration(
                    labelText: "Slogan o Descripción",
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
                    onPressed: _crearNegocio,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "CREAR NEGOCIO",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Panel de Control",
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: _primaryBlue),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _checkNegocioExistente(),
          ),

          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: "Mi Equipo",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminEmployeesScreen()),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.view_list_rounded),
            tooltip: "Catálogo",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminServicesScreen()),
            ),
          ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'perfil')
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                );
              else if (value == 'negocio')
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminBusinessEditScreen(),
                  ),
                );
              else if (value == 'salir')
                auth.signOut();
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
          labelColor: _primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primaryBlue,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Text(
                "Nuevas (${_nuevas.length})",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Tab(
              child: Text(
                "Activas (${_activas.length})",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Tab(text: "Historial"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_nuevas, emptyMsg: "Sin solicitudes nuevas"),
                _buildList(_activas, emptyMsg: "No hay trabajos en curso"),
                _buildList(_historial, emptyMsg: "Historial vacío"),
              ],
            ),
    );
  }

  Widget _buildList(List<Solicitud> list, {required String emptyMsg}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              emptyMsg,
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final s = list[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getColorEstado(s.estado).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconEstado(s.estado),
                color: _getColorEstado(s.estado),
              ),
            ),
            title: Text(
              s.direccion,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getColorEstado(s.estado).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s.estado.name.toUpperCase(),
                      style: TextStyle(
                        color: _getColorEstado(s.estado),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM').format(s.fechaSolicitada),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey,
            ),
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
        return Colors.teal;
      case EstadoSolicitud.agendada:
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
        return Icons.notifications_active;
      case EstadoSolicitud.cotizada:
        return Icons.request_quote;
      case EstadoSolicitud.aceptada:
        return Icons.check_circle;
      case EstadoSolicitud.agendada:
        return Icons.event;
      case EstadoSolicitud.en_proceso:
        return Icons.cleaning_services;
      default:
        return Icons.history;
    }
  }
}

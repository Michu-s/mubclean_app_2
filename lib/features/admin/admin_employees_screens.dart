import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _empleados = [];
  bool _isLoading = true;
  String? _negocioId;
  final Color _primaryBlue = const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _fetchEmpleados();
  }

  Future<void> _fetchEmpleados() async {
    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser!.id;
    try {
      final negocioRes = await _supabase
          .from('negocios')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();
      if (negocioRes == null) {
        setState(() => _isLoading = false);
        return;
      }
      _negocioId = negocioRes['id'];
      final res = await _supabase
          .from('empleados_negocio')
          .select(
            'id, activo, perfiles(email, nombre_completo, foto_perfil_url)',
          )
          .eq('negocio_id', _negocioId!);
      if (mounted)
        setState(() {
          _empleados = res;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEmployeeDialog() {
    final emailCtrl = TextEditingController();
    bool searching = false;
    String? searchError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogSt) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Agregar Técnico",
            style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ingresa el correo del usuario registrado."),
              const SizedBox(height: 15),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: "Correo Electrónico",
                  errorText: searchError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              if (searching)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: searching
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty) return;
                      setDialogSt(() {
                        searching = true;
                        searchError = null;
                      });
                      try {
                        final userRes = await _supabase
                            .from('perfiles')
                            .select('id, rol')
                            .eq('email', email)
                            .maybeSingle();
                        if (userRes == null) {
                          setDialogSt(() {
                            searchError = "Usuario no encontrado.";
                            searching = false;
                          });
                          return;
                        }

                        final existingEmp = await _supabase
                            .from('empleados_negocio')
                            .select()
                            .eq('negocio_id', _negocioId!)
                            .eq('perfil_id', userRes['id'])
                            .maybeSingle();
                        if (existingEmp != null) {
                          setDialogSt(() {
                            searchError = "Ya está en tu equipo.";
                            searching = false;
                          });
                          return;
                        }

                        await _supabase.from('empleados_negocio').insert({
                          'negocio_id': _negocioId,
                          'perfil_id': userRes['id'],
                          'activo': true,
                        });
                        if (userRes['rol'] == 'cliente')
                          await _supabase
                              .from('perfiles')
                              .update({'rol': 'empleado'})
                              .eq('id', userRes['id']);

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Empleado agregado")),
                          );
                          _fetchEmpleados();
                        }
                      } catch (e) {
                        setDialogSt(() {
                          searchError = "Error: $e";
                          searching = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Agregar"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(String empId, bool actual) async {
    await _supabase
        .from('empleados_negocio')
        .update({'activo': !actual})
        .eq('id', empId);
    _fetchEmpleados();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(
          "Mi Equipo",
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryBlue),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEmployeeDialog,
        backgroundColor: _primaryBlue,
        icon: const Icon(Icons.person_add),
        label: const Text("Nuevo"),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryBlue))
          : _empleados.isEmpty
          ? const Center(child: Text("No tienes empleados aún."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _empleados.length,
              itemBuilder: (context, index) {
                final emp = _empleados[index];
                final perfil = emp['perfiles'];
                final activo = emp['activo'] as bool;
                final nombre = perfil != null
                    ? perfil['nombre_completo']
                    : "Sin nombre";
                final email = perfil != null ? perfil['email'] : "";

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: activo ? _primaryBlue : Colors.grey,
                      radius: 25,
                      child: Text(
                        nombre.isNotEmpty ? nombre[0].toUpperCase() : "?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: activo ? null : TextDecoration.lineThrough,
                        color: activo ? Colors.black : Colors.grey,
                      ),
                    ),
                    subtitle: Text(email),
                    trailing: Switch(
                      value: activo,
                      onChanged: (val) => _toggleStatus(emp['id'], activo),
                      activeColor: Colors.green,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _fetchEmpleados();
  }

  Future<void> _fetchEmpleados() async {
    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser!.id;

    try {
      // 1. Obtener ID del negocio
      final negocioRes = await _supabase
          .from('negocios')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();

      if (negocioRes == null) {
        debugPrint("⚠️ No se encontró negocio para este usuario.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _negocioId = negocioRes['id'];

      // 2. Obtener empleados vinculados
      debugPrint("🔍 Buscando empleados para negocio: $_negocioId");

      final res = await _supabase
          .from('empleados_negocio')
          .select(
            'id, activo, perfiles(email, nombre_completo, foto_perfil_url)',
          )
          .eq('negocio_id', _negocioId!);

      debugPrint("✅ Empleados encontrados: ${(res as List).length}");

      if (mounted) {
        setState(() {
          _empleados = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching empleados: $e");
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
          title: const Text("Agregar Técnico"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Ingresa el correo del usuario que deseas agregar a tu equipo.",
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: "Correo Electrónico",
                  errorText: searchError,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
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
                        // 1. Buscar si el usuario existe en perfiles
                        final userRes = await _supabase
                            .from('perfiles')
                            .select('id, rol')
                            .eq('email', email)
                            .maybeSingle();

                        if (userRes == null) {
                          setDialogSt(() {
                            searchError =
                                "Usuario no encontrado. Debe registrarse primero en la app.";
                            searching = false;
                          });
                          return;
                        }

                        // 2. Verificar si ya es empleado de este negocio
                        final existingEmp = await _supabase
                            .from('empleados_negocio')
                            .select()
                            .eq('negocio_id', _negocioId!)
                            .eq('perfil_id', userRes['id'])
                            .maybeSingle();

                        if (existingEmp != null) {
                          setDialogSt(() {
                            searchError = "Este usuario ya está en tu equipo.";
                            searching = false;
                          });
                          return;
                        }

                        // 3. Vincular (Crear empleado)
                        await _supabase.from('empleados_negocio').insert({
                          'negocio_id': _negocioId,
                          'perfil_id': userRes['id'],
                          'activo': true,
                        });

                        // 4. Actualizar rol del usuario a 'empleado' si era 'cliente'
                        if (userRes['rol'] == 'cliente') {
                          await _supabase
                              .from('perfiles')
                              .update({'rol': 'empleado'})
                              .eq('id', userRes['id']);
                        }

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("¡Empleado agregado exitosamente!"),
                            ),
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
              child: const Text("Agregar"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(String empId, bool actual) async {
    try {
      await _supabase
          .from('empleados_negocio')
          .update({'activo': !actual})
          .eq('id', empId);
      _fetchEmpleados();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Equipo de Técnicos")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEmployeeDialog,
        icon: const Icon(Icons.person_add),
        label: const Text("Nuevo"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _empleados.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text("No tienes empleados aún."),
                  const Text(
                    "Agrega usuarios por su correo.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _fetchEmpleados,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refrescar Lista"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _empleados.length,
              itemBuilder: (context, index) {
                final emp = _empleados[index];
                final perfil =
                    emp['perfiles']; // Puede ser null si la política RLS falla
                final activo = emp['activo'] as bool;

                // Manejo seguro de nulos
                final nombre = perfil != null
                    ? perfil['nombre_completo']
                    : "Usuario (Sin acceso al nombre)";
                final email = perfil != null ? perfil['email'] : "Email oculto";

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: activo ? Colors.blue : Colors.grey,
                      child: Text(
                        nombre.isNotEmpty ? nombre[0].toUpperCase() : "?",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      nombre,
                      style: TextStyle(
                        decoration: activo ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email),
                        Text(
                          activo ? "🟢 Activo" : "🔴 Inactivo",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
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

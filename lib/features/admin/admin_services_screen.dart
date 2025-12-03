import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _servicios = [];
  bool _isLoading = true;
  String? _negocioId;

  @override
  void initState() {
    super.initState();
    _fetchServicios();
  }

  Future<void> _fetchServicios() async {
    final userId = _supabase.auth.currentUser!.id;
    try {
      // 1. Obtener ID del negocio
      final negocioRes = await _supabase
          .from('negocios')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();

      if (negocioRes == null) return; // No tiene negocio aún
      _negocioId = negocioRes['id'];

      // 2. Obtener servicios
      final res = await _supabase
          .from('servicios_catalogo')
          .select()
          .eq('negocio_id', _negocioId!)
          .order('nombre');

      if (mounted) {
        setState(() {
          _servicios = res as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error servicios: $e");
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? servicio}) {
    final nombreCtrl = TextEditingController(text: servicio?['nombre']);
    final descCtrl = TextEditingController(text: servicio?['descripcion']);
    // final precioCtrl = TextEditingController(text: servicio?['precio_base_sugerido']?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(servicio == null ? "Nuevo Servicio" : "Editar Servicio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: "Nombre (Ej: Sofá 3 Plazas)",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: "Descripción (Opcional)",
              ),
            ),
            // TextField(controller: precioCtrl, decoration: InputDecoration(labelText: "Precio Base Sugerido"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.isEmpty) return;

              if (servicio == null) {
                // INSERTAR
                await _supabase.from('servicios_catalogo').insert({
                  'negocio_id': _negocioId,
                  'nombre': nombreCtrl.text,
                  'descripcion': descCtrl.text,
                  'activo': true,
                });
              } else {
                // EDITAR
                await _supabase
                    .from('servicios_catalogo')
                    .update({
                      'nombre': nombreCtrl.text,
                      'descripcion': descCtrl.text,
                    })
                    .eq('id', servicio['id']);
              }

              Navigator.pop(ctx);
              _fetchServicios();
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActivo(String id, bool actual) async {
    await _supabase
        .from('servicios_catalogo')
        .update({'activo': !actual})
        .eq('id', id);
    _fetchServicios();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Servicios / Catálogo")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _servicios.isEmpty
          ? const Center(
              child: Text(
                "Agrega servicios para que tus clientes puedan pedir.",
              ),
            )
          : ListView.builder(
              itemCount: _servicios.length,
              itemBuilder: (context, index) {
                final s = _servicios[index];
                return ListTile(
                  title: Text(
                    s['nombre'],
                    style: TextStyle(
                      decoration: s['activo']
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(s['descripcion'] ?? ''),
                  trailing: Switch(
                    value: s['activo'],
                    onChanged: (val) => _toggleActivo(s['id'], s['activo']),
                  ),
                  onLongPress: () => _showAddEditDialog(servicio: s),
                );
              },
            ),
    );
  }
}

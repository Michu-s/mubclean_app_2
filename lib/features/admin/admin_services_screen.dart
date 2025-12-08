import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

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

  // Colores corporativos
  final Color _primaryBlue = const Color(0xFF1565C0);
  final Color _bgLight = const Color(0xFFF5F9FF);

  @override
  void initState() {
    super.initState();
    _fetchServicios();
  }

  Future<void> _fetchServicios() async {
    final userId = _supabase.auth.currentUser!.id;
    try {
      final negocioRes = await _supabase
          .from('negocios')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();

      if (negocioRes == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _negocioId = negocioRes['id'];

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarServicio(String id) async {
    // Confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar servicio?"),
        content: const Text(
          "Esta acción no se puede deshacer. Si el servicio tiene historial, considera solo desactivarlo.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('servicios_catalogo').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Servicio eliminado")));
        _fetchServicios();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error al eliminar: $e. Intenta desactivarlo en su lugar.",
            ),
          ),
        );
      }
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? servicio}) {
    final nombreCtrl = TextEditingController(text: servicio?['nombre']);
    final descCtrl = TextEditingController(text: servicio?['descripcion']);
    final precioCtrl = TextEditingController(
      text: servicio?['precio_base_sugerido']?.toString(),
    );

    File? nuevaImagen;
    String? imagenActualUrl = servicio?['imagen_url'];
    bool procesandoDialogo = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogSt) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            servicio == null ? "Nuevo Servicio" : "Editar Servicio",
            style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- SELECTOR DE IMAGEN ---
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                    );
                    if (image != null)
                      setDialogSt(() => nuevaImagen = File(image.path));
                  },
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      image: nuevaImagen != null
                          ? DecorationImage(
                              image: FileImage(nuevaImagen!),
                              fit: BoxFit.cover,
                            )
                          : (imagenActualUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(imagenActualUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                    ),
                    child: (nuevaImagen == null && imagenActualUrl == null)
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: _primaryBlue.withOpacity(0.5),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Subir Foto",
                                style: TextStyle(
                                  color: _primaryBlue.withOpacity(0.7),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 15,
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- CAMPOS ---
                TextField(
                  controller: nombreCtrl,
                  decoration: InputDecoration(
                    labelText: "Nombre del Servicio",
                    hintText: "Ej: Lavado de Sala L",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: "Descripción",
                    hintText: "Detalles, beneficios...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: precioCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Precio Base (Opcional)",
                    prefixText: "\$ ",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // --- BOTÓN ELIMINAR (Solo en edición) ---
                if (servicio != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  TextButton.icon(
                    onPressed: () async {
                      // Confirmar borrado dentro del diálogo
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (alertCtx) => AlertDialog(
                          title: const Text("¿Estás seguro?"),
                          content: const Text(
                            "Se eliminará este servicio del catálogo.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(alertCtx, false),
                              child: const Text("No"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(alertCtx, true),
                              child: const Text(
                                "Sí, eliminar",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmar == true) {
                        Navigator.pop(ctx); // Cierra diálogo edición
                        _eliminarServicio(servicio['id']); // Llama borrado
                      }
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      "Eliminar Servicio",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: procesandoDialogo ? null : () => Navigator.pop(ctx),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: procesandoDialogo
                  ? null
                  : () async {
                      if (nombreCtrl.text.isEmpty) return;

                      setDialogSt(
                        () => procesandoDialogo = true,
                      ); // Bloquear botón

                      try {
                        // 1. Subir imagen si cambió
                        String? finalUrl = imagenActualUrl;
                        if (nuevaImagen != null) {
                          final fileName =
                              'servicios/${_negocioId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          // Usamos el bucket 'muebles' que ya tienes configurado
                          await _supabase.storage
                              .from('muebles')
                              .upload(fileName, nuevaImagen!);
                          finalUrl = _supabase.storage
                              .from('muebles')
                              .getPublicUrl(fileName);
                        }

                        final precioDouble =
                            double.tryParse(precioCtrl.text) ?? 0.0;

                        // 2. Insertar o Actualizar
                        if (servicio == null) {
                          await _supabase.from('servicios_catalogo').insert({
                            'negocio_id': _negocioId,
                            'nombre': nombreCtrl.text,
                            'descripcion': descCtrl.text,
                            'precio_base_sugerido': precioDouble,
                            'imagen_url': finalUrl,
                            'activo': true,
                          });
                        } else {
                          await _supabase
                              .from('servicios_catalogo')
                              .update({
                                'nombre': nombreCtrl.text,
                                'descripcion': descCtrl.text,
                                'precio_base_sugerido': precioDouble,
                                'imagen_url': finalUrl,
                              })
                              .eq('id', servicio['id']);
                        }

                        if (mounted) {
                          Navigator.pop(ctx);
                          _fetchServicios();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Guardado exitosamente"),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint("Error guardando: $e");
                        setDialogSt(
                          () => procesandoDialogo = false,
                        ); // Desbloquear
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: procesandoDialogo
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActivo(String id, bool actual) async {
    // Feedback optimista (opcional) o solo recargar
    await _supabase
        .from('servicios_catalogo')
        .update({'activo': !actual})
        .eq('id', id);
    _fetchServicios();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text(
          "Catálogo de Servicios",
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryBlue),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: _primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Nuevo Servicio",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryBlue))
          : _servicios.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Tu catálogo está vacío",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Agrega servicios para empezar a vender.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                80,
              ), // Espacio para FAB
              itemCount: _servicios.length,
              itemBuilder: (context, index) {
                final s = _servicios[index];
                final precio = s['precio_base_sugerido'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0, // Diseño plano moderno
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  color: Colors.white,
                  child: InkWell(
                    onTap: () => _showAddEditDialog(servicio: s),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // FOTO
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[100],
                              child: s['imagen_url'] != null
                                  ? Image.network(
                                      s['imagen_url'],
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey[300],
                                    ),
                            ),
                          ),
                          const SizedBox(width: 15),

                          // INFO
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['nombre'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: s['activo']
                                        ? null
                                        : TextDecoration.lineThrough,
                                    color: s['activo']
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (s['descripcion'] != null)
                                  Text(
                                    s['descripcion'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                if (precio != null && precio > 0)
                                  Text(
                                    "\$${precio}",
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // SWITCH
                          Column(
                            children: [
                              Switch(
                                value: s['activo'],
                                activeColor: Colors.green,
                                onChanged: (val) =>
                                    _toggleActivo(s['id'], s['activo']),
                              ),
                              Text(
                                s['activo'] ? "Activo" : "Inactivo",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

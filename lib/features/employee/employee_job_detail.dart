import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../shared/models/marketplace_models.dart';

class EmployeeJobDetail extends StatefulWidget {
  final Solicitud solicitud;

  const EmployeeJobDetail({super.key, required this.solicitud});

  @override
  State<EmployeeJobDetail> createState() => _EmployeeJobDetailState();
}

class _EmployeeJobDetailState extends State<EmployeeJobDetail> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _items = [];
  bool _isLoading = true;
  File? _fotoEvidencia;
  final _comentarioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      // Traemos items Y sus fotos para que el técnico sepa qué limpiar
      // Nota: fotos_solicitud(foto_url) requiere que la relación esté bien definida en Supabase
      final res = await _supabase
          .from('items_solicitud')
          .select('*, servicios_catalogo(nombre), fotos_solicitud(foto_url)')
          .eq('solicitud_id', widget.solicitud.id);

      if (mounted) {
        setState(() {
          _items = res as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error cargando items: $e");
    }
  }

  Future<void> _abrirMapa() async {
    // Intenta abrir la búsqueda de la dirección
    final query = Uri.encodeComponent(widget.solicitud.direccion);
    final googleUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$query",
    );

    // Fallback a Waze si es necesario, o abrir selector de apps
    try {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("No se pudo abrir mapas")));
    }
  }

  Future<void> _iniciarTrabajo() async {
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('solicitudes')
          .update({'estado': 'en_proceso'})
          .eq('id', widget.solicitud.id);

      if (!mounted) return;
      // Recargar la pantalla actual o volver atrás para refrescar lista
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al iniciar: $e")));
      }
    }
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (picked != null) {
      setState(() => _fotoEvidencia = File(picked.path));
    }
  }

  Future<void> _finalizarTrabajo() async {
    if (_fotoEvidencia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Foto obligatoria para terminar")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Subir Foto
      final fileName =
          'evidencia_${widget.solicitud.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from('evidencias')
          .upload(fileName, _fotoEvidencia!);
      final publicUrl = _supabase.storage
          .from('evidencias')
          .getPublicUrl(fileName);

      // 2. Guardar registro de evidencia
      await _supabase.from('evidencia_final').insert({
        'solicitud_id': widget.solicitud.id,
        'foto_url': publicUrl,
        'comentario_tecnico': _comentarioCtrl.text,
      });

      // 3. Cerrar solicitud
      await _supabase
          .from('solicitudes')
          .update({
            'estado': 'completada',
            'fecha_completado': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.solicitud.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("¡Trabajo Terminado! 🏆")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al finalizar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iniciado = widget.solicitud.estado == EstadoSolicitud.en_proceso;

    return Scaffold(
      appBar: AppBar(title: const Text("Hoja de Trabajo")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- TARJETA DE DIRECCIÓN ---
                  Card(
                    color: Colors.blue[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 40,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.solicitud.direccion,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _abrirMapa,
                            icon: const Icon(Icons.map),
                            label: const Text("ABRIR MAPA / WAZE"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- LISTA DE TAREAS ---
                  const Text(
                    "Lista de Muebles:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),

                  if (_items.isEmpty)
                    const Text(
                      "No se encontraron detalles de items.",
                      style: TextStyle(color: Colors.grey),
                    ),

                  ..._items.map((item) {
                    // Extraemos las fotos de referencia del cliente
                    final fotos =
                        item['fotos_solicitud'] as List<dynamic>? ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    "${item['cantidad']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item['servicios_catalogo']['nombre'] ??
                                        'Servicio',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item['descripcion_item'] != null &&
                                item['descripcion_item'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 5,
                                  left: 50,
                                ),
                                child: Text(
                                  item['descripcion_item'],
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),

                            // --- FOTOS DE REFERENCIA (LO QUE SUBIÓ EL CLIENTE) ---
                            if (fotos.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Text(
                                "Referencia del cliente:",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 80,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: fotos.length,
                                  itemBuilder: (ctx, i) => GestureDetector(
                                    onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: Image.network(
                                          fotos[i]['foto_url'],
                                        ),
                                      ),
                                    ),
                                    child: Container(
                                      width: 80,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            fotos[i]['foto_url'],
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  const Divider(height: 40),

                  // --- ZONA DE ACCIÓN ---
                  if (!iniciado)
                    // Opción A: Aún no inicia -> Botón para iniciar
                    SlideActionBtn(onSlide: _iniciarTrabajo)
                  else
                    // Opción B: Ya inició -> Formulario de Cierre
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Finalizar Servicio",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Cámara
                        GestureDetector(
                          onTap: _tomarFoto,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(12),
                              image: _fotoEvidencia != null
                                  ? DecorationImage(
                                      image: FileImage(_fotoEvidencia!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _fotoEvidencia == null
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        "Tocar para tomar foto de evidencia",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Comentario
                        TextField(
                          controller: _comentarioCtrl,
                          decoration: const InputDecoration(
                            labelText: "Notas del técnico (opcional)",
                            border: OutlineInputBorder(),
                            hintText:
                                "Ej: Se limpió mancha difícil, cliente satisfecho.",
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),

                        // Botón Final
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _finalizarTrabajo,
                            icon: const Icon(Icons.check_circle),
                            label: const Text("TERMINAR Y SUBIR EVIDENCIA"),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

// Botón visual para iniciar
class SlideActionBtn extends StatelessWidget {
  final VoidCallback onSlide;
  const SlideActionBtn({super.key, required this.onSlide});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onSlide,
        icon: const Icon(Icons.play_arrow),
        label: const Text("LLEGUÉ AL DOMICILIO - INICIAR"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(20),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

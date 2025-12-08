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

  // Variables para cierre
  File? _fotoEvidencia;
  final _comentarioCtrl = TextEditingController();
  bool _subiendo = false;

  // Colores corporativos
  final Color _primaryBlue = const Color(0xFF1565C0);
  final Color _bgLight = const Color(0xFFF5F9FF);

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
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
    }
  }

  Future<void> _abrirMapa() async {
    final query = Uri.encodeComponent(widget.solicitud.direccion);
    final googleUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$query",
    );
    try {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir el mapa")),
        );
    }
  }

  Future<void> _iniciarTrabajo() async {
    setState(() => _subiendo = true);
    await _supabase
        .from('solicitudes')
        .update({'estado': 'en_proceso'})
        .eq('id', widget.solicitud.id);
    if (mounted) Navigator.pop(context);
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

  Future<void> _confirmarFinalizar() async {
    if (_fotoEvidencia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "📸 FOTO OBLIGATORIA: Debes subir una foto del trabajo terminado.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Finalizar Servicio"),
        content: const Text(
          "¿Confirmas que el trabajo está terminado y la evidencia es correcta?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Cierra dialogo
              _ejecutarFinalizacion(); // Ejecuta lógica
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Sí, Finalizar"),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarFinalizacion() async {
    setState(() => _subiendo = true);
    try {
      // 1. Subir Foto al Bucket 'evidencias'
      final fileName =
          '${widget.solicitud.id}_end_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from('evidencias')
          .upload(fileName, _fotoEvidencia!);
      final url = _supabase.storage.from('evidencias').getPublicUrl(fileName);

      // 2. Guardar registro en tabla evidencia_final
      await _supabase.from('evidencia_final').insert({
        'solicitud_id': widget.solicitud.id,
        'foto_url': url,
        'comentario_tecnico': _comentarioCtrl.text,
      });

      // 3. Actualizar estado de la solicitud a 'completada'
      await _supabase
          .from('solicitudes')
          .update({
            'estado': 'completada',
            'fecha_completado': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.solicitud.id);

      if (mounted) {
        Navigator.pop(context); // Cierra la pantalla
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Trabajo Completado! Cliente notificado. 🏆"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error al finalizar: $e");
      if (mounted) {
        setState(() => _subiendo = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iniciado = widget.solicitud.estado == EstadoSolicitud.en_proceso;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text(
          "Hoja de Trabajo",
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _primaryBlue),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- TARJETA DIRECCIÓN ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 40,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.solicitud.direccion,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _abrirMapa,
                            icon: const Icon(Icons.map),
                            label: const Text("ABRIR GPS"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryBlue,
                              side: BorderSide(color: _primaryBlue),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // --- TÍTULO SECCIÓN ---
                  Text(
                    "📋 TAREAS A REALIZAR",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // --- LISTA DE ITEMS ---
                  if (_items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "Cargando detalles...",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),

                  ..._items.map((item) {
                    final fotos =
                        item['fotos_solicitud'] as List<dynamic>? ?? [];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "${item['cantidad']}x",
                                  style: TextStyle(
                                    color: _primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  item['servicios_catalogo']['nombre'],
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
                              padding: const EdgeInsets.only(top: 8, left: 2),
                              child: Text(
                                "Nota: ${item['descripcion_item']}",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                ),
                              ),
                            ),

                          // FOTOS CARRUSEL
                          if (fotos.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 70,
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
                                    width: 70,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
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
                    );
                  }),

                  const SizedBox(height: 30),

                  // --- ZONA DE ACCIÓN (FOOTER) ---
                  if (_subiendo)
                    Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: _primaryBlue),
                          const SizedBox(height: 10),
                          const Text("Guardando evidencia..."),
                        ],
                      ),
                    )
                  else if (!iniciado)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _iniciarTrabajo,
                        icon: const Icon(Icons.play_circle_fill),
                        label: const Text("LLEGUÉ AL DOMICILIO - INICIAR"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.timer, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                "Trabajo en curso",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 30),
                          const Text(
                            "Evidencia Final",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // CÁMARA
                          GestureDetector(
                            onTap: _tomarFoto,
                            child: Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid,
                                ),
                                image: _fotoEvidencia != null
                                    ? DecorationImage(
                                        image: FileImage(_fotoEvidencia!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _fotoEvidencia == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt_outlined,
                                          size: 40,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          "Tocar para foto",
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 15),

                          // INPUT COMENTARIO
                          TextField(
                            controller: _comentarioCtrl,
                            decoration: InputDecoration(
                              hintText: "Comentarios finales...",
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),

                          // BOTÓN FINALIZAR
                          SizedBox(
                            height: 55,
                            child: ElevatedButton(
                              onPressed:
                                  _confirmarFinalizar, // Usamos la confirmación
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "FINALIZAR SERVICIO",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

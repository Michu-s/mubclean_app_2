import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class AdminBusinessEditScreen extends StatefulWidget {
  const AdminBusinessEditScreen({super.key});

  @override
  State<AdminBusinessEditScreen> createState() =>
      _AdminBusinessEditScreenState();
}

class _AdminBusinessEditScreenState extends State<AdminBusinessEditScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _negocioId;

  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  String? _logoUrl;
  String? _portadaUrl;
  File? _nuevoLogo;
  File? _nuevaPortada;

  @override
  void initState() {
    super.initState();
    _cargarNegocio();
  }

  Future<void> _cargarNegocio() async {
    final userId = _supabase.auth.currentUser!.id;
    try {
      final res = await _supabase
          .from('negocios')
          .select()
          .eq('owner_id', userId)
          .single();

      _negocioId = res['id'];

      setState(() {
        _nombreCtrl.text = res['nombre'];
        _descCtrl.text = res['descripcion'] ?? '';
        _telCtrl.text = res['telefono_contacto'] ?? '';
        _logoUrl = res['logo_url'];
        _portadaUrl = res['portada_url'];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error negocio: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(bool esPortada) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );
    if (picked != null) {
      setState(() {
        if (esPortada) {
          _nuevaPortada = File(picked.path);
        } else {
          _nuevoLogo = File(picked.path);
        }
      });
    }
  }

  Future<void> _guardar() async {
    setState(() => _isLoading = true);
    try {
      String? logoFinal = _logoUrl;
      String? portadaFinal = _portadaUrl;

      // Subir Logo si cambió (usa bucket 'muebles' o crea uno 'negocios')
      if (_nuevoLogo != null) {
        final path =
            'logos/$_negocioId-${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('muebles').upload(path, _nuevoLogo!);
        logoFinal = _supabase.storage.from('muebles').getPublicUrl(path);
      }

      // Subir Portada si cambió
      if (_nuevaPortada != null) {
        final path =
            'portadas/$_negocioId-${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('muebles').upload(path, _nuevaPortada!);
        portadaFinal = _supabase.storage.from('muebles').getPublicUrl(path);
      }

      await _supabase
          .from('negocios')
          .update({
            'nombre': _nombreCtrl.text,
            'descripcion': _descCtrl.text,
            'telefono_contacto': _telCtrl.text,
            'logo_url': logoFinal,
            'portada_url': portadaFinal,
          })
          .eq('id', _negocioId!);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Negocio actualizado")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Editar mi Negocio")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PORTADA
            GestureDetector(
              onTap: () => _pickImage(true),
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                  image: _nuevaPortada != null
                      ? DecorationImage(
                          image: FileImage(_nuevaPortada!),
                          fit: BoxFit.cover,
                        )
                      : (_portadaUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_portadaUrl!),
                                fit: BoxFit.cover,
                              )
                            : null),
                ),
                child: Center(
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white.withOpacity(0.8),
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                "Toque arriba para cambiar Portada",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),

            // LOGO
            Center(
              child: GestureDetector(
                onTap: () => _pickImage(false),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue[100],
                  backgroundImage: _nuevoLogo != null
                      ? FileImage(_nuevoLogo!)
                      : (_logoUrl != null
                            ? NetworkImage(_logoUrl!) as ImageProvider
                            : null),
                  child: (_nuevoLogo == null && _logoUrl == null)
                      ? const Icon(Icons.store, size: 40)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                "Toque para cambiar Logo",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 30),
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: "Nombre del Negocio",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: "Descripción",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _telCtrl,
              decoration: const InputDecoration(
                labelText: "Teléfono Público",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardar,
                child: const Text("GUARDAR CAMBIOS"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

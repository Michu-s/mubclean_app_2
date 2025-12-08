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

  final Color _primaryBlue = const Color(0xFF1565C0);

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
        if (esPortada)
          _nuevaPortada = File(picked.path);
        else
          _nuevoLogo = File(picked.path);
      });
    }
  }

  Future<void> _guardar() async {
    setState(() => _isLoading = true);
    try {
      String? logoFinal = _logoUrl;
      String? portadaFinal = _portadaUrl;

      if (_nuevoLogo != null) {
        final path =
            'logos/$_negocioId-${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('muebles').upload(path, _nuevoLogo!);
        logoFinal = _supabase.storage.from('muebles').getPublicUrl(path);
      }

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return Scaffold(
        backgroundColor: const Color(0xFFF5F9FF),
        body: Center(child: CircularProgressIndicator(color: _primaryBlue)),
      );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(
          "Editar mi Negocio",
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryBlue),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // PORTADA
            GestureDetector(
              onTap: () => _pickImage(true),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Portada del Negocio",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // LOGO
            GestureDetector(
              onTap: () => _pickImage(false),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: _nuevoLogo != null
                        ? FileImage(_nuevoLogo!)
                        : (_logoUrl != null
                              ? NetworkImage(_logoUrl!) as ImageProvider
                              : null),
                    child: (_nuevoLogo == null && _logoUrl == null)
                        ? Icon(Icons.store, size: 40, color: _primaryBlue)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // INPUTS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nombreCtrl,
                    decoration: InputDecoration(
                      labelText: "Nombre Comercial",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      labelText: "Descripción",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _telCtrl,
                    decoration: InputDecoration(
                      labelText: "Teléfono Público",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "GUARDAR CAMBIOS",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

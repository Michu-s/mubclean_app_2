import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/models/marketplace_models.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Datos del perfil
  Perfil? _perfil;
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  // Para la foto
  File? _imagenNueva;
  String? _avatarUrlActual;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser!.id;

    try {
      final data = await _supabase
          .from('perfiles')
          .select()
          .eq('id', userId)
          .single();

      _perfil = Perfil.fromJson(data);

      if (mounted) {
        setState(() {
          _nombreCtrl.text = _perfil!.nombreCompleto;
          // Asumimos que agregamos el campo 'telefono' al modelo Perfil, si no está, lo manejamos manual
          _telefonoCtrl.text = data['telefono'] ?? '';
          _avatarUrlActual = _perfil!.fotoUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error perfil: $e");
    }
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (picked != null) {
      setState(() => _imagenNueva = File(picked.path));
    }
  }

  Future<void> _guardarCambios() async {
    if (_nombreCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("El nombre es obligatorio")));
      return;
    }

    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser!.id;

    try {
      String? avatarUrlFinal = _avatarUrlActual;

      // 1. Si hay imagen nueva, subirla
      if (_imagenNueva != null) {
        final fileExt = _imagenNueva!.path.split('.').last;
        final fileName =
            '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await _supabase.storage
            .from('avatars')
            .upload(
              fileName,
              _imagenNueva!,
              fileOptions: const FileOptions(upsert: true),
            );
        avatarUrlFinal = _supabase.storage
            .from('avatars')
            .getPublicUrl(fileName);
      }

      // 2. Actualizar datos en BD
      await _supabase
          .from('perfiles')
          .update({
            'nombre_completo': _nombreCtrl.text,
            'telefono': _telefonoCtrl.text,
            'foto_perfil_url': avatarUrlFinal,
          })
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado correctamente")),
        );
        setState(() => _isLoading = false);
        Navigator.pop(context); // Volver
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Perfil")),
      body: _isLoading && _perfil == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // --- AVATAR ---
                  GestureDetector(
                    onTap: _seleccionarFoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _imagenNueva != null
                              ? FileImage(_imagenNueva!)
                              : (_avatarUrlActual != null
                                    ? NetworkImage(_avatarUrlActual!)
                                          as ImageProvider
                                    : null),
                          child:
                              (_imagenNueva == null && _avatarUrlActual == null)
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- DATOS ---
                  TextField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nombre Completo",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Teléfono",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Solo lectura
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Correo Electrónico",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFFF0F0F0),
                    ),
                    child: Text(
                      _perfil?.email ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Rol en el sistema",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFFF0F0F0),
                    ),
                    child: Text(
                      _perfil?.rol.toUpperCase() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : const Text("GUARDAR CAMBIOS"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

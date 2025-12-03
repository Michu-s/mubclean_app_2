import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/marketplace_models.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Perfil? _perfilActual;
  Perfil? get perfilActual => _perfilActual;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadUserProfile() async {
    final user = currentUser;
    if (user == null) return;

    try {
      // USAMOS maybeSingle() PARA EVITAR EL ERROR 404 SI NO EXISTE AÚN
      final data = await _supabase
          .from('perfiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _perfilActual = Perfil.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error cargando perfil: $e");
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.auth.signInWithPassword(email: email, password: password);
      await loadUserProfile();

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Error inesperado: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- NUEVA FUNCIÓN: REGISTRO ---

  // --- NUEVA FUNCIÓN: REGISTRO CON METADATA ---
  Future<String?> signUp({
    required String email,
    required String password,
    required String nombre,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Crear usuario Y pasar el nombre como metadata
      // El Trigger en SQL leerá este 'nombre_completo' y creará el perfil.
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'nombre_completo': nombre, // <--- ¡AQUÍ ESTÁ LA CLAVE!
        },
      );

      final user = res.user;
      if (user == null) return "Error al crear usuario";

      // 2. YA NO HACEMOS EL INSERT MANUAL AQUÍ.
      // El Trigger de SQL se encarga de llenar la tabla 'perfiles'.

      // 3. Intentamos cargar el perfil (puede fallar si el email no está confirmado, es normal)
      await loadUserProfile();

      // Si el usuario necesita confirmar email, loadUserProfile será null,
      // pero el registro fue exitoso.
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Error inesperado: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _perfilActual = null;
    notifyListeners();
  }
}

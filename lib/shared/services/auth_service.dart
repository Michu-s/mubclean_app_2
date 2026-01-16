import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_models.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSub;

  Perfil? _perfilActual;
  Perfil? get perfilActual => _perfilActual;

  User? get currentUser => _supabase.auth.currentUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  AuthService() {
    _authSub = _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;

      if (event == AuthChangeEvent.signedOut) {
        _perfilActual = null;
        notifyListeners();
        return;
      }

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.userUpdated ||
          event == AuthChangeEvent.tokenRefreshed) {
        await loadUserProfile();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<String?> signIn(String email, String password) async {
    try {
      _setLoading(true);
      await _supabase.auth.signInWithPassword(email: email, password: password);
      await loadUserProfile();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error inesperado: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _perfilActual = null;
    notifyListeners();
  }

  Future<void> loadUserProfile() async {
    final user = currentUser;
    if (user == null) {
      _perfilActual = null;
      notifyListeners();
      return;
    }

    try {
      final data = await _supabase
          .from('usuarios')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        _perfilActual = Perfil(
          id: user.id,
          email: user.email ?? '',
          nombreCompleto: 'Usuario',
          rol: 'cliente',
          fotoUrl: null,
        );
      } else {
        _perfilActual = Perfil.fromJson(data);
      }

      notifyListeners();
    } catch (_) {
      // Si hay error de red/RLS/etc., evitamos romper la app.
      // Dejamos el perfil en null para que el AuthGate muestre loading.
      _perfilActual = null;
      notifyListeners();
    }
  }

  /// Registro:
  /// 1) Crea usuario en auth.users (email/password)
  /// 2) Inserta perfil en usuarios (id/email/nombre_completo)
  ///
  /// Retorna null si todo sale bien, o un mensaje de error si falla.
  Future<String?> signUp({
    required String email,
    required String password,
    required String nombre,
  }) async {
    try {
      _setLoading(true);

      // 1) Creamos el usuario en Supabase Auth
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'nombre_completo': nombre},
      );

      final User? user = res.user;

      // Si no regresa el user por alguna config rara
      if (user == null) {
        return 'No se pudo crear el usuario. Intenta nuevamente.';
      }

      // 2) Insertamos perfil en usuarios
      // IMPORTANTE: id debe ser el mismo que auth.users.id
      //
      // NOTA:
      // Si tienes "Email confirmation" activa y NO hay sesión,
      // este insert puede fallar por RLS si exige authenticated.
      // Por eso te dejo abajo el SQL con TRIGGER recomendado para que siempre funcione.
      await _supabase.from('usuarios').upsert({
        'id': user.id,
        'email': email,
        'nombre_completo': nombre,
        // campos opcionales:
        // 'telefono': null,
        // 'whatsapp': null,
        // 'url_foto_perfil': null,
      }, onConflict: 'id');

      return null;
    } on AuthException catch (e) {
      return e.message;
    } on PostgrestException catch (e) {
      // Aquí cae cuando RLS bloquea el insert o hay error SQL
      return e.message;
    } catch (e) {
      return 'Error inesperado: $e';
    } finally {
      _setLoading(false);
    }
  }
}

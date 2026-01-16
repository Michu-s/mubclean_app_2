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
      if (kDebugMode) {
        debugPrint('Cargando perfil desde tabla: perfiles (id=${user.id})');
      }

      var data = await _supabase
          .from('perfiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      // 2. Si no existe, intentar recuperar de 'usuarios' (tabla antigua) y migrar
      if (data == null) {
        try {
          final oldUser = await _supabase
              .from('usuarios')
              .select('*')
              .eq('id', user.id)
              .maybeSingle();

          if (oldUser != null) {
            // Migrar datos existentes
            await _supabase.from('perfiles').upsert({
              'id': user.id,
              'email': oldUser['email'],
              'nombre_completo': oldUser['nombre_completo'],
              'rol': 'cliente',
              'telefono': oldUser['telefono'],
              'foto_perfil_url': oldUser['url_foto_perfil'],
            });
          } else {
            // Crear nuevo perfil por defecto
            await _supabase.from('perfiles').upsert({
              'id': user.id,
              'email': user.email,
              'nombre_completo':
                  user.userMetadata?['nombre_completo'] ?? 'Usuario',
              'rol': 'cliente',
            });
          }

          // Volver a cargar tras la migración/creación
          data = await _supabase
              .from('perfiles')
              .select('*')
              .eq('id', user.id)
              .maybeSingle();
        } catch (e) {
          debugPrint("Error migrando perfil: $e");
          // Continuamos para usar el fallback
        }
      }

      if (data != null) {
        _perfilActual = Perfil.fromJson(data);
      } else {
        // Fallback final si la base de datos falla pero tenemos sesión
        _perfilActual = Perfil(
          id: user.id,
          email: user.email ?? '',
          nombreCompleto: 'Usuario',
          rol: 'cliente',
          telefono: null,
          fotoUrl: null,
        );
      }

      notifyListeners();
    } catch (e) {
      // Si hay error de red/RLS/etc., creamos un perfil por defecto
      // para que la app pueda continuar al panel de cliente.
      if (kDebugMode) {
        debugPrint('Error cargando perfil desde perfiles: $e');
      }
      _perfilActual = Perfil(
        id: user.id,
        email: user.email ?? '',
        nombreCompleto: 'Usuario',
        rol: 'cliente',
        telefono: null,
        fotoUrl: null,
      );
      notifyListeners();
    }
  }

  /// Registro:
  /// 1) Crea usuario en auth.users (email/password)
  /// 2) El perfil se crea en public.perfiles mediante TRIGGER en Supabase
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

      // Si no regresa el user, normalmente es porque:
      // - La confirmación de email está habilitada y no se crea sesión.
      // Para el flujo actual (registro -> luego login manual), consideramos esto éxito.
      if (user != null) {
        // 2) NO insertamos manualmente en perfiles: lo hace el TRIGGER en Supabase.
        // 3) Refrescamos el estado del perfil en la app.
        await loadUserProfile();
      }

      // 2) Insertamos perfil en usuarios
      // IMPORTANTE: id debe ser el mismo que auth.users.id
      //
      // NOTA:
      // Si tienes "Email confirmation" activa y NO hay sesión,
      // este insert puede fallar por RLS si exige authenticated.
      // Por eso te dejo abajo el SQL con TRIGGER recomendado para que siempre funcione.
      await _supabase.from('perfiles').upsert({
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
      if (kDebugMode) {
        debugPrint('AuthException en signUp: ${e.message}');
      }
      return e.message;
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint('PostgrestException en signUp: ${e.message}');
      }
      return e.message;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error inesperado en signUp: $e');
      }
      return 'Error inesperado: $e';
    } finally {
      _setLoading(false);
    }
  }
}

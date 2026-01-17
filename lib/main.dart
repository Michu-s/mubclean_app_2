import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

// Imports de Servicios
import 'shared/services/auth_service.dart';
import 'features/auth/login_screen.dart';

// Imports de Funcionalidades
import 'features/customer/customer_main_screen.dart';
import 'features/admin/admin_dashboard.dart';
import 'features/employee/employee_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://mi-backend-c2yr.onrender.com';
  // const supabaseAnonKey = '...'; // Removed unused key

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0bGl0Y2FpYm9lZmN1anFybXJnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMjY1MjksImV4cCI6MjA3OTkwMjUyOX0.uNEVVt9HCCBTnKhdv3hNHDKGrb2rTJAp2wJIA24_EgE',
  );

  if (kDebugMode) {
    debugPrint('Supabase URL configurada: $supabaseUrl');
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: const MubCleanApp(),
    ),
  );
}

class MubCleanApp extends StatelessWidget {
  const MubCleanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MubClean Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: GoogleFonts.notoSansTextTheme(),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.currentUser != null) {
        auth.loadUserProfile();
      }
      _isInit = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final perfil = authService.perfilActual;

    // 1. Si no hay usuario logueado -> Login
    if (user == null) {
      return const LoginScreen();
    }

    // 2. Si hay usuario pero no se ha cargado el perfil -> Loading
    if (perfil == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Cargando perfil..."),
            ],
          ),
        ),
      );
    }

    // 3. LIMPIEZA DE DATOS (SOLUCIÓN DEL PROBLEMA)
    // Quitamos espacios en blanco y forzamos minúsculas
    final String rolLimpio = perfil.rol.trim().toLowerCase();

    // Imprimimos en consola para depuración (mira tu terminal en VS Code)
    debugPrint("🔍 DEBUG ROL: El sistema detectó el rol: '$rolLimpio'");

    // 4. Redirección basada en ROL LIMPIO
    if (rolLimpio == 'admin_negocio') {
      return const AdminDashboardScreen();
    } else if (rolLimpio == 'empleado') {
      return const EmployeeHomeScreen();
    } else {
      // Si es 'cliente' o cualquier otra cosa desconocida
      return const CustomerMainScreen();
    }
  }
}

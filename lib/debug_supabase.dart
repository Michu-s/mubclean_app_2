import 'package:supabase_flutter/supabase_flutter.dart';

// Copy params from main.dart
const supabaseUrl = 'https://wtlitcaiboefcujqrmrg.supabase.co';
const supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0bGl0Y2FpYm9lZmN1anFybXJnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMjY1MjksImV4cCI6MjA3OTkwMjUyOX0.uNEVVt9HCCBTnKhdv3hNHDKGrb2rTJAp2wJIA24_EgE';

Future<void> main() async {
  print("--- INICIANDO TEST DE CONEXION ---");

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    final supabase = Supabase.instance.client;

    print("1. Cliente inicializado. Buscando tabla 'soporte_tickets'...");

    // Try a simple select. Even if empty, it should NOT return 404/PGRST205
    final response = await supabase.from('soporte_tickets').select().limit(1);

    print("SUCCESS: La tabla existe y respondiÃ³: $response");
  } catch (e) {
    print("ERROR CRITICO: $e");
    if (e.toString().contains("PGRST205")) {
      print(
        "DIAGNOSTICO: La API sigue sin ver la tabla. Es un problema 100% de CACHE de Supabase.",
      );
    }
  }
}

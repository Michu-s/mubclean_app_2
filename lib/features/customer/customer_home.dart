import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/marketplace_models.dart';
import 'customer_wizard_screen.dart'; // Lo crearemos a continuación
import './customer_requests_screens.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Negocio> _negocios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNegocios();
  }

  Future<void> _fetchNegocios() async {
    try {
      final response = await _supabase
          .from('negocios')
          .select()
          .eq('activo', true)
          .order('nombre');

      final data = response as List<dynamic>;
      if (mounted) {
        setState(() {
          _negocios = data.map((json) => Negocio.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando negocios: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("MubClean Market"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerRequestsScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _negocios.isEmpty
          ? const Center(child: Text("No hay negocios disponibles aún."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _negocios.length,
              itemBuilder: (context, index) {
                final negocio = _negocios[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // Navegar al Wizard de Solicitud
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerWizardScreen(
                            negocioSeleccionado: negocio,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Imagen de Portada (Placeholder o NetworkImage)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            image: negocio.portadaUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(negocio.portadaUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: negocio.portadaUrl == null
                              ? const Icon(
                                  Icons.store,
                                  size: 50,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                negocio.nombre,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                negocio.descripcion ??
                                    "Servicios de limpieza profesional",
                                style: TextStyle(color: Colors.grey[600]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "4.8 (120 res)",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/marketplace_models.dart';
import 'business_profile_screen.dart'; // <--- CAMBIO: Importamos Perfil en lugar de Wizard directo

class CustomerHomeScreen extends StatefulWidget {
  final bool isActive;

  const CustomerHomeScreen({super.key, this.isActive = false});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Negocio> _negocios = [];
  bool _isLoading = true;
  final Color _primaryBlue = const Color(0xFF1565C0);

  // Timer para refresco automático
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchNegocios();
    _handleTimer();
  }

  @override
  void didUpdateWidget(CustomerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        // Al entrar, refrescamos inmediatamente y arrancamos timer
        _fetchNegocios(silent: true);
        _handleTimer();
      } else {
        // Al salir, cancelamos timer
        _stopTimer();
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _handleTimer() {
    _stopTimer();
    if (widget.isActive) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _fetchNegocios(silent: true);
      });
    }
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _fetchNegocios({bool silent = false}) async {
    // Si es silent, no ponemos isLoading = true para no flashear la UI
    if (!silent) {
      setState(() => _isLoading = true);
    }

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(
          "MubClean",
          style: TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.red[300]),
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryBlue))
          : _negocios.isEmpty
          ? const Center(child: Text("No hay negocios disponibles."))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _negocios.length,
              itemBuilder: (context, index) {
                final negocio = _negocios[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      // CAMBIO: Navegar al PERFIL DEL NEGOCIO
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BusinessProfileScreen(negocio: negocio),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // IMAGEN PORTADA
                          Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              image: negocio.portadaUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(negocio.portadaUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: negocio.portadaUrl == null
                                ? Center(
                                    child: Icon(
                                      Icons.store,
                                      size: 50,
                                      color: Colors.blue[100],
                                    ),
                                  )
                                : null,
                          ),

                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        negocio.nombre,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 14,
                                            color: Colors.green,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            "4.8",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  negocio.descripcion ??
                                      "Expertos en limpieza de muebles y tapicería.",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    // CAMBIO: Navegar al PERFIL DEL NEGOCIO
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BusinessProfileScreen(
                                          negocio: negocio,
                                        ),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _primaryBlue,
                                      side: BorderSide(color: _primaryBlue),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text("VER SERVICIOS"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importar Supabase

class MercadoPagoService {
  // URL del backend de producción en Render
  final String _baseUrl = 'https://mi-backend-c2yr.onrender.com';

  Future<void> createPreferenceAndOpenCheckout({
    required BuildContext context,
    String? title, // Hacemos opcional para la prueba
    int? quantity, // Hacemos opcional para la prueba
    double? price, // Hacemos opcional para la prueba
  }) async {
    final url = Uri.parse('$_baseUrl/create_preference');

    // Obtener el token de acceso del usuario actual de Supabase
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw 'Usuario no autenticado. No se puede crear la preferencia.';
    }
    final accessToken = session.accessToken;

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken', // Enviar el token JWT
        },
        body: json.encode({
          // Valores predefinidos para la prueba. ¡REVERTIR ESTO DESPUÉS DE PROBAR!
          'title': 'Servicio de Prueba MubClean',
          'quantity': 1,
          'unit_price': 2000.00,
        }),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final String checkoutUrl = body['init_point'];

        // Lanza la URL del checkout usando flutter_custom_tabs
        await _launchURL(context, checkoutUrl);
      } else {
        debugPrint('Error del servidor: ${response.body}');
        throw 'Error al crear la preferencia de pago.';
      }
    } catch (e) {
      debugPrint('Error de conexión: $e');
      throw 'No se pudo conectar con el servidor.';
    }
  }

  Future<void> _launchURL(BuildContext context, String url) async {
    final theme = Theme.of(context);
    try {
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: theme.colorScheme.primary,
          ),
          shareState: CustomTabsShareState.on,
          urlBarHidingEnabled: true,
          showTitle: true,
          closeButton: CustomTabsCloseButton(
            icon: CustomTabsCloseButtonIcons.back,
          ),
          animations: const CustomTabsAnimations(
            startEnter: 'slide_up',
            startExit: 'android:anim/fade_out',
            endEnter: 'android:anim/fade_in',
            endExit: 'slide_down',
          ),
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: theme.colorScheme.primary,
          preferredControlTintColor: Colors.white,
          barCollapsingEnabled: true,
          entersReaderIfAvailable: false,
          dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        ),
      );
    } catch (e) {
      // Si falla, podría ser porque no hay un navegador compatible.
      debugPrint(e.toString());
      throw 'No se pudo abrir el navegador.';
    }
  }
}

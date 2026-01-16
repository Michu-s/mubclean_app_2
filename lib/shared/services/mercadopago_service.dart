import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';

class MercadoPagoService {
  // Para web, 'localhost' es correcto. Para móvil, usa la IP de tu red.
  final String _baseUrl = 'http://localhost:3000';

  Future<void> createPreferenceAndOpenCheckout({
    required BuildContext context, // Se necesita para el Theme
    required String title,
    required int quantity,
    required double price,
  }) async {
    final url = Uri.parse('$_baseUrl/create_preference');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          // El backend ahora tiene valores fijos, pero mantenemos el envío
          // por si se revierte el cambio en el futuro.
          'title': title,
          'quantity': quantity,
          'unit_price': price,
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

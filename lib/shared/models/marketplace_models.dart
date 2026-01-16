// lib/shared/models/marketplace_models.dart
//import 'package:flutter/foundation.dart';

// --- ENUMS (Coinciden con PostgreSQL) ---
enum EstadoSolicitud {
  pendiente,
  cotizada,
  aceptada,
  agendada,
  completada,
  cancelada,
  en_proceso,
}

// --- CLASES ---

class Perfil {
  final String id;
  final String email;
  final String nombreCompleto;
  final String rol; // 'cliente', 'admin_negocio', 'empleado'
  final String? fotoUrl;

  Perfil({
    required this.id,
    required this.email,
    required this.nombreCompleto,
    required this.rol,
    this.fotoUrl,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: json['id'],
      email: json['email'] ?? '',
      nombreCompleto: json['nombre_completo'] ?? 'Usuario',
      rol: json['rol'] ?? 'cliente',
      fotoUrl: json['foto_perfil_url'],
    );
  }
}

class Negocio {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? portadaUrl;
  final String? logoUrl;
  final bool activo;

  Negocio({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.portadaUrl,
    this.logoUrl,
    required this.activo,
  });

  factory Negocio.fromJson(Map<String, dynamic> json) {
    return Negocio(
      id: json['id'],
      nombre: json['nombre'],
      descripcion: json['descripcion'],
      portadaUrl: json['portada_url'],
      logoUrl: json['logo_url'],
      activo: json['activo'] ?? true,
    );
  }
}

class Solicitud {
  final String id;
  final String clienteId;
  final String negocioId;
  final String direccion;
  final DateTime fechaSolicitada;
  final EstadoSolicitud estado;
  final double precioTotal;

  Solicitud({
    required this.id,
    required this.clienteId,
    required this.negocioId,
    required this.direccion,
    required this.fechaSolicitada,
    required this.estado,
    required this.precioTotal,
  });

  factory Solicitud.fromJson(Map<String, dynamic> json) {
    return Solicitud(
      id: json['id'],
      clienteId: json['cliente_id'],
      negocioId: json['negocio_id'],
      direccion: json['direccion_servicio'],
      fechaSolicitada: DateTime.parse(json['fecha_solicitada_cliente']),
      estado: EstadoSolicitud.values.firstWhere(
        (e) => e.name == json['estado'],
        orElse: () => EstadoSolicitud.pendiente,
      ),
      precioTotal: (json['precio_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TicketSoporte {
  final String id;
  final String clienteId;
  final String tipo; // 'consulta', 'incidencia', 'sugerencia', 'otro'
  final String asunto;
  final String descripcion;
  final String estado; // 'abierto', 'en_proceso', 'resuelto'
  final String? respuestaAdmin;
  final String? fotoUrl;
  final DateTime createdAt;

  TicketSoporte({
    required this.id,
    required this.clienteId,
    required this.tipo,
    required this.asunto,
    required this.descripcion,
    required this.estado,
    this.respuestaAdmin,
    this.fotoUrl,
    required this.createdAt,
  });

  factory TicketSoporte.fromJson(Map<String, dynamic> json) {
    return TicketSoporte(
      id: json['id'],
      clienteId: json['cliente_id'],
      tipo: json['tipo'],
      asunto: json['asunto'],
      descripcion: json['descripcion'],
      estado: json['estado'] ?? 'abierto',
      respuestaAdmin: json['respuesta_admin'],
      fotoUrl: json['foto_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class Resena {
  final String id;
  final String solicitudId;
  final String negocioId;
  final String clienteId;
  final int calificacion;
  final String? comentario;
  final DateTime createdAt;

  Resena({
    required this.id,
    required this.solicitudId,
    required this.negocioId,
    required this.clienteId,
    required this.calificacion,
    this.comentario,
    required this.createdAt,
  });

  factory Resena.fromJson(Map<String, dynamic> json) {
    return Resena(
      id: json['id'],
      solicitudId: json['solicitud_id'],
      negocioId: json['negocio_id'],
      clienteId: json['cliente_id'],
      calificacion: json['calificacion'],
      comentario: json['comentario'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

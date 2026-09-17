import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../db/app_database.dart';
import 'config_service.dart';

/// Envia a Google Sheets (via Apps Script) los retiros que quedaron
/// guardados localmente sin sincronizar. Se dispara:
/// - despues de guardar un retiro nuevo,
/// - cada vez que el celular recupera conexion,
/// - manualmente (pull-to-refresh).
///
/// Cada retiro tiene un id unico generado en el celular al cargarlo, no al
/// sincronizar. Eso es lo que permite reintentar sin duplicar: si el envio
/// se corta a mitad de camino, el Apps Script reconoce el id ya recibido.
class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  final _controller = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get status => _controller.stream;

  bool _sincronizando = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  void iniciarEscuchaDeConexion() {
    _connectivitySub ??= Connectivity()
        .onConnectivityChanged
        .listen((results) {
      final conectado = results.any((r) => r != ConnectivityResult.none);
      if (conectado) sincronizarPendientes();
    });
  }

  void detenerEscuchaDeConexion() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> sincronizarPendientes() async {
    if (_sincronizando) return;
    _sincronizando = true;
    _controller.add(SyncStatus.sincronizando);
    try {
      final webhookUrl = await ConfigService.instance.getWebhookUrl();
      if (webhookUrl == null || webhookUrl.isEmpty) {
        _controller.add(SyncStatus.sinConfigurar);
        return;
      }

      final pendientes = await AppDatabase.instance.retirosPendientes();
      if (pendientes.isEmpty) {
        _controller.add(SyncStatus.alDia);
        return;
      }

      var huboError = false;
      for (final retiro in pendientes) {
        try {
          final response = await http
              .post(
                Uri.parse(webhookUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(retiro.toSyncPayload()),
              )
              .timeout(const Duration(seconds: 15));

          // El Apps Script responde "ok" tanto si guardo el retiro como si
          // ya existia ese id (duplicado descartado del lado del servidor).
          if (response.statusCode == 200) {
            await AppDatabase.instance.marcarSincronizado(retiro.id);
          } else {
            huboError = true;
          }
        } catch (_) {
          huboError = true;
          // Se corta el lote: probablemente se perdio la conexion de nuevo,
          // se reintenta en la proxima corrida.
          break;
        }
      }

      _controller.add(huboError ? SyncStatus.error : SyncStatus.alDia);
    } finally {
      _sincronizando = false;
    }
  }
}

enum SyncStatus { sincronizando, alDia, error, sinConfigurar }

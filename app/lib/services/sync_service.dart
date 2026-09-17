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
  bool _reintentarAlTerminar = false;
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

  /// Si ya hay una sincronizacion en curso (por ejemplo, la del retiro
  /// anterior todavia no termino de viajar por la red) esta llamada no se
  /// pierde: queda anotada y dispara una pasada mas apenas termina la que
  /// esta corriendo, para no dejar afuera al retiro que la origino.
  Future<void> sincronizarPendientes() async {
    if (_sincronizando) {
      _reintentarAlTerminar = true;
      return;
    }
    _sincronizando = true;
    try {
      do {
        _reintentarAlTerminar = false;
        await _sincronizarUnaPasada();
      } while (_reintentarAlTerminar);
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> _sincronizarUnaPasada() async {
    _controller.add(SyncStatus.sincronizando);

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
        final response = await _postAlWebhook(
          Uri.parse(webhookUrl),
          jsonEncode(retiro.toSyncPayload()),
        );

        // No alcanza con mirar el codigo HTTP: si el deploy de Apps Script
        // no tiene acceso "Cualquier usuario", Google redirige a un login
        // que tambien responde 200 (HTML, no JSON). Solo se considera
        // sincronizado si el cuerpo es el JSON {"status":"ok"} esperado.
        final sincronizadoOk = _esRespuestaOk(response);
        if (sincronizadoOk) {
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
  }

  /// Las URLs `/exec` de Apps Script responden con un 302 hacia una URL de
  /// `googleusercontent.com` antes de ejecutar el script. El cliente HTTP de
  /// Flutter sigue esa redireccion pero, como cualquier cliente que respeta
  /// el comportamiento historico de los navegadores, convierte el POST en
  /// GET al hacerlo (y pierde el cuerpo) — por eso al servidor le llegaba un
  /// doGet en vez de un doPost. Acá seguimos la redireccion a mano,
  /// reenviando el mismo POST con el mismo cuerpo.
  Future<http.Response> _postAlWebhook(Uri url, String body) async {
    final client = http.Client();
    try {
      final headers = {'Content-Type': 'application/json'};
      var request = http.Request('POST', url)
        ..headers.addAll(headers)
        ..body = body
        ..followRedirects = false;
      var streamed =
          await client.send(request).timeout(const Duration(seconds: 15));

      const codigosRedireccion = {301, 302, 303, 307, 308};
      if (codigosRedireccion.contains(streamed.statusCode)) {
        final location = streamed.headers['location'];
        if (location != null) {
          final redirectRequest = http.Request('POST', Uri.parse(location))
            ..headers.addAll(headers)
            ..body = body;
          streamed = await client
              .send(redirectRequest)
              .timeout(const Duration(seconds: 15));
        }
      }

      return http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  bool _esRespuestaOk(http.Response response) {
    if (response.statusCode != 200) return false;
    try {
      final body = jsonDecode(response.body);
      return body is Map && body['status'] == 'ok';
    } catch (_) {
      // No era JSON: probablemente una pagina de login de Google, no la
      // respuesta del script (deploy con acceso mal configurado).
      return false;
    }
  }
}

enum SyncStatus { sincronizando, alDia, error, sinConfigurar }

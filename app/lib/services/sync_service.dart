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

  /// Detalle del ultimo problema encontrado, para mostrar en la app sin
  /// depender de revisar la planilla o el editor de Apps Script.
  String? ultimoError;

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
      http.Response response;
      try {
        response = await _postAlWebhook(
          Uri.parse(webhookUrl),
          jsonEncode(retiro.toSyncPayload()),
        );
      } catch (error) {
        // Fallo de red (se corto la conexion, timeout, etc.): no tiene
        // sentido insistir con el resto de la lista en esta pasada, se
        // reintenta todo en la proxima.
        huboError = true;
        ultimoError = 'Envio de ${retiro.id}: $error';
        break;
      }

      // No alcanza con mirar el codigo HTTP: si el deploy de Apps Script no
      // tiene acceso "Cualquier usuario", Google redirige a un login que
      // tambien responde 200 (HTML, no JSON). Solo se considera
      // sincronizado si el cuerpo es el JSON {"status":"ok"} esperado.
      if (!_esRespuestaOk(response)) {
        huboError = true;
        ultimoError =
            'Respuesta inesperada (${response.statusCode}) para ${retiro.id}';
        // Este retiro sigue pendiente, pero no bloquea a los siguientes.
        continue;
      }

      try {
        await AppDatabase.instance.marcarSincronizado(retiro.id);
      } catch (error) {
        // El servidor ya confirmo el retiro (esta bien en la planilla); si
        // falla marcarlo sincronizado en el celular no hay que perder por
        // eso a los demas retiros de la pasada. Se va a reintentar solo,
        // y el servidor lo va a reconocer como duplicado sin problema.
        huboError = true;
        ultimoError = 'No se pudo marcar ${retiro.id} como sincronizado: $error';
      }
    }

    _controller.add(huboError ? SyncStatus.error : SyncStatus.alDia);
  }

  /// Las URLs `/exec` de Apps Script ejecutan doPost() ahi mismo, con el
  /// pedido original (confirmado a mano con curl: el POST ya deja la fila
  /// escrita en la planilla). La respuesta es un 302 hacia una URL de
  /// `googleusercontent.com` que unicamente sirve para LEER el resultado ya
  /// calculado — no vuelve a ejecutar nada — y por eso solo acepta GET (un
  /// POST ahi devuelve 405). El `http.post()` con auto-redirect de la
  /// libreria tampoco sirve para esto: en una prueba tardo 33 segundos y
  /// devolvio el 302 sin seguirlo. Por eso se sigue a mano con GET.
  ///
  /// Apps Script puede tardar bastante o directamente cortar la conexion
  /// bajo pedidos seguidos (contencion del LockService del lado del
  /// servidor). Como reenviar el mismo retiro es seguro -- el servidor lo
  /// reconoce por id y no lo duplica -- se reintenta el pedido COMPLETO
  /// (no solo la lectura del resultado) unas cuantas veces antes de darse
  /// por vencido.
  Future<http.Response> _postAlWebhook(Uri url, String body) async {
    const intentosMaximos = 3;
    Object? ultimoIntentoError;
    for (var intento = 1; intento <= intentosMaximos; intento++) {
      try {
        return await _unIntentoDePostAlWebhook(url, body);
      } catch (error) {
        ultimoIntentoError = error;
        if (intento < intentosMaximos) {
          await Future.delayed(Duration(seconds: intento * 2));
        }
      }
    }
    throw ultimoIntentoError!;
  }

  Future<http.Response> _unIntentoDePostAlWebhook(Uri url, String body) async {
    final postClient = http.Client();
    late http.StreamedResponse streamed;
    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = body
        ..followRedirects = false;
      streamed =
          await postClient.send(request).timeout(const Duration(seconds: 30));
    } finally {
      postClient.close();
    }

    const codigosRedireccion = {301, 302, 303, 307, 308};
    if (!codigosRedireccion.contains(streamed.statusCode)) {
      return http.Response.fromStream(streamed);
    }
    final location = streamed.headers['location'];
    if (location == null) {
      return http.Response.fromStream(streamed);
    }
    return http.get(Uri.parse(location)).timeout(const Duration(seconds: 30));
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

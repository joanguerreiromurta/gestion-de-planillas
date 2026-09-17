import 'package:shared_preferences/shared_preferences.dart';

/// Configuracion del dispositivo: cada celular queda asociado a un chofer,
/// y apunta a la URL del Google Apps Script publicado para sincronizar.
class ConfigService {
  ConfigService._internal();
  static final ConfigService instance = ConfigService._internal();

  static const _keyChofer = 'chofer_nombre';
  static const _keyWebhookUrl = 'webhook_url';

  Future<String?> getChofer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyChofer);
  }

  Future<void> setChofer(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyChofer, nombre.trim());
  }

  Future<String?> getWebhookUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWebhookUrl);
  }

  Future<void> setWebhookUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWebhookUrl, url.trim());
  }

  Future<bool> estaConfigurado() async {
    final chofer = await getChofer();
    final url = await getWebhookUrl();
    return chofer != null && chofer.isNotEmpty && url != null && url.isNotEmpty;
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Runtime configuration for the Vail app.
/// Settings are persisted in SharedPreferences so they survive restarts.
class AppConfig {
  static const String _keyEndpoint = 'vail_endpoint';
  static const String _keyApiKey = 'vail_api_key';
  static const String _keyTheme = 'vail_theme';
  static const String _keyModel = 'vail_model';
  static const String _keyIsPro = 'vail_is_pro';

  static const String defaultEndpoint = 'http://localhost:9090';
  static const String defaultModel = 'vail-lite';

  final SharedPreferences _prefs;

  AppConfig._(this._prefs);

  static Future<AppConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppConfig._(prefs);
  }

  String get endpoint => _prefs.getString(_keyEndpoint) ?? defaultEndpoint;
  String get apiKey => _prefs.getString(_keyApiKey) ?? '';
  String get theme => _prefs.getString(_keyTheme) ?? 'dark';
  String get model => _prefs.getString(_keyModel) ?? defaultModel;
  bool get isPro => _prefs.getBool(_keyIsPro) ?? false;

  Future<void> setEndpoint(String value) => _prefs.setString(_keyEndpoint, value);
  Future<void> setApiKey(String value) => _prefs.setString(_keyApiKey, value);
  Future<void> setTheme(String value) => _prefs.setString(_keyTheme, value);
  Future<void> setModel(String value) => _prefs.setString(_keyModel, value);
  Future<void> setIsPro(bool value) => _prefs.setBool(_keyIsPro, value);
}

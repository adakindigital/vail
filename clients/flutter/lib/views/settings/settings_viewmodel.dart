import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:vail_app/core/config/app_config.dart';
import 'package:vail_app/core/constants/app_constants.dart';
import 'package:vail_app/data/services/vail_client.dart';

enum GatewayStatus { unknown, checking, online, offline }

class SettingsViewModel extends ChangeNotifier {
  final AppConfig _config = GetIt.I<AppConfig>();

  late String _endpoint = _config.endpoint;
  late String _apiKey = _config.apiKey;
  late String _selectedModel = _config.model;
  late bool _isPro = _config.isPro;
  GatewayStatus _gatewayStatus = GatewayStatus.unknown;

  String get endpoint => _endpoint;
  String get apiKey => _apiKey;
  String get selectedModel => _selectedModel;
  bool get isPro => _isPro;
  GatewayStatus get gatewayStatus => _gatewayStatus;

  List<String> get availableModels => AppConstants.modelTiers;

  Future<void> setIsPro(bool value) async {
    if (_isPro == value) return;
    _isPro = value;
    await _config.setIsPro(value);
    notifyListeners();
  }

  Future<void> saveEndpoint(String value) async {
    _endpoint = value.trim();
    await _config.setEndpoint(_endpoint);
    _gatewayStatus = GatewayStatus.unknown;
    notifyListeners();
  }

  Future<void> saveApiKey(String value) async {
    _apiKey = value.trim();
    await _config.setApiKey(_apiKey);
    notifyListeners();
  }

  Future<void> selectModel(String model) async {
    if (_selectedModel == model) return;
    _selectedModel = model;
    await _config.setModel(model);
    notifyListeners();
  }

  Future<void> checkGateway() async {
    _gatewayStatus = GatewayStatus.checking;
    notifyListeners();

    final client = VailClient(
      endpoint: _endpoint,
      apiKey: _apiKey,
      sessionId: '',
    );
    final isOnline = await client.checkHealth();
    _gatewayStatus = isOnline ? GatewayStatus.online : GatewayStatus.offline;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:vail_app/app.dart';
import 'package:vail_app/core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _registerDependencies();
  runApp(const VailApp());
}

Future<void> _registerDependencies() async {
  final config = await AppConfig.load();
  GetIt.I.registerSingleton<AppConfig>(config);
}

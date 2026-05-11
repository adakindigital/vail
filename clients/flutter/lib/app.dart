import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/views/auth/auth_viewmodel.dart';
import 'package:vail_app/views/auth/login_view.dart';
import 'package:vail_app/views/auth/register_view.dart';
import 'package:vail_app/views/shell/app_shell.dart';

class VailApp extends StatelessWidget {
  const VailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthViewModel>.value(
      value: GetIt.I<AuthViewModel>(),
      child: MaterialApp(
        title: 'Vail',
        debugShowCheckedModeBanner: false,
        theme: VailTheme.materialTheme(),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    if (auth.isAuthenticated) return const AppShell();

    return _showRegister
        ? RegisterView(onSwitchToLogin: () => setState(() => _showRegister = false))
        : LoginView(onSwitchToRegister: () => setState(() => _showRegister = true));
  }
}

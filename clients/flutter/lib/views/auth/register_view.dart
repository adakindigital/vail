import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_button.dart';
import 'package:vail_app/views/auth/auth_viewmodel.dart';

class RegisterView extends StatefulWidget {
  final VoidCallback onSwitchToLogin;

  const RegisterView({required this.onSwitchToLogin, super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _localError = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text != _confirmController.text) {
      setState(() => _localError = 'Passwords do not match');
      return;
    }
    setState(() => _localError = '');
    final auth = context.read<AuthViewModel>();
    await auth.register(_emailController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final errorText = _localError.isNotEmpty ? _localError : (auth.error.isNotEmpty ? auth.error : '');

    return Scaffold(
      backgroundColor: VailTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(VailTheme.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: VailTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(VailTheme.radiusMd),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: VailTheme.primary, size: 24),
                  ),
                ),
                const SizedBox(height: VailTheme.lg),
                Center(child: Text('CREATE ACCOUNT', style: VailTheme.display)),
                const SizedBox(height: VailTheme.xs),
                Center(child: Text('V.A.I.L.', style: VailTheme.caption)),
                const SizedBox(height: VailTheme.xxl),
                _VailTextField(
                  controller: _emailController,
                  label: 'EMAIL',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: VailTheme.md),
                _VailTextField(
                  controller: _passwordController,
                  label: 'PASSWORD',
                  hint: '••••••••',
                  obscureText: true,
                ),
                const SizedBox(height: VailTheme.md),
                _VailTextField(
                  controller: _confirmController,
                  label: 'CONFIRM PASSWORD',
                  hint: '••••••••',
                  obscureText: true,
                ),
                const SizedBox(height: VailTheme.xl),
                if (auth.isLoading)
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: VailTheme.primary),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: VailButton.primary(label: 'CREATE ACCOUNT', onTap: _submit),
                  ),
                if (errorText.isNotEmpty) ...[
                  const SizedBox(height: VailTheme.md),
                  Text(errorText, style: VailTheme.bodySmall.copyWith(color: VailTheme.error), textAlign: TextAlign.center),
                ],
                const SizedBox(height: VailTheme.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?', style: VailTheme.bodySmall),
                    TextButton(
                      onPressed: widget.onSwitchToLogin,
                      child: Text('Sign in', style: VailTheme.bodySmall.copyWith(color: VailTheme.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VailTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _VailTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VailTheme.caption),
        const SizedBox(height: VailTheme.sm),
        Container(
          decoration: BoxDecoration(
            color: VailTheme.surfaceContainerLow,
            border: Border.all(color: VailTheme.ghostBorder),
            borderRadius: BorderRadius.circular(VailTheme.radiusSm),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: VailTheme.body,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: VailTheme.bodySmall.copyWith(color: VailTheme.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: VailTheme.md, vertical: VailTheme.md),
            ),
          ),
        ),
      ],
    );
  }
}

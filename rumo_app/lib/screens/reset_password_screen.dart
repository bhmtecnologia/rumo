import 'package:flutter/material.dart';

import 'package:rumo_app/core/services/auth_service.dart';

/// Redefinir senha usando o token recebido por e-mail.
class ResetPasswordScreen extends StatefulWidget {
  final String? initialToken;

  const ResetPasswordScreen({super.key, this.initialToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) _tokenController.text = widget.initialToken!;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = _tokenController.text.trim();
    final password = _passwordController.text;
    if (token.isEmpty) {
      setState(() => _error = 'Informe o token recebido por e-mail');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'A senha deve ter no mínimo 6 caracteres');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'As senhas não conferem');
      return;
    }
    setState(() { _error = null; _loading = true; });
    try {
      await _auth.resetPassword(token, password);
      if (mounted) setState(() { _loading = false; _success = true; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Redefinir senha'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _success
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF00D95F)),
                      const SizedBox(height: 16),
                      const Text('Senha redefinida. Faça login com a nova senha.'),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        child: const Text('Ir para o login'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Cole o token que você recebeu por e-mail e defina uma nova senha.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'Token',
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirmar nova senha',
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00D95F),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Redefinir senha'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

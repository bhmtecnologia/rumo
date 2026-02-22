import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rumo_app/core/config.dart';
import 'package:rumo_app/core/models/user.dart';
import 'package:rumo_app/core/services/api_service.dart';

const _keyToken = 'rumo_auth_token';
const _keyUser = 'rumo_auth_user';

/// Autenticação local (JWT). Estrutura preparada para trocar por Firebase/Google/Microsoft depois.
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  AuthService._();

  /// Chamado quando a API retorna 401 (token inválido/expirado). O app pode redirecionar ao login.
  static void Function()? onUnauthorized;

  String? _token;
  AppUser? _user;

  String get _base => kApiBaseUrl;

  /// Token atual (para o ApiService enviar no header).
  String? get token => _token;

  /// Usuário atual, se logado.
  AppUser? get currentUser => _user;

  /// Se está autenticado.
  bool get isLoggedIn => _token != null && _user != null;

  /// Inicializar a partir do armazenamento. Chamar no startup do app.
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    final userJson = prefs.getString(_keyUser);
    if (userJson != null) {
      try {
        _user = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {
        _user = null;
      }
    } else {
      _user = null;
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null && _user != null) {
      await prefs.setString(_keyToken, _token!);
      await prefs.setString(_keyUser, jsonEncode(_user!.toJson()));
    } else {
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
    }
  }

  /// Login com e-mail e senha.
  Future<AppUser> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    if (res.statusCode != 200) {
      final msg = ApiService.errorMessage(null, res, 'E-mail ou senha incorretos');
      throw Exception(msg);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _token = data['token'] as String?;
    final userMap = data['user'] as Map<String, dynamic>?;
    if (_token == null || userMap == null) {
      throw Exception('Resposta inválida do servidor');
    }
    _user = AppUser.fromJson(userMap);
    await _saveToStorage();
    return _user!;
  }

  /// Atualiza usuário e token a partir do servidor (/me). Retorna null se token inválido.
  Future<AppUser?> refreshUser() async {
    if (_token == null) return null;
    final res = await http.get(
      Uri.parse('$_base/auth/me'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (res.statusCode != 200) {
      await logout();
      return null;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final userMap = data['user'] as Map<String, dynamic>?;
    if (userMap == null) {
      await logout();
      return null;
    }
    _user = AppUser.fromJson(userMap);
    await _saveToStorage();
    return _user;
  }

  /// Verifica se o token ainda é válido (chama /me).
  Future<bool> validateToken() async {
    if (_token == null) return false;
    final user = await refreshUser();
    return user != null;
  }

  /// Encerra sessão. Chama [onUnauthorized] se definido, para a UI atualizar (ex.: voltar ao login).
  Future<void> logout() async {
    _token = null;
    _user = null;
    await _saveToStorage();
    onUnauthorized?.call();
  }

  /// Alterar senha (usuário já logado).
  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (_token == null) throw Exception('Faça login para alterar a senha');
    final res = await http.post(
      Uri.parse('$_base/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception(ApiService.errorMessage(null, res, 'Erro ao alterar senha'));
    }
  }

  /// Solicitar recuperação de senha (e-mail).
  Future<void> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('$_base/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );
    if (res.statusCode != 200) {
      throw Exception(ApiService.errorMessage(null, res, 'Erro ao enviar e-mail'));
    }
  }

  /// Redefinir senha com o token recebido por e-mail.
  Future<void> resetPassword(String token, String newPassword) async {
    final res = await http.post(
      Uri.parse('$_base/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );
    if (res.statusCode != 200) {
      throw Exception(ApiService.errorMessage(null, res, 'Erro ao redefinir senha'));
    }
  }

  /// Cadastro (útil para primeiro usuário ou quando liberado).
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    required String profile,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'name': name.trim(),
        'profile': profile,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(ApiService.errorMessage(null, res, 'Erro ao cadastrar'));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _token = data['token'] as String?;
    final userMap = data['user'] as Map<String, dynamic>?;
    if (_token == null || userMap == null) throw Exception('Resposta inválida');
    _user = AppUser.fromJson(userMap);
    await _saveToStorage();
    return _user!;
  }
}

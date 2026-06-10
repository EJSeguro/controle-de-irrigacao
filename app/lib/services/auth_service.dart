import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class AuthService extends ChangeNotifier {
  final DatabaseService _db;

  AuthService(this._db);

  static const _key = 'accounts';
  static const _sessionKey = 'current_email';
  Map<String, String> _accounts = {};
  String? _currentEmail;
  bool _loading = true;

  String? get currentEmail => _currentEmail;
  bool get isAuthenticated => _currentEmail != null;
  bool get isLoading => _loading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      _accounts = Map<String, String>.from(jsonDecode(raw));
    }
    _migrarSenhas();
    _currentEmail = prefs.getString(_sessionKey);
    _loading = false;
    notifyListeners();
  }

  void _migrarSenhas() {
    bool alterou = false;
    for (final entry in _accounts.entries.toList()) {
      final valor = entry.value;
      if (!valor.contains(':')) {
        final salt = DatabaseService.gerarSalt();
        final hash = DatabaseService.hashSenha(valor, salt);
        _accounts[entry.key] = '$salt:$hash';
        alterou = true;
      }
    }
    if (alterou) _salvar();
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_accounts));
  }

  Future<void> _salvarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentEmail != null) {
      await prefs.setString(_sessionKey, _currentEmail!);
    } else {
      await prefs.remove(_sessionKey);
    }
  }

  Future<String> register(String email, String password) async {
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw Exception('Este e-mail já está cadastrado.');
    }
    if (password.length < 6) {
      throw Exception('A senha deve ter no mínimo 6 caracteres.');
    }
    final salt = DatabaseService.gerarSalt();
    final hash = DatabaseService.hashSenha(password, salt);
    _accounts[key] = '$salt:$hash';
    await _salvar();
    await _db.criarUsuario(key, hash, salt);
    _currentEmail = key;
    await _salvarSessao();
    notifyListeners();
    return key;
  }

  Future<String> login(String email, String password) async {
    final key = email.trim().toLowerCase();
    final stored = _accounts[key];
    if (stored == null || !stored.contains(':')) {
      throw Exception('Usuário ou senha inválidos.');
    }
    final parts = stored.split(':');
    if (parts.length != 2) {
      throw Exception('Usuário ou senha inválidos.');
    }
    final salt = parts[0];
    final hash = parts[1];
    if (!DatabaseService.verificarSenha(password, salt, hash)) {
      throw Exception('Usuário ou senha inválidos.');
    }
    await _db.criarUsuario(key, hash, salt);
    _currentEmail = key;
    await _salvarSessao();
    notifyListeners();
    return key;
  }

  Future<void> logout() async {
    _currentEmail = null;
    await _salvarSessao();
    notifyListeners();
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const _key = 'accounts';
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
    _loading = false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_accounts));
  }

  Future<String> register(String email, String password) async {
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw Exception('Este e-mail já está cadastrado.');
    }
    if (password.length < 6) {
      throw Exception('A senha deve ter no mínimo 6 caracteres.');
    }
    _accounts[key] = password;
    await _save();
    _currentEmail = key;
    notifyListeners();
    return key;
  }

  Future<String> login(String email, String password) async {
    final key = email.trim().toLowerCase();
    final stored = _accounts[key];
    if (stored == null) {
      throw Exception('Usuário não encontrado.');
    }
    if (stored != password) {
      throw Exception('Senha incorreta.');
    }
    _currentEmail = key;
    notifyListeners();
    return key;
  }

  Future<void> logout() async {
    _currentEmail = null;
    notifyListeners();
  }
}

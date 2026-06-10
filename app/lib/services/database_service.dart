import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import '../models/leitura.dart';

class ConsumoRecord {
  final DateTime data;
  final double litros;
  final int tempoSegundos;

  ConsumoRecord({
    required this.data,
    required this.litros,
    required this.tempoSegundos,
  });
}

class _LeituraEntry {
  final Leitura leitura;
  final String email;
  _LeituraEntry(this.leitura, this.email);
}

class _ConsumoEntry {
  final ConsumoRecord record;
  final String email;
  _ConsumoEntry(this.record, this.email);
}

class DatabaseService {
  static Database? _db;
  static List<_LeituraEntry>? _memoria;
  static List<_ConsumoEntry>? _memConsumo;
  static Map<String, String>? _memConfig;

  bool get _isWeb => kIsWeb;

  Future<Database> get database async {
    if (_isWeb) throw UnsupportedError('sqflite não disponível na web');
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  List<_LeituraEntry> get _mem {
    _memoria ??= [];
    return _memoria!;
  }

  List<_ConsumoEntry> get _memCons {
    _memConsumo ??= [];
    return _memConsumo!;
  }

  Map<String, String> get _memCfg {
    _memConfig ??= {};
    return _memConfig!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'irrigacao.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE leituras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data TEXT NOT NULL,
            umidade INTEGER NOT NULL,
            status_solo TEXT NOT NULL,
            tipo TEXT NOT NULL,
            usuario_email TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE consumo (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data TEXT NOT NULL,
            litros REAL NOT NULL,
            tempo_segundos INTEGER NOT NULL,
            usuario_email TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE config (
            chave TEXT NOT NULL,
            valor TEXT NOT NULL,
            usuario_email TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (chave, usuario_email)
          )
        ''');
        await _criarTabelaUsuarios(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS consumo (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              data TEXT NOT NULL,
              litros REAL NOT NULL,
              tempo_segundos INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS config (
              chave TEXT PRIMARY KEY,
              valor TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE leituras ADD COLUMN usuario_email TEXT NOT NULL DEFAULT \'\'');
          await db.execute(
              'ALTER TABLE consumo ADD COLUMN usuario_email TEXT NOT NULL DEFAULT \'\'');
          await db.execute('''
            CREATE TABLE config_nova (
              chave TEXT NOT NULL,
              valor TEXT NOT NULL,
              usuario_email TEXT NOT NULL DEFAULT '',
              PRIMARY KEY (chave, usuario_email)
            )
          ''');
          await db.execute('''
            INSERT INTO config_nova (chave, valor, usuario_email)
            SELECT chave, valor, '' FROM config
          ''');
          await db.execute('DROP TABLE config');
          await db.execute('ALTER TABLE config_nova RENAME TO config');
        }
        if (oldVersion < 4) {
          await _criarTabelaUsuarios(db);
        }
      },
    );
  }

  Future<void> salvarLeitura(Leitura leitura, {String usuarioEmail = ''}) async {
    if (_isWeb) {
      _mem.insert(0, _LeituraEntry(leitura, usuarioEmail));
      return;
    }
    final db = await database;
    await db.insert('leituras', {
      'data': leitura.data.toIso8601String(),
      'umidade': leitura.umidade,
      'status_solo': leitura.statusSolo,
      'tipo': leitura.tipo,
      'usuario_email': usuarioEmail,
    });
  }

  Future<List<Leitura>> carregarLeituras({String? usuarioEmail}) async {
    if (_isWeb) {
      var items = _mem;
      if (usuarioEmail != null) {
        items = items.where((e) => e.email == usuarioEmail).toList();
      }
      return items.map((e) => e.leitura).toList();
    }
    final db = await database;
    final where = usuarioEmail != null ? 'usuario_email = ?' : null;
    final whereArgs = usuarioEmail != null ? [usuarioEmail] : null;
    final rows = await db.query('leituras',
        where: where, whereArgs: whereArgs, orderBy: 'data DESC');
    return rows.map((row) {
      return Leitura(
        data: DateTime.parse(row['data'] as String),
        umidade: row['umidade'] as int,
        statusSolo: row['status_solo'] as String,
        tipo: row['tipo'] as String,
      );
    }).toList();
  }

  Future<void> salvarConsumo(ConsumoRecord record, {String usuarioEmail = ''}) async {
    if (_isWeb) {
      _memCons.insert(0, _ConsumoEntry(record, usuarioEmail));
      return;
    }
    final db = await database;
    await db.insert('consumo', {
      'data': record.data.toIso8601String(),
      'litros': record.litros,
      'tempo_segundos': record.tempoSegundos,
      'usuario_email': usuarioEmail,
    });
  }

  Future<List<ConsumoRecord>> carregarConsumos({String? usuarioEmail}) async {
    if (_isWeb) {
      var items = _memCons;
      if (usuarioEmail != null) {
        items = items.where((e) => e.email == usuarioEmail).toList();
      }
      return items.map((e) => e.record).toList();
    }
    final db = await database;
    final where = usuarioEmail != null ? 'usuario_email = ?' : null;
    final whereArgs = usuarioEmail != null ? [usuarioEmail] : null;
    final rows = await db.query('consumo',
        where: where, whereArgs: whereArgs, orderBy: 'data DESC');
    return rows.map((row) {
      return ConsumoRecord(
        data: DateTime.parse(row['data'] as String),
        litros: row['litros'] as double,
        tempoSegundos: row['tempo_segundos'] as int,
      );
    }).toList();
  }

  Future<void> salvarConfig(String chave, String valor, {String usuarioEmail = ''}) async {
    if (_isWeb) {
      _memCfg['$usuarioEmail:$chave'] = valor;
      return;
    }
    final db = await database;
    await db.insert(
      'config',
      {'chave': chave, 'valor': valor, 'usuario_email': usuarioEmail},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> carregarConfigs({String? usuarioEmail}) async {
    if (_isWeb) {
      if (usuarioEmail == null) return Map.from(_memCfg);
      final prefix = '$usuarioEmail:';
      return Map.fromEntries(
        _memCfg.entries
            .where((e) => e.key.startsWith(prefix))
            .map((e) => MapEntry(e.key.substring(prefix.length), e.value)),
      );
    }
    final db = await database;
    final where = usuarioEmail != null ? 'usuario_email = ?' : null;
    final whereArgs = usuarioEmail != null ? [usuarioEmail] : null;
    final rows = await db.query('config',
        where: where, whereArgs: whereArgs);
    return {for (final r in rows) r['chave'] as String: r['valor'] as String};
  }

  Future<bool> usuarioTemDados(String usuarioEmail) async {
    if (_isWeb) {
      return _mem.any((e) => e.email == usuarioEmail);
    }
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM leituras WHERE usuario_email = ?', [usuarioEmail]));
    return (count ?? 0) > 0;
  }

  Future<void> sembrarDadosMock(String usuarioEmail) async {
    final now = DateTime.now();
    final random = Random();

    for (int i = 0; i < 25; i++) {
      final data = now.subtract(Duration(hours: random.nextInt(168)));
      final umidade = random.nextInt(81) + 5;
      final status = _calcStatus(umidade);
      final tipo = random.nextBool() ? 'automática' : 'manual';

      await salvarLeitura(
        Leitura(data: data, umidade: umidade, statusSolo: status, tipo: tipo),
        usuarioEmail: usuarioEmail,
      );
    }

    for (int i = 0; i < 5; i++) {
      final data = now.subtract(Duration(days: random.nextInt(30)));
      final litros = random.nextDouble() * 50 + 5;
      final tempo = random.nextInt(120) + 10;

      await salvarConsumo(
        ConsumoRecord(data: data, litros: litros, tempoSegundos: tempo),
        usuarioEmail: usuarioEmail,
      );
    }

    await salvarConfig('intervalo_leitura', '30', usuarioEmail: usuarioEmail);
    await salvarConfig('unidade_intervalo', 'min', usuarioEmail: usuarioEmail);
    await salvarConfig('potencia_bomba', '12', usuarioEmail: usuarioEmail);
    await salvarConfig('diametro_tubulacao', '20', usuarioEmail: usuarioEmail);
  }

  static String _calcStatus(int umidade) {
    if (umidade < 20) return 'Muito seco';
    if (umidade < 45) return 'Seco';
    if (umidade < 65) return 'Ideal';
    if (umidade < 85) return 'Úmido';
    return 'Encharcado';
  }

  // ── Tabela de usuários ────────────────────────────────────

  static Future<void> _criarTabelaUsuarios(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        email TEXT PRIMARY KEY,
        senha_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        criado_em TEXT NOT NULL
      )
    ''');
  }

  static String gerarSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  static String hashSenha(String senha, String salt) {
    final salted = utf8.encode(salt + senha);
    return base64Encode(sha256.convert(salted).bytes);
  }

  static bool verificarSenha(String senha, String salt, String hash) {
    return hashSenha(senha, salt) == hash;
  }

  Future<void> criarUsuario(String email, String senhaHash, String salt) async {
    if (_isWeb) return;
    final db = await database;
    await db.insert(
      'usuarios',
      {
        'email': email,
        'senha_hash': senhaHash,
        'salt': salt,
        'criado_em': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> carregarUsuario(String email) async {
    if (_isWeb) return null;
    final db = await database;
    final rows = await db.query('usuarios',
        where: 'email = ?', whereArgs: [email]);
    return rows.isNotEmpty ? rows.first : null;
  }
}

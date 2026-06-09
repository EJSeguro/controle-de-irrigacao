import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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

class DatabaseService {
  static Database? _db;
  static List<Leitura>? _memoria;
  static List<ConsumoRecord>? _memConsumo;
  static Map<String, String>? _memConfig;

  bool get _isWeb => kIsWeb;

  Future<Database> get database async {
    if (_isWeb) throw UnsupportedError('sqflite não disponível na web');
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  List<Leitura> get _mem {
    _memoria ??= [];
    return _memoria!;
  }

  List<ConsumoRecord> get _memCons {
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
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE leituras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data TEXT NOT NULL,
            umidade INTEGER NOT NULL,
            status_solo TEXT NOT NULL,
            tipo TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE consumo (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data TEXT NOT NULL,
            litros REAL NOT NULL,
            tempo_segundos INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE config (
            chave TEXT PRIMARY KEY,
            valor TEXT NOT NULL
          )
        ''');
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
      },
    );
  }

  Future<void> salvarLeitura(Leitura leitura) async {
    if (_isWeb) {
      _mem.insert(0, leitura);
      return;
    }
    final db = await database;
    await db.insert('leituras', {
      'data': leitura.data.toIso8601String(),
      'umidade': leitura.umidade,
      'status_solo': leitura.statusSolo,
      'tipo': leitura.tipo,
    });
  }

  Future<List<Leitura>> carregarLeituras() async {
    if (_isWeb) return List.unmodifiable(_mem);
    final db = await database;
    final rows = await db.query('leituras', orderBy: 'data DESC');
    return rows.map((row) {
      return Leitura(
        data: DateTime.parse(row['data'] as String),
        umidade: row['umidade'] as int,
        statusSolo: row['status_solo'] as String,
        tipo: row['tipo'] as String,
      );
    }).toList();
  }

  Future<void> salvarConsumo(ConsumoRecord record) async {
    if (_isWeb) {
      _memCons.insert(0, record);
      return;
    }
    final db = await database;
    await db.insert('consumo', {
      'data': record.data.toIso8601String(),
      'litros': record.litros,
      'tempo_segundos': record.tempoSegundos,
    });
  }

  Future<List<ConsumoRecord>> carregarConsumos() async {
    if (_isWeb) return List.unmodifiable(_memCons);
    final db = await database;
    final rows = await db.query('consumo', orderBy: 'data DESC');
    return rows.map((row) {
      return ConsumoRecord(
        data: DateTime.parse(row['data'] as String),
        litros: row['litros'] as double,
        tempoSegundos: row['tempo_segundos'] as int,
      );
    }).toList();
  }

  Future<void> salvarConfig(String chave, String valor) async {
    if (_isWeb) {
      _memCfg[chave] = valor;
      return;
    }
    final db = await database;
    await db.insert(
      'config',
      {'chave': chave, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> carregarConfigs() async {
    if (_isWeb) return Map.from(_memCfg);
    final db = await database;
    final rows = await db.query('config');
    return {for (final r in rows) r['chave'] as String: r['valor'] as String};
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/leitura.dart';

class DatabaseService {
  static Database? _db;
  static List<Leitura>? _memoria;

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

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'irrigacao.db');
    return openDatabase(
      path,
      version: 1,
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

  Future<void> limparLeituras() async {
    if (_isWeb) {
      _memoria?.clear();
      return;
    }
    final db = await database;
    await db.delete('leituras');
  }
}

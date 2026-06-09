import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/leitura.dart';

class DatabaseService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
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
    final db = await database;
    await db.insert('leituras', {
      'data': leitura.data.toIso8601String(),
      'umidade': leitura.umidade,
      'status_solo': leitura.statusSolo,
      'tipo': leitura.tipo,
    });
  }

  Future<List<Leitura>> carregarLeituras() async {
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
    final db = await database;
    await db.delete('leituras');
  }
}

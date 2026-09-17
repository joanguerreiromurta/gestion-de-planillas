import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/cliente.dart';
import '../models/retiro.dart';

class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'retiros.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE retiros (
            id TEXT PRIMARY KEY,
            fecha TEXT NOT NULL,
            chofer TEXT NOT NULL,
            generador TEXT NOT NULL,
            direccion TEXT NOT NULL,
            litros REAL NOT NULL,
            importe REAL NOT NULL,
            sincronizado INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE clientes (
            nombre TEXT PRIMARY KEY,
            direccion TEXT NOT NULL,
            telefono TEXT
          )
        ''');
      },
    );
  }

  // ---------- Retiros ----------

  Future<void> insertRetiro(Retiro retiro) async {
    final db = await database;
    await db.insert(
      'retiros',
      retiro.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> marcarSincronizado(String id) async {
    final db = await database;
    await db.update(
      'retiros',
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Retiro>> retirosPendientes() async {
    final db = await database;
    final rows = await db.query(
      'retiros',
      where: 'sincronizado = 0',
      orderBy: 'fecha ASC',
    );
    return rows.map(Retiro.fromDbMap).toList();
  }

  Future<List<Retiro>> retirosDelDia(DateTime dia) async {
    final db = await database;
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fin = inicio.add(const Duration(days: 1));
    final rows = await db.query(
      'retiros',
      where: 'fecha >= ? AND fecha < ?',
      whereArgs: [inicio.toIso8601String(), fin.toIso8601String()],
      orderBy: 'fecha DESC',
    );
    return rows.map(Retiro.fromDbMap).toList();
  }

  // ---------- Clientes ----------

  Future<void> seedClientesSiVacio() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM clientes'),
    );
    if (count != null && count > 0) return;

    final raw = await rootBundle.loadString('assets/clientes_seed.json');
    final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
    final batch = db.batch();
    for (final item in data) {
      final cliente = Cliente.fromJson(item as Map<String, dynamic>);
      batch.insert(
        'clientes',
        cliente.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Cliente>> buscarClientes(String query) async {
    final db = await database;
    final rows = await db.query(
      'clientes',
      where: 'nombre LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'nombre ASC',
      limit: 20,
    );
    return rows.map(Cliente.fromDbMap).toList();
  }

  Future<List<Cliente>> todosLosClientes() async {
    final db = await database;
    final rows = await db.query('clientes', orderBy: 'nombre ASC');
    return rows.map(Cliente.fromDbMap).toList();
  }
}

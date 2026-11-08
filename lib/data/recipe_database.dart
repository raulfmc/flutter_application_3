import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.ingredients,
    required this.preparation,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String category;
  final String ingredients;
  final String preparation;
  final bool isFavorite;

  String get emoji => switch (category) {
    'Doces' => '🍰',
    'Bebidas' => '🥤',
    _ => '🍲',
  };

  factory Recipe.fromMap(Map<String, Object?> map) {
    return Recipe(
      id: map['id']! as String,
      name: map['name']! as String,
      category: _normalizeCategory(map['category']! as String),
      ingredients: _readRecipeText(map['ingredients']! as String),
      preparation: _readRecipeText(map['steps']! as String),
      isFavorite: map['is_favorite'] != null,
    );
  }
}

String _normalizeCategory(String category) {
  return switch (category) {
    'Doces' || 'Sobremesa' => 'Doces',
    'Bebidas' => 'Bebidas',
    _ => 'Salgados',
  };
}

String _readRecipeText(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) return decoded.join('\n');
  } on FormatException {
    return value;
  }
  return value;
}

class LocalUser {
  const LocalUser({required this.id, required this.name});

  final int id;
  final String name;
}

class RecipeDatabase {
  RecipeDatabase({Database? database}) : _providedDatabase = database;

  static const _databaseName = 'meu_livro_de_receitas.db';
  static const _passwordIterations = 120000;
  static final _passwordAlgorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _passwordIterations,
    bits: 256,
  );
  static final instance = RecipeDatabase();

  final Database? _providedDatabase;
  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;
    if (_providedDatabase != null) {
      _database = _providedDatabase;
      await _createTables(_database!);
    } else {
      final path = p.join(await getDatabasesPath(), _databaseName);
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) async {
          await _createTables(db);
        },
      );
    }

    await _removeStarterRecipes(_database!);
  }

  Future<Database> get _db async {
    await initialize();
    return _database!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        minutes INTEGER NOT NULL,
        emoji TEXT NOT NULL,
        description TEXT NOT NULL,
        ingredients TEXT NOT NULL,
        steps TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        user_id INTEGER NOT NULL,
        recipe_id TEXT NOT NULL,
        PRIMARY KEY (user_id, recipe_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _removeStarterRecipes(Database db) async {
    await db.transaction((transaction) async {
      for (final id in _starterRecipeIds) {
        await transaction.delete(
          'favorites',
          where: 'recipe_id = ?',
          whereArgs: [id],
        );
        await transaction.delete('recipes', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<LocalUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await _db;
    final normalizedEmail = email.trim().toLowerCase();
    final existing = await db.query(
      'users',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw const AccountAlreadyExistsException();
    }

    final salt = List<int>.generate(
      16,
      (_) => SecureRandom.defaultRandom.nextInt(256),
    );
    final hash = await _passwordHash(password, salt);
    final userId = await db.insert('users', {
      'name': name.trim(),
      'email': normalizedEmail,
      'password_salt': _toHex(salt),
      'password_hash': _toHex(hash),
    });
    final user = LocalUser(id: userId, name: name.trim());
    await _saveSession(userId);
    return user;
  }

  Future<LocalUser?> login({
    required String email,
    required String password,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final salt = _fromHex(row['password_salt']! as String);
    final expectedHash = _fromHex(row['password_hash']! as String);
    final actualHash = await _passwordHash(password, salt);
    if (!_constantTimeEquals(actualHash, expectedHash)) return null;

    final user = LocalUser(id: row['id']! as int, name: row['name']! as String);
    await _saveSession(user.id);
    return user;
  }

  Future<LocalUser?> savedSession() async {
    final db = await _db;
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['active_user_id'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final userId = int.tryParse(rows.first['value']! as String);
    if (userId == null) return null;
    final users = await db.query(
      'users',
      columns: ['id', 'name'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (users.isEmpty) return null;
    return LocalUser(
      id: users.first['id']! as int,
      name: users.first['name']! as String,
    );
  }

  Future<void> logout() async {
    final db = await _db;
    await db.delete(
      'settings',
      where: 'key = ?',
      whereArgs: ['active_user_id'],
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<List<Recipe>> recipesFor(int userId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT recipes.*, favorites.user_id AS is_favorite
      FROM recipes
      LEFT JOIN favorites
        ON favorites.recipe_id = recipes.id AND favorites.user_id = ?
      ORDER BY recipes.name COLLATE NOCASE
      ''',
      [userId],
    );
    return rows.map(Recipe.fromMap).toList();
  }

  Future<String> addRecipe({
    required String name,
    required String category,
    required String ingredients,
    required String preparation,
  }) async {
    final db = await _db;
    final id = 'recipe-${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('recipes', {
      'id': id,
      'name': name.trim(),
      'category': _normalizeCategory(category),
      'minutes': 0,
      'emoji': _emojiFor(category),
      'description': '',
      'ingredients': ingredients.trim(),
      'steps': preparation.trim(),
    });
    return id;
  }

  Future<void> updateRecipe({
    required String id,
    required String name,
    required String category,
    required String ingredients,
    required String preparation,
  }) async {
    final db = await _db;
    final updated = await db.update(
      'recipes',
      {
        'name': name.trim(),
        'category': _normalizeCategory(category),
        'minutes': 0,
        'emoji': _emojiFor(category),
        'description': '',
        'ingredients': ingredients.trim(),
        'steps': preparation.trim(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      throw const RecipeNotFoundException();
    }
  }

  String _emojiFor(String category) {
    return switch (_normalizeCategory(category)) {
      'Doces' => '🍰',
      'Bebidas' => '🥤',
      _ => '🍲',
    };
  }

  Future<void> deleteRecipe(String id) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.delete(
        'favorites',
        where: 'recipe_id = ?',
        whereArgs: [id],
      );
      final deleted = await transaction.delete(
        'recipes',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (deleted == 0) {
        throw const RecipeNotFoundException();
      }
    });
  }

  Future<void> setFavorite({
    required int userId,
    required String recipeId,
    required bool isFavorite,
  }) async {
    final db = await _db;
    if (isFavorite) {
      await db.insert('favorites', {
        'user_id': userId,
        'recipe_id': recipeId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete(
        'favorites',
        where: 'user_id = ? AND recipe_id = ?',
        whereArgs: [userId, recipeId],
      );
    }
  }

  Future<void> _saveSession(int userId) async {
    final db = await _db;
    await db.insert('settings', {
      'key': 'active_user_id',
      'value': '$userId',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<int>> _passwordHash(String password, List<int> salt) async {
    final key = await _passwordAlgorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  String _toHex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  List<int> _fromHex(String value) {
    return List<int>.generate(
      value.length ~/ 2,
      (index) =>
          int.parse(value.substring(index * 2, index * 2 + 2), radix: 16),
    );
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}

class AccountAlreadyExistsException implements Exception {
  const AccountAlreadyExistsException();
}

class RecipeNotFoundException implements Exception {
  const RecipeNotFoundException();
}

const _starterRecipeIds = [
  'panqueca-banana',
  'macarrao-cremoso',
  'bolo-chocolate',
  'sopa-abobora',
];

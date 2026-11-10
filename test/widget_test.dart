import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_3/banco_de_dados.dart';
import 'package:flutter_application_3/main.dart';

void main() {
  late RecipeDatabase database;
  late Database sqliteDatabase;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    sqliteDatabase = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    database = RecipeDatabase(database: sqliteDatabase);
    await database.initialize();
  });

  tearDown(() async {
    await database.close();
  });

  test('stores accounts, favorites, and the local session in SQLite', () async {
    final user = await database.register(
      name: 'Ana',
      email: 'ana@example.com',
      password: 'minhasenha',
    );

    expect(
      await database.login(email: 'ana@example.com', password: 'errada'),
      isNull,
    );
    expect(
      (await database.login(
        email: 'ANA@example.com',
        password: 'minhasenha',
      ))?.id,
      user.id,
    );
    expect((await database.savedSession())?.name, 'Ana');

    final recipeId = await database.addRecipe(
      userId: user.id,
      name: 'Receita favorita',
      category: 'Salgados',
      ingredients: 'Ingredientes',
      preparation: 'Preparo',
    );
    await database.setFavorite(
      userId: user.id,
      recipeId: recipeId,
      isFavorite: true,
    );
    expect(
      (await database.recipesFor(user.id))
          .singleWhere((item) => item.id == recipeId)
          .isFavorite,
      isTrue,
    );
  });

  test('administrator can list and block or unblock accounts', () async {
    final admin = await database.login(
      email: 'raulferreira091@gmail.com.br',
      password: 'adimin_raul_2006',
    );
    expect(admin?.isAdmin, isTrue);
    expect(
      await database.login(
        email: 'raulferreira091@gmail.com.br',
        password: 'senha-incorreta',
      ),
      isNull,
    );

    final user = await database.register(
      name: 'Ana',
      email: 'ana@example.com',
      password: 'minhasenha',
    );

    await expectLater(
      database.accountsForAdmin(user.id),
      throwsA(isA<AdminAuthorizationException>()),
    );
    await expectLater(
      database.setAccountBlocked(
        adminUserId: user.id,
        accountId: user.id,
        isBlocked: true,
      ),
      throwsA(isA<AdminAuthorizationException>()),
    );

    final accounts = await database.accountsForAdmin(admin!.id);
    expect(accounts.map((account) => account.email), contains(user.email));
    await expectLater(
      database.recipesFor(admin.id),
      throwsA(isA<AdminAuthorizationException>()),
    );
    await expectLater(
      database.addRecipe(
        userId: admin.id,
        name: 'Receita não permitida',
        category: 'Doces',
        ingredients: 'Ingredientes',
        preparation: 'Preparo',
      ),
      throwsA(isA<AdminAuthorizationException>()),
    );
    await database.setAccountBlocked(
      adminUserId: admin.id,
      accountId: user.id,
      isBlocked: true,
    );
    expect(
      await database.login(email: user.email, password: 'minhasenha'),
      isNull,
    );

    await database.setAccountBlocked(
      adminUserId: admin.id,
      accountId: user.id,
      isBlocked: false,
    );
    expect(
      (await database.login(email: user.email, password: 'minhasenha'))?.id,
      user.id,
    );
  });

  test('administrator account cannot be blocked', () async {
    final admin = await database.login(
      email: 'raulferreira091@gmail.com.br',
      password: 'adimin_raul_2006',
    );
    expect(admin, isNotNull);

    await expectLater(
      database.setAccountBlocked(
        adminUserId: admin!.id,
        accountId: admin.id,
        isBlocked: true,
      ),
      throwsA(isA<CannotManageAdministratorException>()),
    );
  });

  test('adds access-control columns to an existing users table', () async {
    await sqliteDatabase.execute('DROP TABLE users');
    await sqliteDatabase.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL
      )
    ''');
    final migratedDatabase = RecipeDatabase(database: sqliteDatabase);
    await migratedDatabase.initialize();

    final columns = await sqliteDatabase.rawQuery('PRAGMA table_info(users)');
    expect(
      columns.map((column) => column['name']),
      containsAll(['role', 'is_blocked']),
    );
    expect(
      (await migratedDatabase.login(
        email: 'raulferreira091@gmail.com.br',
        password: 'adimin_raul_2006',
      ))?.isAdmin,
      isTrue,
    );
  });

  test('starts without predefined recipes', () async {
    final user = await database.register(
      name: 'Ana',
      email: 'ana@example.com',
      password: 'minhasenha',
    );
    expect(await database.recipesFor(user.id), isEmpty);
  });

  test('detects accounts that are not registered on this device', () async {
    expect(await database.accountExists('outro-aparelho@example.com'), isFalse);
    expect(
      await database.login(
        email: 'outro-aparelho@example.com',
        password: 'minhasenha',
      ),
      isNull,
    );

    await database.register(
      name: 'Ana',
      email: 'ana@example.com',
      password: 'minhasenha',
    );
    expect(await database.accountExists('ANA@example.com'), isTrue);
  });

  test('keeps recipes private between accounts on the same device', () async {
    final firstUser = await database.register(
      name: 'Ana',
      email: 'ana@example.com',
      password: 'minhasenha',
    );
    final firstRecipeId = await database.addRecipe(
      userId: firstUser.id,
      name: 'Receita da Ana',
      category: 'Doces',
      ingredients: 'Farinha',
      preparation: 'Misture.',
    );

    final secondUser = await database.register(
      name: 'Bia',
      email: 'bia@example.com',
      password: 'minhasenha',
    );
    final secondRecipeId = await database.addRecipe(
      userId: secondUser.id,
      name: 'Receita da Bia',
      category: 'Bebidas',
      ingredients: 'Fruta',
      preparation: 'Bata.',
    );

    expect(
      (await database.recipesFor(firstUser.id)).map((recipe) => recipe.id),
      [firstRecipeId],
    );
    expect(
      (await database.recipesFor(secondUser.id)).map((recipe) => recipe.id),
      [secondRecipeId],
    );
    await expectLater(
      database.updateRecipe(
        userId: secondUser.id,
        id: firstRecipeId,
        name: 'Receita alterada',
        category: 'Doces',
        ingredients: 'Farinha',
        preparation: 'Misture.',
      ),
      throwsA(isA<RecipeNotFoundException>()),
    );
    await expectLater(
      database.deleteRecipe(userId: secondUser.id, id: firstRecipeId),
      throwsA(isA<RecipeNotFoundException>()),
    );
    await expectLater(
      database.setFavorite(
        userId: secondUser.id,
        recipeId: firstRecipeId,
        isFavorite: true,
      ),
      throwsA(isA<RecipeNotFoundException>()),
    );

  });

  test(
    'removes predefined recipes while preserving personal recipes',
    () async {
      final user = await database.register(
        name: 'Ana',
        email: 'ana@example.com',
        password: 'minhasenha',
      );
      await sqliteDatabase.insert('recipes', {
        'id': 'panqueca-banana',
        'name': 'Panqueca de banana',
        'category': 'Salgados',
        'minutes': 0,
        'emoji': '',
        'description': '',
        'ingredients': '',
        'steps': '',
      });
      await sqliteDatabase.insert('recipes', {
        'id': 'receita-pessoal',
        'name': 'Minha receita',
        'category': 'Doces',
        'minutes': 0,
        'emoji': '',
        'description': '',
        'ingredients': '',
        'steps': '',
      });

      final reopenedDatabase = RecipeDatabase(database: sqliteDatabase);
      await reopenedDatabase.initialize();

      final recipes = await reopenedDatabase.recipesFor(user.id);
      expect(recipes.map((recipe) => recipe.id), ['receita-pessoal']);
    },
  );

  test('adds, edits, and deletes recipes in SQLite', () async {
    final user = await database.register(
      name: 'Ana',
      email: 'ana@example.com',
      password: 'minhasenha',
    );
    final id = await database.addRecipe(
      userId: user.id,
      name: 'Sopa de teste',
      category: 'Salgados',
      ingredients: '1 abóbora\nSal',
      preparation: 'Corte a abóbora e cozinhe até ficar macia.',
    );

    var recipe = (await database.recipesFor(user.id))
        .singleWhere((item) => item.id == id);
    expect(recipe.name, 'Sopa de teste');
    expect(recipe.ingredients, '1 abóbora\nSal');
    expect(recipe.preparation, 'Corte a abóbora e cozinhe até ficar macia.');

    await database.updateRecipe(
      userId: user.id,
      id: id,
      name: 'Sopa editada',
      category: 'Doces',
      ingredients: '2 abóboras',
      preparation: 'Cozinhe por mais tempo e sirva.',
    );
    recipe = (await database.recipesFor(user.id))
        .singleWhere((item) => item.id == id);
    expect(recipe.name, 'Sopa editada');
    expect(recipe.category, 'Doces');
    expect(recipe.ingredients, '2 abóboras');
    expect(recipe.preparation, 'Cozinhe por mais tempo e sirva.');

    await database.deleteRecipe(userId: user.id, id: id);
    expect(
      (await database.recipesFor(user.id)).any((item) => item.id == id),
      isFalse,
    );
  });

  test('reads recipes saved by the previous format', () {
    final recipe = Recipe.fromMap({
      'id': 'old-bolo',
      'name': 'Bolo antigo',
      'category': 'Sobremesa',
      'minutes': 50,
      'emoji': '🍰',
      'description': 'Comentário antigo',
      'ingredients': '["Farinha","Açúcar"]',
      'steps': '["Misture tudo.","Asse até dourar."]',
      'is_favorite': null,
    });

    expect(recipe.category, 'Doces');
    expect(recipe.ingredients, 'Farinha\nAçúcar');
    expect(recipe.preparation, 'Misture tudo.\nAsse até dourar.');
  });

  testWidgets('opens login first and allows switching to account creation', (
    tester,
  ) async {
    await tester.pumpWidget(RecipeBookApp(database: database));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('email-field')), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    await tester.tap(find.text('Criar uma conta'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('name-field')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Criar conta'), findsOneWidget);
  });
}

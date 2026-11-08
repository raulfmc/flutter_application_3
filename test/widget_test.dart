import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_3/data/recipe_database.dart';
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

  test('starts without predefined recipes', () async {
    expect(await database.recipesFor(1), isEmpty);
  });

  test(
    'removes predefined recipes while preserving personal recipes',
    () async {
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

      final recipes = await reopenedDatabase.recipesFor(1);
      expect(recipes.map((recipe) => recipe.id), ['receita-pessoal']);
    },
  );

  test('adds, edits, and deletes recipes in SQLite', () async {
    final id = await database.addRecipe(
      name: 'Sopa de teste',
      category: 'Salgados',
      ingredients: '1 abóbora\nSal',
      preparation: 'Corte a abóbora e cozinhe até ficar macia.',
    );

    var recipe = (await database.recipesFor(1))
        .singleWhere((item) => item.id == id);
    expect(recipe.name, 'Sopa de teste');
    expect(recipe.ingredients, '1 abóbora\nSal');
    expect(recipe.preparation, 'Corte a abóbora e cozinhe até ficar macia.');

    await database.updateRecipe(
      id: id,
      name: 'Sopa editada',
      category: 'Doces',
      ingredients: '2 abóboras',
      preparation: 'Cozinhe por mais tempo e sirva.',
    );
    recipe = (await database.recipesFor(1))
        .singleWhere((item) => item.id == id);
    expect(recipe.name, 'Sopa editada');
    expect(recipe.category, 'Doces');
    expect(recipe.ingredients, '2 abóboras');
    expect(recipe.preparation, 'Cozinhe por mais tempo e sirva.');

    await database.deleteRecipe(id);
    expect(
      (await database.recipesFor(1)).any((item) => item.id == id),
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

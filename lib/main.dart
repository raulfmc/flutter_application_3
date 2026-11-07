import 'package:flutter/material.dart';

import 'database_factory_setup.dart';
import 'data/recipe_database.dart';

const Color _brown = Color(0xFF8A4528);
const Color _orange = Color(0xFFB9683E);
const Color _paper = Color(0xFFFFFBF8);
const Color _text = Color(0xFF392D27);
const Color _subtle = Color(0xFF82766F);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDatabaseFactory();
  runApp(const RecipeBookApp());
}

class RecipeBookApp extends StatefulWidget {
  const RecipeBookApp({super.key, this.database});

  final RecipeDatabase? database;

  @override
  State<RecipeBookApp> createState() => _RecipeBookAppState();
}

class _RecipeBookAppState extends State<RecipeBookApp> {
  late final RecipeDatabase _database =
      widget.database ?? RecipeDatabase.instance;
  LocalUser? _user;
  Object? _startupError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _openLogin();
  }

  Future<void> _openLogin() async {
    setState(() {
      _loading = true;
      _startupError = null;
    });
    try {
      await _database.initialize();
      if (!mounted) return;
      setState(() {
        _user = null;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _startupError = error;
        _loading = false;
      });
    }
  }

  void _onAuthenticated(LocalUser user) {
    setState(() => _user = user);
  }

  Future<void> _logout() async {
    try {
      await _database.logout();
      if (mounted) setState(() => _user = null);
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível sair: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meu Livro de Receitas',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(seedColor: _orange, surface: _paper),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _text,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFE7D8CF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFE7D8CF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _orange, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _brown,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ),
      home: _loading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator(color: _brown)),
            )
          : _startupError != null
          ? _StartupErrorPage(error: _startupError!, onRetry: _openLogin)
          : _user == null
          ? _LoginPage(database: _database, onAuthenticated: _onAuthenticated)
          : _RecipeHomePage(
              database: _database,
              user: _user!,
              onLogout: _logout,
            ),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage_outlined, size: 44, color: _brown),
              const SizedBox(height: 12),
              const Text(
                'Não consegui abrir o banco de receitas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage({required this.database, required this.onAuthenticated});

  final RecipeDatabase database;
  final ValueChanged<LocalUser> onAuthenticated;

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _creatingAccount = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final LocalUser user;
      if (_creatingAccount) {
        user = await widget.database.register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        final signedIn = await widget.database.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (signedIn == null) {
          setState(() => _message = 'E-mail ou senha incorretos.');
          return;
        }
        user = signedIn;
      }
      widget.onAuthenticated(user);
    } on AccountAlreadyExistsException {
      setState(() => _message = 'Já existe uma conta com esse e-mail.');
    } on Exception catch (error) {
      setState(() => _message = 'Não foi possível salvar seus dados: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _creatingAccount ? 'Criar conta' : 'Entrar';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 48,
                      color: _brown,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Meu Livro de Receitas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _text,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _creatingAccount
                          ? 'Crie uma conta para guardar suas receitas.'
                          : 'Entre para acessar suas receitas.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _subtle, fontSize: 14),
                    ),
                    const SizedBox(height: 27),
                    if (_creatingAccount) ...[
                      const Text('Seu nome'),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const ValueKey('name-field'),
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(hintText: 'Nome'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Digite seu nome.'
                            : null,
                      ),
                      const SizedBox(height: 15),
                    ],
                    const Text('E-mail'),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const ValueKey('email-field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'voce@email.com',
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return email.contains('@') && email.contains('.')
                            ? null
                            : 'Digite um e-mail válido.';
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text('Senha'),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const ValueKey('password-field'),
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        hintText: 'Pelo menos 6 caracteres',
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Mostrar senha'
                              : 'Esconder senha',
                          onPressed: () => setState(() {
                            _hidePassword = !_hidePassword;
                          }),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 6)
                          ? 'A senha precisa ter pelo menos 6 caracteres.'
                          : null,
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 13),
                      Text(
                        _message!,
                        style: const TextStyle(color: Color(0xFF9A3829)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(title),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _creatingAccount = !_creatingAccount;
                              _message = null;
                            }),
                      child: Text(
                        _creatingAccount
                            ? 'Já tenho uma conta'
                            : 'Criar uma conta',
                        style: const TextStyle(color: _brown),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Seus dados ficam salvos somente neste aparelho.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _subtle, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeHomePage extends StatefulWidget {
  const _RecipeHomePage({
    required this.database,
    required this.user,
    required this.onLogout,
  });

  final RecipeDatabase database;
  final LocalUser user;
  final Future<void> Function() onLogout;

  @override
  State<_RecipeHomePage> createState() => _RecipeHomePageState();
}

class _RecipeHomePageState extends State<_RecipeHomePage> {
  static const _categories = [
    'Todas',
    'Salgados',
    'Doces',
    'Bebidas',
  ];

  List<Recipe> _recipes = [];
  String _category = 'Todas';
  String _search = '';
  String? _loadError;
  bool _loading = true;
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final recipes = await widget.database.recipesFor(widget.user.id);
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Não foi possível carregar as receitas: $error';
        _loading = false;
      });
    }
  }

  List<Recipe> get _visibleRecipes {
    Iterable<Recipe> recipes = _recipes;
    if (_showFavorites) recipes = recipes.where((recipe) => recipe.isFavorite);
    if (!_showFavorites && _category != 'Todas') {
      recipes = recipes.where((recipe) => recipe.category == _category);
    }
    final query = _search.trim().toLowerCase();
    if (query.isNotEmpty) {
      recipes = recipes.where(
        (recipe) => recipe.name.toLowerCase().contains(query),
      );
    }
    return recipes.toList();
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    await _setFavorite(recipe, !recipe.isFavorite);
  }

  Future<bool> _setFavorite(Recipe recipe, bool isFavorite) async {
    try {
      await widget.database.setFavorite(
        userId: widget.user.id,
        recipeId: recipe.id,
        isFavorite: isFavorite,
      );
      await _loadRecipes();
      return true;
    } on Exception catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar a receita: $error')),
      );
      return false;
    }
  }

  void _openRecipe(Recipe recipe) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => _RecipeDetailPage(
              recipe: recipe,
              onFavoriteTap: (isFavorite) => _setFavorite(recipe, isFavorite),
              onEdit: (updatedRecipe) => _editRecipe(updatedRecipe),
              onDelete: () => _deleteRecipe(recipe),
            ),
          ),
        )
        .then((_) => _loadRecipes());
  }

  Future<Recipe?> _editRecipe(Recipe recipe) {
    return Navigator.of(context).push<Recipe>(
      MaterialPageRoute<Recipe>(
        builder: (_) =>
            _RecipeFormPage(database: widget.database, recipe: recipe),
      ),
    );
  }

  Future<void> _addRecipe() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _RecipeFormPage(database: widget.database),
      ),
    );
    if (saved == true) await _loadRecipes();
  }

  Future<bool> _deleteRecipe(Recipe recipe) async {
    try {
      await widget.database.deleteRecipe(recipe.id);
      return true;
    } on Exception catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir a receita: $error')),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _visibleRecipes;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meu Livro de Receitas',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, ${widget.user.name}!',
                  style: const TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: const InputDecoration(
                    hintText: 'Buscar receita pelo nome',
                    prefixIcon: Icon(Icons.search_rounded, color: _brown),
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    _FilterButton(
                      label: 'Todas',
                      selected: !_showFavorites,
                      onTap: () => setState(() {
                        _showFavorites = false;
                        _category = 'Todas';
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterButton(
                      label: 'Favoritas',
                      selected: _showFavorites,
                      onTap: () => setState(() => _showFavorites = true),
                    ),
                  ],
                ),
                if (!_showFavorites) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return _FilterButton(
                          label: category,
                          selected: _category == category,
                          onTap: () => setState(() => _category = category),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _brown))
                : _loadError != null
                ? _ErrorMessage(message: _loadError!, onRetry: _loadRecipes)
                : recipes.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma receita por aqui.',
                        style: TextStyle(color: _subtle),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: _brown,
                    onRefresh: _loadRecipes,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: recipes.length,
                      itemBuilder: (context, index) {
                        final recipe = recipes[index];
                        return _RecipeTile(
                          recipe: recipe,
                          onTap: () => _openRecipe(recipe),
                          onFavoriteTap: () => _toggleFavorite(recipe),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecipe,
        backgroundColor: _brown,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar receita'),
      ),
    );
  }
}

class _RecipeFormPage extends StatefulWidget {
  const _RecipeFormPage({required this.database, this.recipe});

  final RecipeDatabase database;
  final Recipe? recipe;

  @override
  State<_RecipeFormPage> createState() => _RecipeFormPageState();
}

class _RecipeFormPageState extends State<_RecipeFormPage> {
  static const _categories = ['Salgados', 'Doces', 'Bebidas'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ingredientsController;
  late final TextEditingController _preparationController;
  late String _category;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.recipe != null;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _nameController = TextEditingController(text: recipe?.name ?? '');
    _ingredientsController = TextEditingController(
      text: recipe?.ingredients ?? '',
    );
    _preparationController = TextEditingController(
      text: recipe?.preparation ?? '',
    );
    _category = recipe?.category ?? 'Salgados';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ingredientsController.dispose();
    _preparationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    final ingredients = _ingredientsController.text.trim();
    final preparation = _preparationController.text.trim();

    try {
      if (_isEditing) {
        final recipe = widget.recipe!;
        await widget.database.updateRecipe(
          id: recipe.id,
          name: name,
          category: _category,
          ingredients: ingredients,
          preparation: preparation,
        );
        if (!mounted) return;
        Navigator.of(context).pop(
          Recipe(
            id: recipe.id,
            name: name,
            category: _category,
            ingredients: ingredients,
            preparation: preparation,
            isFavorite: recipe.isFavorite,
          ),
        );
      } else {
        await widget.database.addRecipe(
          name: name,
          category: _category,
          ingredients: ingredients,
          preparation: preparation,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível salvar a receita: $error';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar receita' : 'Nova receita'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(
              'Salvar',
              style: TextStyle(color: _brown, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            const Text('Nome do prato'),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('recipe-name-field'),
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Ex.: Sopa da vovó'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Digite o nome da receita.'
                  : null,
            ),
            const SizedBox(height: 14),
            const Text('Categoria'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _categories.contains(_category)
                  ? _category
                  : 'Salgados',
              decoration: const InputDecoration(),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _category = value);
                    },
            ),
            const SizedBox(height: 16),
            const Text('Ingredientes'),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('recipe-ingredients-field'),
              controller: _ingredientsController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Escreva os ingredientes como preferir',
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Digite os ingredientes.'
                  : null,
            ),
            const SizedBox(height: 16),
            const Text('Modo de preparo'),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('recipe-preparation-field'),
              controller: _preparationController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText: 'Escreva o preparo completo do seu jeito',
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escreva o modo de preparo.'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFF9A3829))),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEditing ? 'Salvar alterações' : 'Salvar receita'),
            ),
          ],
        ),
      ),
    );
  }

}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : _brown,
        fontSize: 12,
      ),
      selectedColor: _brown,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE7D8CF)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({
    required this.recipe,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFECE2DC)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0E6),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(recipe.emoji, style: const TextStyle(fontSize: 26)),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(
            color: _text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            recipe.category,
            style: const TextStyle(color: _subtle, fontSize: 12),
          ),
        ),
        trailing: IconButton(
          tooltip: recipe.isFavorite
              ? 'Remover dos favoritos'
              : 'Salvar nos favoritos',
          onPressed: onFavoriteTap,
          icon: Icon(
            recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: recipe.isFavorite ? _orange : _subtle,
          ),
        ),
      ),
    );
  }
}

class _RecipeDetailPage extends StatefulWidget {
  const _RecipeDetailPage({
    required this.recipe,
    required this.onFavoriteTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Recipe recipe;
  final Future<bool> Function(bool isFavorite) onFavoriteTap;
  final Future<Recipe?> Function(Recipe recipe) onEdit;
  final Future<bool> Function() onDelete;

  @override
  State<_RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<_RecipeDetailPage> {
  late Recipe _recipe = widget.recipe;

  Future<void> _editRecipe() async {
    final updatedRecipe = await widget.onEdit(_recipe);
    if (updatedRecipe != null && mounted) {
      setState(() => _recipe = updatedRecipe);
    }
  }

  Future<void> _deleteRecipe() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir receita?'),
        content: Text('A receita "${_recipe.name}" será apagada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9A3829),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    final deleted = await widget.onDelete();
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.name),
        actions: [
          IconButton(
            tooltip: recipe.isFavorite
                ? 'Remover dos favoritos'
                : 'Salvar nos favoritos',
            onPressed: () async {
              final saved = await widget.onFavoriteTap(!recipe.isFavorite);
              if (saved && mounted) {
                setState(
                  () => _recipe = Recipe(
                    id: recipe.id,
                    name: recipe.name,
                    category: recipe.category,
                    ingredients: recipe.ingredients,
                    preparation: recipe.preparation,
                    isFavorite: !recipe.isFavorite,
                  ),
                );
              }
            },
            icon: Icon(
              recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _orange,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E6),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(recipe.emoji, style: const TextStyle(fontSize: 68)),
          ),
            const SizedBox(height: 12),
            Text(
              recipe.category,
              style: const TextStyle(color: _subtle, fontSize: 13),
            ),
            const SizedBox(height: 20),
          const Text(
            'Ingredientes',
            style: TextStyle(
              color: _brown,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recipe.ingredients,
            style: const TextStyle(color: _text, height: 1.5),
          ),
          const SizedBox(height: 17),
          const Text(
            'Modo de preparo',
            style: TextStyle(
              color: _brown,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recipe.preparation,
            style: const TextStyle(color: _text, height: 1.5),
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFFE7D8CF)),
          const SizedBox(height: 10),
          const Text(
            'Quer mudar alguma coisa?',
            style: TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _editRecipe,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar receita'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brown,
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: _brown),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          const SizedBox(height: 9),
          TextButton.icon(
            onPressed: _deleteRecipe,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir receita'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9A3829),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}

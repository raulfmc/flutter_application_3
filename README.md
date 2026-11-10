# Meu Livro de Receitas

Um app pessoal e simples para consultar receitas, filtrar por categoria,
marcar favoritas e cadastrar suas receitas com nome, categoria, ingredientes
em texto e modo de preparo em texto. As receitas podem ser editadas ou
excluídas pela tela de detalhes. As categorias são Salgados, Doces e Bebidas.

## Dados

O SQLite guarda contas, receitas e favoritas localmente em cada aparelho; o app
não adiciona receitas demonstrativas ao iniciar. Cada conta tem suas próprias
receitas naquele aparelho. Sem servidor ou sincronização, uma conta e suas
receitas não podem ser acessadas em outro aparelho; o app avisa quando o e-mail
não está cadastrado localmente. As senhas das contas comuns são armazenadas como
hashes com salt. A senha administrativa é uma comparação simples definida em
texto no código; qualquer pessoa com acesso ao código pode vê-la.

## Administração de acessos

Há uma conta administradora preconfigurada que pode abrir **Gerenciar acessos**
para listar e bloquear ou desbloquear contas locais. O administrador não acessa
receitas, e contas não podem ser excluídas pelo app. O controle é local e não
substitui autorização no servidor: alguém que possa modificar o app ou o banco
do aparelho pode contorná-lo. A lógica do banco está reunida em
[`lib/banco_de_dados.dart`](lib/banco_de_dados.dart).

## Executar

Com o Flutter instalado:

```bash
flutter pub get
flutter devices
flutter run
```

`flutter devices` mostra os dispositivos que estão conectados e prontos para
executar. Para abrir no Chrome, use:

```bash
flutter run -d chrome --web-port=7357
```

O SQLite no Chrome fica no armazenamento IndexedDB do navegador e é separado
por endereço e porta; mantenha `--web-port=7357` para continuar usando o mesmo
banco durante o desenvolvimento. Os dados do navegador não são compartilhados
com Android ou Windows.

Para iniciar em outros destinos já configurados, use, por exemplo:

```bash
flutter run -d windows
flutter run -d <id-do-emulador-ou-celular>
```

O projeto tem suporte configurado para Chrome, Android, iOS e Windows. Android
precisa de um emulador aberto ou celular conectado; iOS só pode ser compilado
em um Mac. Linux e macOS desktop ainda não foram configurados.

Se `flutter devices` não listar opções, verifique a instalação com
`flutter doctor -v` e abra ou conecte o dispositivo que quer usar.

## Testes

```bash
flutter test
```

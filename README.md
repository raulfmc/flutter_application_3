# Meu Livro de Receitas

Um app pessoal e simples para consultar receitas, filtrar por categoria,
marcar favoritas e cadastrar suas receitas com nome, categoria, ingredientes
em texto e modo de preparo em texto. As receitas podem ser editadas ou
excluídas pela tela de detalhes. As categorias são Salgados, Doces e Bebidas.

## Dados

O SQLite guarda as contas, as receitas e as favoritas localmente. As senhas são
armazenadas como hashes com salt; elas não são gravadas em texto puro. Não há
servidor, sincronização entre aparelhos ou recuperação de senha.

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

# Relatório do projeto — Meu Livro de Receitas

## 1. Objetivo

O projeto foi desenvolvido como um aplicativo pessoal para guardar e consultar
receitas. A prioridade foi manter o uso simples, com cadastro local, poucos
campos e uma interface em tons claros com marrom e laranja. O aplicativo foi
preparado para funcionar em celular Android, Windows e navegador; outros
destinos dependem de configuração própria da plataforma.

## 2. Planejamento e evolução

O escopo foi definido e simplificado em etapas, de acordo com o uso pretendido:

1. Transformar o projeto Flutter inicial em um livro digital de receitas.
2. Direcionar o visual para uma paleta branca e marrom-alaranjada e manter o
   aplicativo voltado ao uso pessoal.
3. Incluir criação de conta e login, com persistência local em SQLite em vez de
   depender de um serviço externo.
4. Implementar cadastro, visualização, edição e exclusão de receitas.
5. Reduzir o formulário ao essencial: nome, categoria, ingredientes e modo de
   preparo. As categorias finais são **Salgados**, **Doces** e **Bebidas**.
6. Fazer o aplicativo iniciar sempre na tela de login e permitir execução em
   plataformas diferentes.
7. Remover as receitas pré-cadastradas e os textos de exemplo dos campos,
   mantendo apenas conteúdo inserido pelo usuário.

## 3. Funcionalidades entregues

- Criar uma conta local e entrar com e-mail e senha.
- Abrir no login ao iniciar o aplicativo, sem entrar automaticamente em uma
  sessão anterior.
- Cadastrar receitas com nome, categoria, ingredientes em texto e modo de
  preparo em texto.
- Consultar, pesquisar e filtrar receitas por categoria.
- Marcar e consultar receitas favoritas.
- Editar ou excluir uma receita pela tela de detalhes, com confirmação antes da
  exclusão.
- Armazenar informações localmente no dispositivo ou no navegador.
- Começar sem receitas de demonstração. Na inicialização, identificadores das
  receitas de exemplo de versões anteriores são removidos sem apagar receitas
  pessoais.

## 4. Tecnologias e organização

- **Flutter e Dart:** interface e lógica do aplicativo.
- **SQLite:** armazenamento local de contas, receitas e favoritos.
- **PBKDF2 com HMAC-SHA-256 e salt:** derivação do hash da senha antes de
  armazená-la; a senha não é gravada em texto puro.
- **sqflite_common_ffi:** acesso ao SQLite em sistemas desktop.
- **sqflite_common_ffi_web:** armazenamento SQLite no navegador, apoiado pelo
  armazenamento local do browser.

Arquivos principais:

- [`lib/main.dart`](./lib/main.dart): inicialização, login, lista de receitas,
  filtros, formulário e telas de detalhe.
- [`lib/data/recipe_database.dart`](./lib/data/recipe_database.dart): banco de
  dados, autenticação, receitas, favoritos e compatibilidade com registros
  antigos.
- [`lib/database_factory_setup.dart`](./lib/database_factory_setup.dart) e os
  arquivos `database_factory_setup_*`: seleção do mecanismo de banco conforme
  a plataforma.
- [`test/widget_test.dart`](./test/widget_test.dart): testes de banco,
  autenticação, operações de receita, dados antigos e tela de login.
- [`README.md`](./README.md): instruções para executar o projeto.

## 5. Persistência e privacidade

O banco é local. Não há servidor, sincronização entre dispositivos, recuperação
de senha ou compartilhamento de conta entre instalações. Os dados salvos no
Android, Windows e navegador não são automaticamente compartilhados entre si.
No navegador, o armazenamento depende do endereço e da porta utilizados.

O mecanismo de hash protege contra guardar a senha em texto simples, mas o login
local não equivale a uma autenticação em servidor. A conta e as receitas ficam
no armazenamento do dispositivo e podem ser perdidas se os dados do aplicativo
forem apagados ou se o dispositivo for removido.

## 6. Execução em plataformas

O projeto tem configuração para Android, Windows e Web. O iOS exige macOS e as
ferramentas da Apple; Linux e macOS desktop não foram configurados.

Durante a preparação para Android, foi necessário configurar o Android SDK,
usar Java 17 ou superior, aceitar as licenças do SDK e instalar o NDK exigido
pelo Gradle. A instalação no telefone também depende de autorizar a instalação
via USB no próprio aparelho. Essas configurações são do ambiente de
desenvolvimento e podem variar entre computadores.

Com o Flutter disponível no terminal:

```powershell
flutter pub get
flutter devices
flutter run -d <id-do-dispositivo>
```

Para executar no Windows ou Chrome, use `flutter run -d windows` ou
`flutter run -d chrome`. Consulte o [`README.md`](./README.md) para detalhes
adicionais de execução e persistência Web.

## 7. Verificações realizadas

O projeto foi validado com:

- `flutter test test\widget_test.dart`: testes aprovados, incluindo a ausência
  de receitas iniciais e a remoção de receitas pré-definidas sem apagar uma
  receita pessoal.
- `flutter analyze`: sem problemas encontrados.
- Compilações de depuração para Android e Windows e compilação de produção Web:
  concluídas com sucesso.

## 8. Estado atual e possíveis melhorias

O escopo atual atende ao uso pessoal offline descrito durante o desenvolvimento.
Como próximos passos opcionais, podem ser considerados exportação ou backup das
receitas, sincronização entre dispositivos, recuperação de senha e distribuição
do aplicativo. Esses recursos exigiriam decisões adicionais sobre contas,
servidor, cópias de segurança e proteção dos dados.

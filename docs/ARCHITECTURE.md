# SpoolIQ Desktop — Arquitetura e convenções

App Flutter desktop (macOS + Windows) para a API SpoolIQ (`https://api.spooliq.com/v1`,
swagger em `../spooliq/docs/swagger.json`). UI sobre o design system **Forma**
(`forma_ui` + `forma_theme_spooliq`, usados via `pubspec_overrides.yaml` apontando
para `../forma` até a publicação).

## Estrutura

```
lib/
├── app/                 # App, shell (sidebar/topbar/command palette), tema
├── core/
│   ├── auth/            # SessionUser (JWT), Role, Permissions, TokenStore
│   ├── config/          # AppConfig (--dart-define)
│   ├── di/injector.dart # get_it — repositórios registrados pela INTERFACE
│   ├── format/          # Fmt: dinheiro (centavos), datas, gramas, tempo (pt-BR)
│   ├── network/         # ApiClient (dio), ApiError sealed, Paginated, PageQuery, Json helpers
│   ├── observability/   # AppLogger (Sentry), AppBlocObserver
│   ├── routing/         # Routes, navigation (sidebar/palette), app_router (go_router)
│   ├── state/           # PagedListCubit<T> genérico
│   └── ui/              # PageLayout, SectionCard, PagedTable, SearchField, Toasts, ErrorView…
└── features/<feature>/
    ├── domain/          # modelos (Equatable + fromJson) e interface do repositório
    ├── data/            # Api<Feature>Repository (usa ApiClient)
    └── presentation/    # páginas, cubits, widgets de domínio
```

## Regras

- **Camadas:** presentation → domain ← data. Cubits dependem da *interface* do
  repositório (obtida via `di<…>()` no `BlocProvider.create`). Widgets nunca chamam
  `ApiClient` direto.
- **Estado:** `Cubit` (flutter_bloc). Listagens simples usam `PagedListCubit<T>` +
  `PagedTable<T>`. Telas mais ricas têm cubit próprio com estado imutável (Equatable).
- **Erros:** o `ApiClient` só lança `ApiError` (sealed: `NetworkError`,
  `UnauthorizedError`, `ForbiddenError`, `SubscriptionError`, `ValidationError`
  (com `fields`), `NotFoundError`, `ConflictError`, `BusinessError`, `ServerError`).
  Capture `on ApiError` e mostre `e.message` (já vem em pt-BR do backend).
  401/402/403 de assinatura são tratados globalmente (sessão/banner).
- **Observabilidade:** `AppLogger.info/warning/error` (breadcrumbs + Sentry). Nunca
  logar tokens, senhas ou dados pessoais de clientes.
- **JSON:** use as extensões de `core/network/json.dart` (`str`, `strOrNull`,
  `integer`, `dbl`, `boolean`, `date`, `obj`, `list`, `unwrapData`) — nunca casts
  diretos. Requisições: `compactJson` remove nulos.
- **Dinheiro:** orçamentos, `price_per_kg` de filamento, `unit_price_per_kg` de
  estoque e `shipping_override` são **centavos (int)**. Presets (custos, energia,
  máquina) e desconto fixo são **reais (double)**. Formate com `Fmt.cents` /
  `Fmt.money`.
- **Pegadinhas da API:** `/company/` exige barra final; `GET /brands/{id}` e
  `/materials/{id}` vêm em `{data}`; clientes vêm como `{customer, budget_count,
  total_budgets, budgets}`; PDF pode ser JSON `{pdf_url}` ou bytes.
- **Permissões:** `core/auth/permissions.dart` (espelha `ROUTE_PERMISSIONS` da web e
  os papéis das rotas Go). A UI esconde/desabilita; o backend é a fonte da verdade.
- **UI:** só componentes Forma + tokens do tema (`FormaThemeExtension`,
  `context.formaTypography`, `context.formaShape`). Sem cores hardcoded, exceto
  cores de domínio (status de orçamento, cores de filamento, gráficos).
  Toda tela: loading (skeleton), vazio (`FormaEmptyState` com CTA), erro
  (`ErrorView` com retry), confirmação destrutiva (`confirmDelete`), feedback
  (`Toasts`). Textos em pt-BR.
- **Lints:** `very_good_analysis` + `bloc_lint`; `flutter analyze` sem issues.
- **Testes:** `test/` espelha `lib/`. Cubits com `bloc_test` + `mocktail`
  (repositório mockado); modelos com testes de `fromJson` usando payloads reais da API.

## Referência

`lib/features/catalog/presentation/brands_page.dart` é a tela-modelo de CRUD
(PagedListCubit + PagedTable + FormaDialog com formulário + FormaMenuButton).

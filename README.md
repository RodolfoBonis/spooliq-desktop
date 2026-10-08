# SpoolIQ Desktop

Aplicativo desktop (macOS e Windows) do SpoolIQ, para gerenciar orçamentos de
impressão 3D de ponta a ponta: quadro kanban, editor com preço calculado em
tempo real, clientes, catálogo e estoque de filamentos, presets, configurações
da empresa, assinatura e painel administrativo da plataforma.

Construído em Flutter sobre o design system **Forma** (tema `forma_theme_spooliq`)
e a API SpoolIQ (`https://api.spooliq.com/v1`).

## Requisitos

- Flutter 3.47.6 via [fvm](https://fvm.app) (`.fvmrc`)
- Checkout do Forma ao lado deste repo (`../forma`, branch `feat/desktop-foundation`)
  enquanto os pacotes desktop não forem publicados — veja `pubspec_overrides.yaml`
- macOS: Xcode 16+. Windows: Visual Studio 2022 com "Desktop development with C++"

## Rodando

```sh
fvm flutter pub get

# macOS (flavors: development, staging, production)
fvm flutter run -d macos --flavor development -t lib/main_development.dart

# Windows (sem flavors nativos; o entry point define o ambiente)
fvm flutter run -d windows -t lib/main_development.dart
```

| Flavor | API padrão |
|---|---|
| development | `http://localhost:8080/v1` (rode o backend `../spooliq`) |
| staging | `https://api.spooliq.stg.rb.lab/v1` |
| production | `https://api.spooliq.com/v1` |

Overrides via `--dart-define`: `API_BASE_URL`, `PUBLIC_BUDGET_BASE_URL`,
`SENTRY_DSN` (sem DSN o Sentry fica desligado).

## Atalhos

| Atalho | Ação |
|---|---|
| ⌘K / Ctrl+K | Paleta de comandos (navegar, buscar orçamentos e clientes, ações) |
| ⌘N / Ctrl+N | Novo orçamento |
| ⌘S / Ctrl+S | Salvar no editor de orçamento |
| Esc | Fecha diálogos, painéis e menus |

## Qualidade

```sh
fvm flutter analyze
fvm flutter test
```

Arquitetura e convenções: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Build de distribuição

```sh
fvm flutter build macos --release --flavor production -t lib/main_production.dart
fvm flutter build windows --release -t lib/main_production.dart
```

O CI (`.github/workflows/ci.yml`) roda analyze/test e gera os artefatos de macOS
e Windows. Segredos: `FORMA_REPO_TOKEN`, `PUB_TOKEN`, `SENTRY_DSN`.
Assinatura/notarização (macOS) e instalador MSIX (Windows) ainda não configurados.

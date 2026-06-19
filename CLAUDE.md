# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # install dependencies
flutter run -d chrome    # run in development (Chrome required)
flutter build web        # production build
flutter analyze          # lint/static analysis
flutter test             # run tests
```

## Architecture

**Flutter Web PWA** connecting to a FastAPI backend on AWS EC2.

```
LoginScreen → MainLayout → [DashboardScreen, TicketsScreen, EquipmentScreen, PantallaRespaldos]
```

**State management**: No external package. `MainLayout` is the central state owner — it holds `_tickets: List<Ticket>` and `_inventario: List<Equipo>`, fetches both in parallel on load, and passes an `onRefresh` callback to each child screen so they can trigger a global reload after mutations.

**Auth flow**: `LoginScreen` POSTs to `/login`, constructs a `Session` object (username, nombreCompleto, rol, token), instantiates `NotificationService`, then navigates to `MainLayout` via `Navigator.pushReplacement`. The `Session` is passed as a constructor argument through the widget tree — there is no global auth state.

**API layer** (`lib/services/api_service.dart`): `ApiService` is instantiated per-session with a Bearer token. The base URL and timeout are top-level consts (`kApiUrl`, `kTimeout`) also used directly by `LoginScreen`. To change the backend URL, update `kApiUrl` in `api_service.dart`.

**Models**: Plain Dart classes with `fromMap`/`toMap`. `Equipo` has two computed properties — `valorActual` (20% annual depreciation, floor at 20% of original value) and `diasUltimoRespaldo` (days since last backup, null if never backed up).

**Notifications** (`lib/services/notification_service.dart`): Wraps the browser Web Notifications API via the `web` package. Polls every 30 seconds. The `_revisarNuevosTickets` method is currently a stub — actual diff logic is not yet implemented. `NotificationService.lanzarAlertaLocal()` is a static helper for dispatching a browser notification anywhere in the app.

**Roles**: `Admin` sees all tickets and full inventory controls. `Técnico` sees only their assigned tickets. Role is a plain string from the API response — check `session.rol == 'Admin'` in screens to gate features.

**Backup alert thresholds**: yellow = `ultimoRespaldo == null`, red = `diasUltimoRespaldo > 15`.

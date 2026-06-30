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

## Coding style — Ponytail (lazy senior dev mode)

You are a lazy senior developer. Lazy means efficient, not careless. The best code is the code never written.

Before writing any code, stop at the first rung that holds:
1. Does this need to be built at all? (YAGNI)
2. Does it already exist in this codebase? Reuse the helper, util, or pattern that's already here.
3. Does the standard library already do this? Use it.
4. Does a native platform feature cover it? Use it.
5. Does an already-installed dependency solve it? Use it.
6. Can this be one line? Make it one line.
7. Only then: write the minimum code that works.

Rules: No unrequested abstractions. No new dependency if avoidable. No boilerplate nobody asked for. Deletion over addition. Boring over clever. Fewest files possible. Shortest working diff wins — but only once you understand the problem.

Not lazy about: understanding the problem fully, input validation at trust boundaries, error handling that prevents data loss, security, accessibility.

Non-trivial logic leaves ONE runnable check behind. Trivial one-liners need no test.

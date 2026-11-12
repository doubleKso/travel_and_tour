# Porting guide: Flutter → native Swift

This is the contract for porting `lib/` to `ios_native/EpicWorld/`. Read it before you
write any Swift. The goal is **the same logic, UI and flow** as the Flutter app.
That means a line-by-line port, not a redesign. If the Dart code does something
odd, port the oddity and keep its comment.

The foundation already exists: `Core/` and `App/`. Read those files. Use them instead
of re-inventing them, and don't change their public API. If a feature genuinely
needs something the foundation lacks, add it inside the feature, and note it in your
final report so it can be promoted later.

---

## 1. Ground rules

1. **One Dart file → one Swift file**, same base name in PascalCase, at the mirrored path:
   `lib/features/booking/domain/entities/trip_option_model.dart` →
   `EpicWorld/Features/Booking/Domain/Entities/TripOptionModel.swift`.
   Folder mapping: `data/datasources` → `Data/DataSources`, `data/models` → `Data/Models`,
   `data/repositories` → `Data/Repositories`, `domain/entities` → `Domain/Entities`,
   `domain/repositories` → `Domain/Repositories`, `domain/usecases` → `Domain/UseCases`,
   `presentation/pages|widgets|providers|bloc|pdf` → `Presentation/Pages|Widgets|Providers|Bloc|Pdf`,
   `di` → `DI`. Barrel files (`feature_x.dart`) have no Swift equivalent. Skip them.
2. Start every file with `// Port of lib/…/x.dart` and keep the Dart doc comments,
   translated to `///`.
3. **Names are identical to Dart.** That covers classes, enums, enum cases, fields,
   getters, methods, named parameters and providers (with the `Provider` suffix
   dropped, §5). Other features reference your types by their Dart names without
   seeing your code, so a renamed member breaks someone else's file.
   - Dart private `_Foo` → Swift `private struct Foo` (file-scoped). If the name
     would shadow a SwiftUI/Foundation type (`Section`, `Label`, `Group`, `Image`, `Text`,
     `Badge`, `Tab`, `Divider`, `Spacer`, `Menu`, `Picker`, `Toggle`, `Link`, `Form`,
     `List`, `Grid`, `Table`, `Button`, `Shape`, `Path`, `Canvas`, `Color`, `Font`,
     `Data`, `Date`, `URL`, `Notification`, `Timer`, `Task`, `Result`, `Error`),
     add a `View` suffix: `SectionView`.
   - Dart private members `_load()` → Swift `private func load()`.
   - A Dart name that is a Swift keyword gets backticks in the declaration
     (``case `default` ``). Call sites can still say `.default`.
4. Swift language mode is **5** with minimal concurrency checking. Mark view models,
   notifiers and blocs `@MainActor`. Don't sprinkle `Sendable`.
5. Don't add features, don't "fix" behaviour, and don't drop a branch because it
   looks dead. If something truly cannot exist on iOS (an Android-only path, a
   web-only `kIsWeb` branch), keep the iOS/mobile branch and leave a one-line
   comment saying why the other was dropped.
6. No `TODO` stubs in place of real code. If a piece is genuinely blocked, write as
   much as possible and list it in your report.

## 2. Language mapping

| Dart | Swift |
| --- | --- |
| `int` / `double` / `num` / `bool` / `String` | `Int` / `Double` / `Double` / `Bool` / `String` |
| `T?` | `T?` |
| `List<T>` / `Map<K,V>` / `Set<T>` | `[T]` / `[K: V]` / `Set<T>` (needs `Hashable`) |
| `Map<String, dynamic>` (JSON) | `JSON` (= `[String: Any]`) |
| `dynamic` / `Object?` | `Any?` |
| `final class X { final a; const X({required this.a, this.b = 1}); }` | `struct X { let a: A; var b: Int = 1 }` with an explicit `init(a:b:)` in Dart's parameter order and defaults |
| Value equality (`==`/`hashCode`, `Equatable`) | `: Equatable` (or `Hashable`) |
| `X copyWith({A? a, bool clearB = false})` | `func copyWith(a: A? = nil, clearB: Bool = false) -> X` with the same `??` semantics |
| `factory X.fromJson(Map j)` | `static func fromJson(_ json: JSON) -> X` (call sites stay `X.fromJson(j)`) |
| `Map<String, dynamic> toJson()` | `func toJson() -> JSON` |
| Named constructor `X.initial()` / `X.empty()` | `static func initial() -> X` |
| getter `bool get isEmpty => …` | `var isEmpty: Bool { … }` |
| `static const k = …` | `static let k = …` |
| `enum E { a, b }` | `enum E: String, CaseIterable, DartEnum { case a, b }` (gives `.name`, `.index`, `E.values`, `E.byName`) |
| Enhanced enum with fields/methods | the same enum with computed properties / `switch` |
| `sealed class S` + subclasses | `enum S` with associated values, or a protocol + structs. Keep the subclass names as cases or types. |
| `abstract interface class R { Future<Result<T>> f(); }` | `protocol R: AnyObject { func f() async -> AppResult<T> }` |
| `abstract class` with shared code | protocol + extension, or a base class |
| mixin | protocol + extension |
| `late final x = …` | `lazy var x = …` |
| `Future<T>` / `async` / `await` | `async` / `await`; throwing APIs `async throws` |
| `unawaited(f())` | `Task { await f() }` |
| `Future.delayed(d)` | `try? await Task.sleep(for: d)` |
| `Timer.periodic(d, cb)` / `Timer(d, cb)` | a `Task` loop with `Task.sleep`, cancelled where Dart cancels the timer (or `Timer.scheduledTimer`) |
| `Stream<T>` / `StreamController` | `AsyncStream<T>` / its continuation |
| `Completer<T>` | `withCheckedContinuation` |
| `throw Exception('m')` / `FormatException` / `StateError` | the same-named Swift types in `Core/Foundation/AppFailure.swift` |
| `try { } catch (e) { }` | `do { } catch { }` |
| `e is SomeType` | `e is SomeType` / `as?` |
| `'$a ${b.c}'` | `"\(a) \(b.c)"` (for a dynamic value, use `Dart.interpolate(v)` to get Dart's `null`/`1.0` text) |
| `list.where(f).map(g).toList()` | `list.filter(f).map(g)` |
| `list.firstWhere(f, orElse: () => x)` | `list.first(where: f) ?? x` |
| `list.firstOrNull` / `lastOrNull` | `list.first` / `list.last` |
| `list.fold(init, f)` | `list.reduce(init, f)` |
| `list.expand(f)` | `list.flatMap(f)` |
| `list.any` / `every` | `contains(where:)` / `allSatisfy` |
| `list..sort((a, b) => a.x.compareTo(b.x))` | `list.sort { $0.x < $1.x }`. Keep stability where Dart relies on it. |
| `s.trim()` / `toLowerCase()` / `split(',')` | `trimmingCharacters(in: .whitespacesAndNewlines)` / `lowercased()` / `components(separatedBy: ",")` |
| `s.isEmpty` / `isNotEmpty` | `isEmpty` / `!isEmpty` |
| `RegExp(r'…')` | `NSRegularExpression` or `range(of:options: .regularExpression)` |
| `math.max` / `min` / `pi` | `max` / `min` / `Double.pi` |
| `int.parse` / `double.tryParse` | `Dart.parseInt` / `Dart.parseDouble` |
| `const Duration(minutes: 5)` | `Duration(minutes: 5)` (Dart API on Swift `Duration`, see `DateTime.swift`) |
| `DateTime` | `DateTime` (see §3, **not** `Date`) |
| `Uuid().v4()` | `UUID().uuidString.lowercased()` |
| `kDebugMode` | `#if DEBUG` |
| `print` / `debugPrint` / `superPrint` | `superPrint(…)` |

Dart named arguments may appear in any order. Swift labels must follow declaration order, so reorder the call sites.

## 3. Foundation you must use

| Need | Use | File |
| --- | --- | --- |
| `Result<T>`, `Failure` | `AppResult<T>` (= `Result<T, AppFailure>`), `.success`, `.failure`, `fold`, `dataOrNull`, `isSuccess`; failures `.network()`, `.server(message:statusCode:)`, `.cache`, `.parsing`, `.unexpected`, `failure.message`, `failure.isNetwork` | `Core/Foundation/AppFailure.swift`, `AppResult.swift` |
| `UseCase<T, P>`, `NoParams` | `protocol UseCase` with `callAsFunction(_:) async -> AppResult<T>`; `NoParams()` | `UseCase.swift` |
| Dart `DateTime` | `DateTime` struct with `isUtc`, `DateTime(2026, 9, 1)`, `.utc(…)`, `.now()`, `parse`/`tryParse`, `add`, `difference`, `isBefore`, `toLocal`, `toIso8601String`, `weekday` (Mon = 1), `dateOnly` | `DateTime.swift` |
| `Duration` | `Duration(days:hours:minutes:seconds:milliseconds:)`, `.inMinutes`, `.inHours`, `.inDays`, `.isNegative` | `DateTime.swift` |
| intl | `DateFormat("EEE, d MMM").format(dt)`, `DateFormat.Hm()`, `parseStrict`, `NumberFormat.decimalPattern()`, `NumberFormat("#,##0.00")` (English, like the Flutter app) | `IntlFormat.swift` |
| JSON dynamic typing | `Dart.str`, `Dart.int`, `Dart.double`, `Dart.bool`, `Dart.map`, `Dart.list`, `Dart.maps`, `Dart.isNum`/`isInt`/`isBool`/`isString`/`isNull`, `Dart.interpolate`, `jsonDecode`, `jsonEncode` | `Dart.swift` |
| Firebase callables | `CallableInvoking` (`container.functions`): `try await functions.call(F.functionsUrl(Endpoints.x), body)` → `Any?`; errors are `FunctionsException(code:message:details:)` | `Core/Network/FunctionsException.swift` |
| Dio | `HTTPClient` (`container.http`): `get/post/put/patch/delete(path, data:, query:)` → `HTTPResponse(statusCode, data)`; errors `HTTPException(type: .badResponse/.connectionTimeout…)` | `HTTPClient.swift` |
| `ApiException`, `FailureMapper` | same names: `ApiException.callablePayload(data, endpoint:)`, `.messageFrom`, `.isSessionExpired`, `.fromFunctions` (Dart `fromFirebaseFunctions`), `.fromHTTP` (Dart `fromDio`), `FailureMapper.from(error)` | `ApiException.swift` |
| `AppResponse<T>` | same | `AppResponse.swift` |
| `Endpoints`, `F`, `Env`, `AppConsts`, `AppAssets` | same names and members | `Core/Network`, `App/Config`, `Core/Config` |
| `SharedPreferences` / `AppPrefs` | `AppPrefs.getString/setString/getBool/…/remove` (same `flutter.` keys, synchronous). Raw `SharedPreferences` use in Dart → `AppPrefs` with the same key. | `Core/Storage/AppPrefs.swift` |
| `flutter_secure_storage` | `SecureSessionStore` (session) or `KeychainStore().read/write/delete(key)` (same service/account layout) | `SecureSessionStore.swift` |
| easy_localization | `LocaleKeys.x_y.tr()`, `.tr(args: [...])`, `L10n.change(code)`, `L10n.currentCode`, `LocaleStore.shared.code` | `Core/Config/L10n.swift`, `LocaleKeys.swift` (generated) |
| `Formatters`, `AccessToken`, `ContactLauncher` | same names. `ContactLauncher.dial(n)` etc. are `async` and take no `BuildContext`. | `Core/Utils` |
| Share sheet / `printing` | `SharePresenter.share([items])`, `SharePresenter.sharePdf(data, filename:)` | `Core/Utils/SharePresenter.swift` |

`ApiException.callablePayload` and `HTTPClient` already log in debug builds.

## 4. Data layer pattern

```swift
// Port of lib/features/booking/data/datasources/flight_search_callable_service.dart
final class FlightSearchCallableService {
    private let functions: CallableInvoking
    init(_ functions: CallableInvoking) { self.functions = functions }

    func searchFlights(_ request: FlightSearchRequest) async throws -> [TripOptionModel] {
        let data = try await functions.call(F.functionsUrl(Endpoints.searchFlights), request.toJson())
        let payload = try ApiException.callablePayload(data, endpoint: Endpoints.searchFlights)
        return Dart.maps(payload["flights"]).map(TripOptionModel.fromJson)
    }
}

// Repository: catch → FailureMapper, exactly where Dart catches.
func submitFlightSearch(_ request: FlightSearchRequest) async -> AppResult<[TripOptionModel]> {
    do { return .success(try await remote.searchFlights(request)) }
    catch { return .failure(FailureMapper.from(error)) }
}
```
Where Dart catches `FirebaseFunctionsException` specifically, catch `let e as FunctionsException`.
Where it catches `DioException`, catch `let e as HTTPException`.

## 5. State and DI

**Every Riverpod provider becomes a property on `AppContainer`.** Use the same name
with `Provider` dropped, declared in an `extension AppContainer` in the same Swift
file that ports the Dart file declaring it (`*_module.dart` → `DI/XModule.swift`,
`*_providers.dart` → `Presentation/Providers/XProviders.swift`).

| Dart | Swift |
| --- | --- |
| `Provider<T>((ref) => X(ref.watch(a)))` | `var x: T { provide { X(a) } }` (cached) |
| derived `Provider<bool>((ref) => ref.watch(n).isAuthenticated)` | `var isAuthenticated: Bool { authNotifier.state.isAuthenticated }` (computed, not cached) |
| `StateNotifierProvider<N, S>` | `var n: N { provide { N(…) } }` where `@MainActor @Observable final class N { private(set) var state: S }` |
| `ChangeNotifierProvider<C>` | `var c: C { provide { C(…) } }` where `C` is `@MainActor @Observable` |
| `FutureProvider<T>` | `var p: AsyncResource<T> { provide { AsyncResource(dependencies: {…}) { try await … } } }`. Views read `container.p.state.when(data:error:loading:)`. |
| `FutureProvider.family<T, A>` | `AsyncResourceFamily<A, T>`. Call it as `container.p(arg).state`. |
| `StateProvider<T>` | `var p: StateBox<T> { provide { StateBox(initial) } }`. Read and write `.value`. |
| `.autoDispose` | ignore (kept alive) unless disposal changes behaviour. If it does, reset in `onDisappear`. |
| `ref.watch(a)` inside a provider body | read `a` inside the `dependencies:` closure (reloads when it changes) or the factory |
| `ref.listen(p, (prev, next) {…})` in a widget | `.onChange(of: container.p.state.someEquatable) { old, new in … }` |
| `ref.invalidate(futureProvider)` / `ref.refresh(…)` | `container.p.invalidate()` / `await container.p.refresh()` |
| `ref.read(p.future)` | `try await container.p.future` |
| `ref.read(p.notifier).foo()` | `container.p.foo()` |
| `ref.read(mainShellTabProvider.notifier).state = 2` | `container.mainShellTab.value = 2` |
| `ProviderScope(overrides: […])` (tests) | `container.override("name", with: fake)` before first read |

A `FutureProvider` body that throws a failure (`result.fold((f) => throw f, …)`)
becomes `try await useCase(params).get()`. Swift's `Result.get()` throws the
`AppFailure`.

Notifier skeleton:

```swift
// Port of lib/features/ticket/presentation/providers/ticket_notifier.dart
@MainActor
@Observable
final class TicketNotifier {
    private(set) var state: TicketState
    private let getMyTickets: GetMyTicketsUseCase
    init(getMyTickets: GetMyTicketsUseCase) { self.getMyTickets = getMyTickets; state = .initial() }
    func load() async {
        state = state.copyWith(isLoading: true)
        let result = await getMyTickets(NoParams())
        result.fold(
            { failure in state = state.copyWith(isLoading: false, error: failure.message) },
            { tickets in state = state.copyWith(isLoading: false, tickets: tickets) }
        )
    }
}
```

**Flight booking (BLoC).** `FlightBookingBloc` stays a bloc: a `@MainActor @Observable`
class with `private(set) var state: FlightBookingState`, an `enum FlightBookingEvent`,
and `func add(_ event: FlightBookingEvent)`. The event enum is used by four port groups,
so its shape follows one rule. Each Dart event class becomes a case named in
lowerCamelCase. Positional constructor parameters become **unlabeled** associated
values. Named parameters become **labeled** associated values with the Dart names
and defaults, in the Dart order. A class without parameters becomes a bare case.

| Dart event | Swift case |
| --- | --- |
| `TravelModeChanged(mode)` | `.travelModeChanged(TravelMode)` |
| `ReturnDateChanged(DateTime? date)` | `.returnDateChanged(DateTime?)` |
| `LocationsSwapped()` / `FlightSearchRequested()` | `.locationsSwapped` / `.flightSearchRequested` |
| `ResultsReloaded({DateTime? date})` | `.resultsReloaded(date: DateTime? = nil)` |
| `SortOrderChanged({required bool ascending})` | `.sortOrderChanged(ascending: Bool)` |
| `FiltersApplied({maxStops, classFilter, maxPrice, airlines, departureTimes})` | `.filtersApplied(maxStops: Int? = nil, classFilter: TravelClass? = nil, maxPrice: Double? = nil, airlines: Set<String>? = nil, departureTimes: Set<String>? = nil)` (types as in Dart) |
| `HeldReservationConfirmed({request, response})` | `.heldReservationConfirmed(request: FlightHoldRequest, response: FlightHoldResponse)` |
| `HeldBookingResumed({…, stage = BookingStage.payment})` | `.heldBookingResumed(from:to:departDate:adults:children:infants:cabinClass:outbound:inbound:holdRequest:holdResponse:stage:)` with the Dart defaults |
| private `_DailyMinPricesRequested()` | `.dailyMinPricesRequested` (only the bloc sends it) | Handlers run in order on the main actor.
`restartable()` handlers cancel the previous `Task` of the same event type, and the
Dart `emit.isDone` check becomes a `Task.isCancelled` check. The Riverpod bridge goes
away: `flightBookingBlocProvider` → `container.flightBookingBloc`,
`flightBookingStateProvider` → `container.flightBookingBloc.state`,
`context.read<FlightBookingBloc>()` / `context.watch<…>().state` → `container.flightBookingBloc`.

Views get the container with `@Environment(AppContainer.self) private var container`
and the router with `@Environment(AppRouter.self) private var router`. Reading
`container.x.state` in `body` re-renders on change (Observation).

## 6. Navigation

Routes are `Route` cases (`App/Router/Route.swift`). Page structs take the route's
arguments with the same labels. `RouteView` already instantiates every page, so
**your page's initializer must match exactly** (`LoginPage(popOnSuccess:)`,
`LocationPickerPage(title:exclude:)`, `HistoryPage(onBack:)`, `TicketDetailPage(ticket:)`
and so on; see `RouteView.swift`).

| Dart (auto_route / Navigator) | Swift (`AppRouter`) |
| --- | --- |
| `context.router.push(XRoute(a: 1))` | `router.push(.x(a: 1))` |
| `final v = await context.router.push<T>(XRoute())` | `let v = await router.pushForResult(.x, as: T.self)` |
| `await context.router.push(XRoute())` (wait for pop) | `await router.pushAndWait(.x)` |
| `context.router.pop(v)` / `Navigator.pop(context, v)` (page) | `router.pop(v)` |
| `context.router.maybePop()` / back button | `await router.maybePop()` |
| `context.router.replace(XRoute())` | `router.replace(.x)` |
| `context.router.replaceAll([A(), B()])` | `router.replaceAll([.a, .b])` |
| `context.router.navigate(XRoute())` | `router.navigate(.x)` |
| `context.router.popUntilRoot()` / `popUntil(…)` | same names |
| `context.router.current.name == XRoute.name` | `router.currentName == "XRoute"` (`Route.loginName`, `Route.paymentName`) |
| `context.router.canPop()` | `router.canPop` |
| `PopScope(canPop: c, onPopInvokedWithResult: (didPop, _) {…})` | `.popScope(canPop: c) { didPop in … }` |
| `Navigator.pop(context, v)` inside a dialog/sheet | the `dismiss(v)` closure, or `@Environment(\.dismissModal)` |

`flightSearchLoading` is drawn as a transparent overlay above the stack: push and pop work the same.

## 7. UI translation

**Fidelity first.** Same sizes, paddings, radii, colours, fonts, icons, copy, ordering
and animations as the Dart widget tree. Port the widget tree top-down.

- **Scaffold/AppBar:** `Scaffold { … }`, `Scaffold(title:) { … }` or
  `Scaffold(appBar: { AppBar(title: …) { actions } }) { … }` (`Core/UI/Components/AppBar.swift`).
  `RouteView` hides the system navigation bar on every page. Never use `.navigationTitle`.
  Pages with a custom header (no AppBar in Dart) just draw it.
- **Stacks have no default spacing in Flutter.** Always write `VStack(alignment: .leading, spacing: 0)`
  and `HStack(spacing: 0)`, and use `VGap(8)` / `HGap(8)` / `Gap(8)` for `SizedBox`.
  Column's default cross alignment is **center**: use `VStack(spacing: 0)` and pin children to the leading edge with `.frame(maxWidth: .infinity, alignment: .leading)` only where Dart uses `CrossAxisAlignment.start`.
- `Expanded` → `.frame(maxWidth: .infinity)` (Row) or `.frame(maxHeight: .infinity)` (Column).
  `Flexible`/`flex:` → `layoutPriority` or proportional `GeometryReader` only if needed.
- `Padding(EdgeInsets.fromLTRB(l,t,r,b))` → `.padding(l, t, r, b)`;
  `EdgeInsets.symmetric(horizontal:vertical:)` → `.padding(horizontal:vertical:)`;
  `EdgeInsets.all(n)` → `.padding(n)`.
- `Container(decoration: BoxDecoration(…))` → `.boxDecoration(color:gradient:radius:corners:circle:borderColor:borderWidth:shadows:)`
  with `BoxShadow(color:blurRadius:offset: Offset(x, y))`. `BorderRadius.vertical(top: 16)` → `corners: BorderRadius.vertical(top: 16)`.
- `ClipRRect` → `.clipShape(RoundedRectangle(cornerRadius:))`. `Stack` → `ZStack(alignment:)`.
  `Positioned` → `.overlay(alignment:)` / `.offset` / `.padding` in a `ZStack`.
- `Text(s, style: AppTypography.body(14, weight: FontWeight.w600, color: c))` →
  `Text(s).textStyle(AppTypography.body(14, weight: .w600, color: c))`. **Every** Text gets a
  style, because SwiftUI's default (SF 17) is not Flutter's (Roboto 14). `maxLines`/`overflow` →
  `.lineLimit(n)` / `.truncationMode(.tail)`. `TextAlign.center` → `.multilineTextAlignment(.center)`.
  `Text.rich`/`TextSpan` → `Text(a).styled(s1) + Text(b).styled(s2)`.
  `Theme.of(context).textTheme.bodyMedium` → `AppTypography.bodyMedium`.
- Colours: `AppColors.x`, Flutter `Colors.white/black/grey300/black54…` → `Colors.x`
  (`Core/UI/Tokens/AppColors.swift`), `Color(0xFF123456)` → `Color(0xFF123456)`,
  `c.withValues(alpha: a)` → `c.withValues(alpha: a)`. Gradients: SwiftUI `LinearGradient`
  with `UnitPoint` (`Alignment.topLeft` → `.topLeading`).
- Icons: `Icon(Icons.x, size:, color:)` → identical (Flutter's own font). If you use an icon
  that isn't in `Core/UI/Icons.swift` yet, it's fine: it gets generated by
  `scripts/gen_material_icons.sh` (which scans Swift too). Mention it in your report.
- Images: `Image.asset(AppAssets.x)` / `SvgPicture.asset(AppAssets.x)` → `AppImage(AppAssets.x, width:, height:, fit:, tint:)`.
  `CachedNetworkImage`/`Image.network` → `NetworkImage(url, fit:) { placeholder } error: { … }`.
- Buttons: `ElevatedButton` → `Button { } label: { }.buttonStyle(ElevatedButtonStyle(…))`
  (parameters mirror `styleFrom`). `OutlinedButtonStyle`, `TextButtonStyle`. `InkWell`/`GestureDetector`
  → `Button { } label: { }.buttonStyle(.ink)` / `.ink(radius:)` or `.onTapGesture`.
  `IconButton` → `Button { } label: { Icon(…).frame(width: 48, height: 48) }.buttonStyle(.plain)`.
- Inputs: `TextFormField`/`TextField` → `AppTextField(text:hintText:labelText:prefixIcon:errorText:…)`.
  The validator logic stays in the page and is passed in as `errorText`. Form `validate()` →
  compute errors on submit, exactly as Dart does.
- Lists: `ListView` → `ScrollView { LazyVStack(spacing: 0) { … } }`; `ListView.separated` → interleave
  separators; `GridView` → `LazyVGrid`; `SingleChildScrollView` → `ScrollView`; `RefreshIndicator` →
  `.refreshable { await … }`; `PageView`/carousel → `TabView(selection:).tabViewStyle(.page(indexDisplayMode: .never))`
  or a paging `ScrollView`; `Wrap` → a flow layout (write a small `Layout` if needed).
- `CircularProgressIndicator` → `ProgressView().tint(…)` (or `FlightOrbitLoader` where Dart uses it).
- `Switch` / `Checkbox` / `Radio` → SwiftUI `Toggle(...).tint(AppColors.primary)` / custom
  square / custom circle drawn like Material.
- Dialogs/sheets: `showDialog<T>` → `let v: T? = await showDialog { dismiss in … }`;
  `showModalBottomSheet<T>` → `await showModalBottomSheet(isScrollControlled:…) { dismiss in … }`
  (`Core/UI/Components/Modals.swift`). Draw the Dart dialog's own widgets (AlertDialog → a white
  rounded card, 28pt radius in M3). Dismiss a modal before pushing a route from it.
- `showDatePicker` → a dialog containing `DatePicker(…, displayedComponents: .date).datePickerStyle(.graphical)`
  with the same first/last dates, tinted `AppColors.primary`.
- Snack bars: `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)))` →
  `SnackBarCenter.shared.show(m, floating: <true if behavior: floating>)`.
- Animations: `AnimatedContainer`/`AnimatedOpacity`/`AnimatedSwitcher` → `.animation(.easeInOut(duration:), value:)`
  and `.transition`. `AnimationController` + `Tween` → `@State` progress plus `withAnimation`, or
  `TimelineView(.animation)` for continuous ones. Keep the durations and curves
  (`Curves.easeOutCubic` → `.timingCurve(0.215, 0.61, 0.355, 1)`, `easeInOut` → `.easeInOut`).
- `CustomPaint` → `Canvas` or `Shape`. `MediaQuery.of(context).size` → `GeometryReader` or
  `containerRelativeFrame`. `padding.top` → `safeAreaInsets`. `SafeArea` → default SwiftUI
  behaviour (use `.ignoresSafeArea` where Flutter draws under the bars). `LayoutBuilder` → `GeometryReader`.
- `initState` → `.task { }` (async) or `.onAppear`. `addPostFrameCallback` → `.task` / `DispatchQueue.main.async`.
  `dispose` → `.onDisappear`. Controllers become `@State` values. `FocusNode` becomes `@FocusState`.
  `mounted` checks become a check that the task wasn't cancelled.

## 8. Platform services

| Flutter plugin | iOS |
| --- | --- |
| `firebase_auth` + `google_sign_in` | `FirebaseAuth` + `GoogleSignIn` (`GIDSignIn.sharedInstance`, `GIDConfiguration(clientID: FirebaseApp.app()?.options.clientID, serverClientID: Env.googleWebClientId)`, `signIn(withPresenting: UIApplication.shared.topViewController!)`, `GoogleAuthProvider.credential(withIDToken:accessToken:)`) |
| `firebase_messaging` + `flutter_local_notifications` | `FirebaseMessaging` + `UNUserNotificationCenter`. Install `AppDelegate.Hooks` in `initialize()`, and replay `AppDelegate.Hooks.pendingResponse`. |
| `image_picker` | `PhotosPicker` / `UIImagePickerController` |
| `image_gallery_saver_plus` + `permission_handler` | `PHPhotoLibrary.requestAuthorization(for: .addOnly)` + `UIImageWriteToSavedPhotosAlbum` / `PHAssetChangeRequest` |
| `pdf` + `printing` | `UIGraphicsPDFRenderer` (or `ImageRenderer` → PDF) + `SharePresenter.sharePdf` |
| widget → image (`RepaintBoundary.toImage`) | `ImageRenderer(content:).uiImage` (scale 3) |
| `qr_flutter` / `barcode_widget` | CoreImage `CIFilter.qrCodeGenerator()` / `code128BarcodeGenerator()` / `pdf417BarcodeGenerator()` with `interpolation(.none)` |
| `url_launcher` | `ContactLauncher.open(url)` / `UIApplication.shared.open` |
| `webview_flutter` | iOS uses the system browser in the Flutter app too: open the URL externally |
| `package_info_plus` | `Bundle.main.infoDictionary["CFBundleShortVersionString"/"CFBundleVersion"]` |
| `confetti` | a small SwiftUI particle view (`TimelineView` + `Canvas`) with the same colours/duration |
| `carousel_slider` / `smooth_page_indicator` | paging `TabView` / custom dots matching the indicator style |

## 9. Contracts the app shell depends on

These are referenced by code that already exists (`App/AppWidget.swift`, `MainShellPage.swift`,
`RouteView.swift`, `Route.swift`). Implement them with exactly these shapes.

- **Pages**: every page struct listed in `RouteView.swift` with that initializer. Plus `HomePageV2()`.
- **Route argument types**: `TicketModel`, `LocationModel`, `HotelCategory`, `TourPackage`.
- **Auth** (`container.authNotifier: AuthNotifier`): `state.isAuthenticated: Bool`,
  `func restoreSessionFromApi() async`, `func ensureValidAccessToken() async`, plus everything the Dart notifier has.
- **Notifications**: `container.pushNotificationService: PushNotificationService` (`@MainActor @Observable final class`) with
  `pendingOpen: PushMessage?`, `func takePendingOpen() -> PushMessage?`, `isInitialized: Bool`,
  `func initialize() async`, `func requestPermissionIfNeeded() async`, `func refreshPermission() async`.
  `PushMessage` is a **`final class`** (identity compared with `===`, Dart's `identical`) with `notificationId: String?`.
  `container.notificationRemoteList: AsyncResource<…>`, and `func markNotificationRead(_ id: String) async` on `AppContainer`
  (Dart's top-level `markNotificationRead(ref, id)`).
- **Prefetched resources** (`AsyncResource`, from the Dart providers of the same names): `locationList`,
  `activeCountryList`, `activeFlightCarrierList`, `activeFlightScheduleList`, `globalAirlineRateList`,
  `tierAirlineRateList`, `tourPackageList`, `hotelList`, `membershipTierList`, `memberTierBenefitList`,
  `memberGlobalAirlineRateList`, `memberTierAirlineRateList`, `activeVisaCountryList`,
  `publishedVisaTypeCountryList`, `discountTierList`, `myPoints`.
- **Payment return**: `PaymentReturnPage.routePath: String` and `static func isReturnUrl(_ url: URL) -> Bool`.

## 10. Tests

Port the Dart unit tests for logic you own (`test/features/<f>/data|domain|presentation/bloc|providers`)
to XCTest under `EpicWorldTests/Features/<Feature>/…`, same file names in PascalCase plus `Tests`.
Use hand-written fakes like the Dart ones. Skip widget tests (`testWidgets`, golden/finder based),
but if a widget test asserts real logic (a computed label, a rule), port that assertion as a unit
test of the function that computes it. `blocTest` → drive `add(…)` and await settling
(`await Task.yield()` loops or polling `state`).

## 11. Done checklist (per file)

- [ ] Mirrored path and name, header comment, doc comments kept
- [ ] Every Dart member ported with the same name; no behaviour dropped
- [ ] Uses the foundation types (DateTime, Dart helpers, AppResult, FailureMapper, AppImage, Icon, textStyle…)
- [ ] Views: same tree, sizes, colours, copy keys, icons; every `Text` styled; stacks `spacing: 0`
- [ ] Providers declared as `AppContainer` extensions under the Dart names minus `Provider`
- [ ] Unit tests ported for the logic in the file

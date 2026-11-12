import Foundation
import Observation

/// Riverpod's `FutureProvider` as an observable object.
///
/// Reading `state` starts the first load — the way watching a `FutureProvider`
/// does — so a view can simply read it in `body`. `invalidate()` is
/// `ref.invalidate(provider)`; a `dependencies` closure is the provider's
/// `ref.watch(...)` calls: whenever anything observable it reads changes, the
/// resource reloads.
///
/// ```swift
/// // Dart:
/// // final hotelListProvider = FutureProvider<List<Hotel>>((ref) async {
/// //   ref.watch(authTokenProvider);
/// //   final result = await ref.watch(getHotelsUseCaseProvider)(const NoParams());
/// //   return result.fold((f) => throw f, (data) => data);
/// // });
/// extension AppContainer {
///     var hotelList: AsyncResource<[Hotel]> {
///         shared {
///             AsyncResource(dependencies: { [unowned self] in self.authToken }) { [unowned self] in
///                 try await self.getHotelsUseCase(NoParams()).get()
///             }
///         }
///     }
/// }
///
/// // View:
/// container.hotelList.state.when(data: { … }, error: { … }, loading: { … })
/// ```
@MainActor
@Observable
final class AsyncResource<Value> {
    private enum LoadKind { case initial, refresh, reload }

    @ObservationIgnored private let loader: () async throws -> Value
    @ObservationIgnored private let dependencies: (() -> AnyHashable)?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var lastDependency: AnyHashable?

    private var current: AsyncValue<Value> = .loading

    init(
        dependencies: (() -> AnyHashable)? = nil,
        loader: @escaping () async throws -> Value
    ) {
        self.dependencies = dependencies
        self.loader = loader
    }

    /// The current value. Reading it starts the first load.
    var state: AsyncValue<Value> {
        startIfNeeded()
        return current
    }

    /// The current value without starting a load (`ref.read` of a provider
    /// nobody is watching yet).
    var peek: AsyncValue<Value> { current }

    /// Starts the first load if nothing has started it yet.
    func startIfNeeded() {
        guard !started else { return }
        started = true
        Task { @MainActor [weak self] in self?.run(.initial) }
    }

    /// `ref.invalidate(provider)`: reload, keeping the previous value visible.
    func invalidate() {
        guard started else { return }
        run(.refresh)
    }

    /// `await ref.refresh(provider.future)`: reload and wait for the outcome.
    @discardableResult
    func refresh() async -> AsyncValue<Value> {
        run(.refresh)
        await task?.value
        return current
    }

    /// `await ref.read(provider.future)`: the value, loading it if needed.
    var future: Value {
        get async throws {
            if !started { run(.initial) }
            while current.isLoading {
                guard let task else { break }
                await task.value
            }
            if let error = current.error { throw error }
            guard let value = current.value else {
                throw StateError("AsyncResource finished without a value")
            }
            return value
        }
    }

    private func run(_ kind: LoadKind) {
        started = true
        task?.cancel()
        generation += 1
        let token = generation

        switch kind {
        case .initial: current = .loading
        case .refresh: current = current.markRefreshing()
        case .reload: current = current.markReloading()
        }

        if let dependencies { observe(dependencies) }

        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let value = try await self.loader()
                guard token == self.generation else { return }
                self.current = .data(value)
            } catch {
                guard token == self.generation, !(error is CancellationError) else { return }
                self.current = self.current.failed(error)
            }
        }
    }

    /// Re-runs the loader when the value the dependency closure returns
    /// changes — Riverpod's `ref.watch(p.select(...))`. A change to something
    /// the closure merely read (a token refresh when it returns the user id)
    /// only re-arms the observation.
    private func observe(_ dependencies: @escaping () -> AnyHashable) {
        let current = withObservationTracking {
            dependencies()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.dependencyMayHaveChanged() }
        }
        lastDependency = current
    }

    private func dependencyMayHaveChanged() {
        guard let dependencies else { return }
        let previous = lastDependency
        // Peek without arming, then either reload (which re-observes) or
        // re-arm the observation for the next change.
        if dependencies() != previous {
            run(.reload)
        } else {
            observe(dependencies)
        }
    }
}

/// Riverpod's `FutureProvider.family`: one `AsyncResource` per argument.
///
/// ```swift
/// // Dart: final visaCountryProvider = FutureProvider.family<VisaCountry, String>((ref, slug) async => …);
/// var visaCountry: AsyncResourceFamily<String, VisaCountry> {
///     shared { AsyncResourceFamily { [unowned self] slug in try await … } }
/// }
/// // View: container.visaCountry(slug).state.when(…)
/// ```
@MainActor
final class AsyncResourceFamily<Key: Hashable, Value> {
    private var resources: [Key: AsyncResource<Value>] = [:]
    private let dependencies: ((Key) -> AnyHashable)?
    private let loader: (Key) async throws -> Value

    init(
        dependencies: ((Key) -> AnyHashable)? = nil,
        loader: @escaping (Key) async throws -> Value
    ) {
        self.dependencies = dependencies
        self.loader = loader
    }

    func callAsFunction(_ key: Key) -> AsyncResource<Value> { self[key] }

    subscript(key: Key) -> AsyncResource<Value> {
        if let existing = resources[key] { return existing }
        let loader = self.loader
        var deps: (() -> AnyHashable)?
        if let dependencies { deps = { dependencies(key) } }
        let resource = AsyncResource<Value>(dependencies: deps) { try await loader(key) }
        resources[key] = resource
        return resource
    }

    /// `ref.invalidate(familyProvider)`: reload every argument already loaded.
    func invalidateAll() {
        resources.values.forEach { $0.invalidate() }
    }

    /// `ref.invalidate(familyProvider(key))`.
    func invalidate(_ key: Key) {
        resources[key]?.invalidate()
    }
}

/// Riverpod's `StateProvider<T>`: one observable value.
///
/// | Dart                                         | Swift                    |
/// |----------------------------------------------|--------------------------|
/// | `ref.watch(mainShellTabProvider)`            | `container.mainShellTab.value` |
/// | `ref.read(mainShellTabProvider.notifier).state = 2` | `container.mainShellTab.value = 2` |
@MainActor
@Observable
final class StateBox<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}

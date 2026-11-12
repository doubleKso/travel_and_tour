import Foundation

/// Riverpod's `AsyncValue<T>`: loading, data or error — keeping the previous
/// value and error while a reload is in flight, exactly as Riverpod does.
///
/// | Dart (Riverpod)                       | Swift                                |
/// |---------------------------------------|--------------------------------------|
/// | `async.when(data:, loading:, error:)` | `value.when(data:, error:, loading:)`|
/// | `async.valueOrNull`                   | `value.valueOrNull`                  |
/// | `async.isLoading / hasValue / hasError` | same                               |
/// | `async.isRefreshing / isReloading`    | same                                 |
/// | `async.error`                         | `value.error`                        |
/// | `AsyncValue.data(v)` / `.loading()` / `.error(e, st)` | `.data(v)` / `.loading` / `.error(e)` |
struct AsyncValue<Value> {
    /// The latest successful value, kept across reloads and errors.
    private(set) var value: Value?
    /// The latest error, kept across reloads.
    private(set) var error: Error?
    private(set) var isLoading: Bool
    /// True while loading because of `invalidate()`/`refresh()`.
    private(set) var isRefreshing: Bool = false
    /// True while loading because a watched dependency changed.
    private(set) var isReloading: Bool = false

    static var loading: AsyncValue { AsyncValue(value: nil, error: nil, isLoading: true) }

    static func data(_ value: Value) -> AsyncValue {
        AsyncValue(value: value, error: nil, isLoading: false)
    }

    static func error(_ error: Error) -> AsyncValue {
        AsyncValue(value: nil, error: error, isLoading: false)
    }

    var valueOrNull: Value? { value }
    var hasValue: Bool { value != nil }
    var hasError: Bool { error != nil }

    /// `requireValue` — crashes like Dart's when there is no value.
    var requireValue: Value {
        guard let value else { preconditionFailure("AsyncValue has no value (error: \(String(describing: error)))") }
        return value
    }

    /// Riverpod's `when` with its defaults: `skipLoadingOnRefresh: true`,
    /// `skipLoadingOnReload: false`, `skipError: false`.
    func when<R>(
        skipLoadingOnReload: Bool = false,
        skipLoadingOnRefresh: Bool = true,
        skipError: Bool = false,
        data: (Value) -> R,
        error onError: (Error) -> R,
        loading: () -> R
    ) -> R {
        if isLoading {
            let skip: Bool
            if isRefreshing {
                skip = skipLoadingOnRefresh
            } else if isReloading {
                skip = skipLoadingOnReload
            } else {
                skip = false
            }
            if !skip || (value == nil && error == nil) { return loading() }
        }
        if let error, value == nil || !skipError { return onError(error) }
        if let value { return data(value) }
        return loading()
    }

    /// Riverpod's `maybeWhen`.
    func maybeWhen<R>(
        data: ((Value) -> R)? = nil,
        error onError: ((Error) -> R)? = nil,
        loading: (() -> R)? = nil,
        orElse: () -> R
    ) -> R {
        when(
            data: { data?($0) ?? orElse() },
            error: { onError?($0) ?? orElse() },
            loading: { loading?() ?? orElse() }
        )
    }

    // MARK: - Transitions used by AsyncResource

    /// Loading again because of `invalidate()`, keeping value and error.
    func markRefreshing() -> AsyncValue {
        var copy = self
        copy.isLoading = true
        copy.isRefreshing = value != nil || error != nil
        copy.isReloading = false
        return copy
    }

    /// Loading again because a dependency changed, keeping value and error.
    func markReloading() -> AsyncValue {
        var copy = self
        copy.isLoading = true
        copy.isReloading = value != nil || error != nil
        copy.isRefreshing = false
        return copy
    }

    /// Failed, keeping the previous value (`AsyncError.copyWithPrevious`).
    func failed(_ error: Error) -> AsyncValue {
        AsyncValue(value: value, error: error, isLoading: false)
    }
}

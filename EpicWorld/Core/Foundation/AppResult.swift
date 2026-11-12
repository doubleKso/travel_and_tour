import Foundation

/// The single value every repository and use case hands back: either data or
/// an `AppFailure` — the Swift side of `app_core`'s `Result<T>`.
///
/// It is Swift's own `Result`, so `switch`, `map`, `flatMap` and `mapError`
/// all work. The extensions below add the Dart API names so ported code reads
/// the same:
///
/// | Dart                          | Swift                              |
/// |-------------------------------|------------------------------------|
/// | `Result.success(v)`           | `.success(v)`                      |
/// | `Result.failure(f)`           | `.failure(f)`                      |
/// | `Result<void>` / `success(null)` | `AppResult<Void>` / `.success(())` |
/// | `result.fold((f) => …, (d) => …)` | `result.fold({ f in … }, { d in … })` |
/// | `result.isSuccess / isFailure`| same                               |
/// | `result.dataOrNull`           | same                               |
/// | `result.failureOrNull`        | same                               |
/// | `result.map(t)`               | `result.map(t)`                    |
/// | `result.flatMap(t)`           | `result.flatMap(t)`                |
/// | `result.mapFailure(t)`        | `result.mapError(t)`               |
/// | `await result.asyncMap(t)`    | `await result.asyncMap(t)`         |
/// | `await result.asyncFlatMap(t)`| `await result.asyncFlatMap(t)`     |
typealias AppResult<T> = Result<T, AppFailure>

extension Result where Failure == AppFailure {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isFailure: Bool { !isSuccess }

    /// The data when this is a success, otherwise nil.
    var dataOrNull: Success? {
        if case .success(let value) = self { return value }
        return nil
    }

    /// The failure when this is a failure, otherwise nil.
    var failureOrNull: AppFailure? {
        if case .failure(let failure) = self { return failure }
        return nil
    }

    /// Exhaustive fold over the two outcomes.
    func fold<R>(
        _ onFailure: (AppFailure) throws -> R,
        _ onSuccess: (Success) throws -> R
    ) rethrows -> R {
        switch self {
        case .failure(let failure): return try onFailure(failure)
        case .success(let value): return try onSuccess(value)
        }
    }

    /// Async `map`.
    func asyncMap<R>(_ transform: (Success) async -> R) async -> AppResult<R> {
        switch self {
        case .failure(let failure): return .failure(failure)
        case .success(let value): return .success(await transform(value))
        }
    }

    /// Async `flatMap`.
    func asyncFlatMap<R>(_ transform: (Success) async -> AppResult<R>) async -> AppResult<R> {
        switch self {
        case .failure(let failure): return .failure(failure)
        case .success(let value): return await transform(value)
        }
    }
}

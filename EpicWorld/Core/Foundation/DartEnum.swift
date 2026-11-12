import Foundation

/// Dart's enum API for ported enums: `.name`, `.index`, `E.values`,
/// `E.values.byName(s)`.
///
/// ```swift
/// enum TravelMode: String, CaseIterable, DartEnum { case flight, bus }
/// TravelMode.flight.name           // "flight"   (Dart: TravelMode.flight.name)
/// TravelMode.values                // [.flight, .bus]
/// TravelMode.byName("bus")         // .bus       (Dart: TravelMode.values.byName('bus'))
/// TravelMode.tryByName("train")    // nil
/// ```
/// The raw value is always the Dart case name. Keep any extra Dart enum
/// fields as computed properties.
protocol DartEnum: RawRepresentable, CaseIterable, Hashable where RawValue == String {}

extension DartEnum {
    /// Dart `enum.name`.
    var name: String { rawValue }

    /// Dart `Enum.values`.
    static var values: [Self] { Array(allCases) }

    /// Dart `enum.index`.
    var index: Int { Array(Self.allCases).firstIndex(of: self) ?? 0 }

    /// Dart `values.byName(name)` — like Dart, a missing name is a programming error.
    static func byName(_ name: String) -> Self {
        guard let value = Self(rawValue: name) else {
            preconditionFailure("No enum value with name \"\(name)\" in \(Self.self)")
        }
        return value
    }

    /// The case named `name`, or nil (Dart `values.asNameMap()[name]`).
    static func tryByName(_ name: String) -> Self? { Self(rawValue: name) }
}

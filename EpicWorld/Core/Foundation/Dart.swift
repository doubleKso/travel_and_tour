import Foundation

/// A decoded JSON object — Dart's `Map<String, dynamic>`.
typealias JSON = [String: Any]

/// Dart's dynamic-typing rules for values decoded from JSON.
///
/// Callable and REST payloads arrive as `Any` (NSNumber, NSString, NSNull,
/// NSArray, NSDictionary). These helpers reproduce what the Dart parsers do
/// with them, so a ported `fromJson` makes the same decisions:
///
/// | Dart                                   | Swift                          |
/// |----------------------------------------|--------------------------------|
/// | `json['id']?.toString()`               | `Dart.str(json["id"])`         |
/// | `'${json['id']}'`                      | `Dart.interpolate(json["id"])` |
/// | `(json['price'] as num?)?.toDouble()`  | `Dart.double(json["price"])`   |
/// | `(json['stops'] as num?)?.toInt()`     | `Dart.int(json["stops"])`      |
/// | `json['ok'] as bool?` / `== true`      | `Dart.bool(json["ok"])`        |
/// | `json['x'] is num` / `is int` / `is bool` / `is String` | `Dart.isNum` / `isInt` / `isBool` / `isString` |
/// | `json['m'] is Map ? Map<String, dynamic>.from(…) : null` | `Dart.map(json["m"])` |
/// | `json['l'] as List? ?? []`             | `Dart.list(json["l"]) ?? []`   |
/// | `double.tryParse(s)` / `int.tryParse(s)` | `Dart.parseDouble(s)` / `Dart.parseInt(s)` |
///
/// JSON `null` arrives as `NSNull`; every helper treats it as Dart `null`.
/// Where a Dart `as` cast would throw on a wrong type these return nil — the
/// ported code then takes its `?? fallback` branch, which is what every
/// parser in this app does after a failed cast anyway.
enum Dart {
    /// Unwraps `NSNull` and nested optionals to a plain value or nil.
    static func unwrap(_ value: Any?) -> Any? {
        guard let value else { return nil }
        if value is NSNull { return nil }
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let child = mirror.children.first else { return nil }
            return unwrap(child.value)
        }
        return value
    }

    static func isNull(_ value: Any?) -> Bool { unwrap(value) == nil }

    /// Dart `value is bool`. NSNumber-backed booleans are told apart from
    /// numbers by their CoreFoundation type, as JSON decoding produces both.
    static func isBool(_ value: Any?) -> Bool {
        guard let value = unwrap(value) else { return false }
        return CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID()
    }

    /// Dart `value is num`.
    static func isNum(_ value: Any?) -> Bool {
        guard let value = unwrap(value), !isBool(value) else { return false }
        return value is NSNumber
    }

    /// Dart `value is int`: a number decoded without a fractional part.
    static func isInt(_ value: Any?) -> Bool {
        guard isNum(value), let number = unwrap(value) as? NSNumber else { return false }
        return !CFNumberIsFloatType(number as CFNumber)
    }

    /// Dart `value is double`.
    static func isDouble(_ value: Any?) -> Bool {
        guard isNum(value), let number = unwrap(value) as? NSNumber else { return false }
        return CFNumberIsFloatType(number as CFNumber)
    }

    static func isString(_ value: Any?) -> Bool { unwrap(value) is String }
    static func isMap(_ value: Any?) -> Bool { map(value) != nil }
    static func isList(_ value: Any?) -> Bool { list(value) != nil }

    /// Dart `value?.toString()`.
    static func str(_ value: Any?) -> String? {
        guard let value = unwrap(value) else { return nil }
        return describe(value)
    }

    /// Dart string interpolation `'$value'` — `"null"` for null.
    static func interpolate(_ value: Any?) -> String {
        str(value) ?? "null"
    }

    /// Dart `(value as num?)?.toDouble()`.
    static func double(_ value: Any?) -> Swift.Double? {
        guard isNum(value), let number = unwrap(value) as? NSNumber else { return nil }
        return number.doubleValue
    }

    /// Dart `(value as num?)?.toInt()` — truncates toward zero like Dart.
    static func int(_ value: Any?) -> Swift.Int? {
        guard isNum(value), let number = unwrap(value) as? NSNumber else { return nil }
        let double = number.doubleValue
        guard double.isFinite else { return nil }
        return isInt(value) ? number.intValue : Swift.Int(double.rounded(.towardZero))
    }

    /// Dart `value as bool?` (nil when the value is not a bool).
    static func bool(_ value: Any?) -> Swift.Bool? {
        guard isBool(value), let number = unwrap(value) as? NSNumber else { return nil }
        return number.boolValue
    }

    /// Dart `value is Map ? Map<String, dynamic>.from(value) : null`.
    static func map(_ value: Any?) -> JSON? {
        guard let value = unwrap(value) else { return nil }
        if let json = value as? JSON { return json }
        if let dict = value as? [AnyHashable: Any] {
            var out = JSON(minimumCapacity: dict.count)
            for (key, element) in dict { out[describe(key.base)] = element }
            return out
        }
        return nil
    }

    /// Dart `value is List ? value : null`.
    static func list(_ value: Any?) -> [Any]? {
        guard let value = unwrap(value) else { return nil }
        if let array = value as? [Any] { return array }
        if let array = value as? NSArray { return array.map { $0 } }
        return nil
    }

    /// The maps inside a list, skipping anything else — Dart's
    /// `list.whereType<Map>().map((e) => Map<String, dynamic>.from(e))`.
    static func maps(_ value: Any?) -> [JSON] {
        (list(value) ?? []).compactMap { map($0) }
    }

    /// Dart `double.tryParse(source)` (accepts surrounding whitespace,
    /// exponents, `Infinity`, `NaN`).
    static func parseDouble(_ source: String) -> Swift.Double? {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        switch text {
        case "Infinity", "+Infinity": return .infinity
        case "-Infinity": return -.infinity
        case "NaN": return .nan
        default: break
        }
        guard text.range(of: #"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$"#, options: .regularExpression) != nil else {
            return nil
        }
        return Swift.Double(text)
    }

    /// Dart `int.tryParse(source)` (decimal, optional sign, `0x` hex).
    static func parseInt(_ source: String) -> Swift.Int? {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        var body = Substring(text)
        var sign = 1
        if body.first == "+" || body.first == "-" {
            sign = body.first == "-" ? -1 : 1
            body = body.dropFirst()
        }
        if body.lowercased().hasPrefix("0x") {
            guard let value = Swift.Int(body.dropFirst(2), radix: 16) else { return nil }
            return sign * value
        }
        guard body.allSatisfy(\.isNumber), let value = Swift.Int(body) else { return nil }
        return sign * value
    }

    /// Dart's `toString()` of a decoded JSON value.
    static func describe(_ value: Any) -> String {
        if let string = value as? String { return string }
        if isBool(value), let number = value as? NSNumber { return number.boolValue ? "true" : "false" }
        if let number = value as? NSNumber {
            if CFNumberIsFloatType(number as CFNumber) {
                let double = number.doubleValue
                if double.isNaN { return "NaN" }
                if double.isInfinite { return double < 0 ? "-Infinity" : "Infinity" }
                return "\(double)"
            }
            return number.stringValue
        }
        if let array = list(value) {
            return "[" + array.map { unwrap($0).map(describe) ?? "null" }.joined(separator: ", ") + "]"
        }
        if let dict = value as? [AnyHashable: Any] {
            let body = dict.map { key, element in
                "\(describe(key.base)): \(unwrap(element).map(describe) ?? "null")"
            }
            return "{" + body.joined(separator: ", ") + "}"
        }
        return String(describing: value)
    }
}

extension Dictionary where Key == String, Value == Any {
    /// JSON encoding of a payload (Dart `jsonEncode`).
    func jsonString() -> String {
        guard JSONSerialization.isValidJSONObject(self),
              let data = try? JSONSerialization.data(withJSONObject: self),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}

/// Dart `jsonDecode(source)` — throws `FormatException` on malformed input.
func jsonDecode(_ source: String) throws -> Any {
    guard let data = source.data(using: .utf8) else { throw FormatException("Invalid UTF-8") }
    do {
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    } catch {
        throw FormatException(error.localizedDescription)
    }
}

/// Dart `jsonEncode(value)`.
func jsonEncode(_ value: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
          let text = String(data: data, encoding: .utf8) else { return "null" }
    return text
}

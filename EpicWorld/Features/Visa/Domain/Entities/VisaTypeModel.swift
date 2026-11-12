// Port of lib/features/visa/domain/entities/visa_type_model.dart

import Foundation

/// A visa the Epic World visa desk handles for one country, returned by
/// `dcExec:GetVisaTypes`.
struct VisaTypeModel {
    let code: String
    let title: String
    let description: String
    let imageUrl: String
    let documents: [String]

    init(
        code: String,
        title: String,
        description: String,
        imageUrl: String,
        documents: [String]
    ) {
        self.code = code
        self.title = title
        self.description = description
        self.imageUrl = imageUrl
        self.documents = documents
    }

    static func fromJson(_ json: JSON) -> VisaTypeModel {
        VisaTypeModel(
            code: Dart.str(json["code"]) ?? "",
            title: Dart.str(json["title"]) ?? "",
            description: Dart.str(json["description"]) ?? "",
            imageUrl: Dart.str(json["imageUrl"]) ?? "",
            documents: parseVisaDocuments(json["documents"])
        )
    }

    /// Card title — falls back to the code when the catalogue has no title.
    var headline: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty
            ? trimmedTitle
            : code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}

/// `documents` comes back as a single string whose shape depends on how the
/// admin entered it: a JSON array, one document per line, or a separated list.
/// Every form collapses to the same checklist here so the UI never has to care.
func parseVisaDocuments(_ raw: Any?) -> [String] {
    guard let raw = Dart.unwrap(raw) else { return [] }
    if let list = Dart.list(raw) {
        return cleaned(list.map { Dart.str($0) ?? "" })
    }

    let text = Dart.describe(raw).trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty { return [] }

    if text.hasPrefix("[") {
        // A FormatException means it is not JSON after all — fall through to
        // the separator split below.
        if let decoded = try? jsonDecode(text), let list = Dart.list(decoded) {
            return cleaned(list.map { Dart.str($0) ?? "" })
        }
    }

    // First separator that actually splits the value wins. Comma is last because
    // document names may legitimately contain one.
    for separator in ["\n", "|", ";", ","] {
        // Literal (code-unit) search, like Dart's: "\n" is found inside "\r\n".
        if text.range(of: separator, options: .literal) == nil { continue }
        let parts = cleaned(text.components(separatedBy: separator))
        if parts.count > 1 { return parts }
    }
    return cleaned([text])
}

/// Trims list markers and whitespace, and drops anything left empty.
private func cleaned(_ values: [String]) -> [String] {
    values
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"^[-*•]\s*"#, with: "", options: .regularExpression)
        }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

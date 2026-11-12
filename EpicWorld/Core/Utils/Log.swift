import Foundation
import os

/// Debug-only console logging — the port of lib/core/utils/super_print.dart.
/// Compiles to nothing useful in release builds.
func superPrint(
    _ content: Any,
    title: String = "Super Print",
    isApi: Bool = false,
    file: String = #fileID,
    line: Int = #line
) {
    #if DEBUG
    let now = DateTime.now()
    let stamp = "\(now.hour) : \(now.minute) : \(now.second).\(now.millisecond)"
    print("")
    print("- \(title) - \(file):\(line)")
    print("____________________________")
    print("\(content)")
    print(" _________________________________________________________________  \(stamp)")
    #endif
}

/// Prints each element's `toJson()` map (Dart `mapPrint`).
func mapPrint(_ list: [JSON], title: String? = nil) {
    #if DEBUG
    for element in list {
        print("---------------------(\(title ?? ""))---------------------")
        element.forEach { print(" \($0.key): \($0.value) ") }
    }
    #endif
}

import UIKit

/// Presents the system share sheet from the top-most view controller — what
/// the Flutter app gets from `printing`'s share/save sheet and `share_plus`.
@MainActor
enum SharePresenter {
    static func share(_ items: [Any]) {
        guard let presenter = UIApplication.shared.topViewController else { return }
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad needs an anchor for the popover.
        sheet.popoverPresentationController?.sourceView = presenter.view
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0
        )
        presenter.present(sheet, animated: true)
    }

    /// Writes `bytes` to a temporary `filename` and shares the file — the
    /// native branch of `savePdfToDevice` (lib/core/utils/pdf_saver.dart).
    @discardableResult
    static func sharePdf(_ bytes: Data, filename: String) -> Bool {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try bytes.write(to: url, options: .atomic)
        } catch {
            return false
        }
        share([url])
        return true
    }
}

extension UIApplication {
    /// The view controller currently on top of the key window.
    var topViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

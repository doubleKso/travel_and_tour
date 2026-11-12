import SwiftUI
import UIKit

/// Flutter's `BoxFit`.
enum BoxFit {
    case cover, contain, fill, fitWidth, fitHeight, none
}

/// A bundled image by its Flutter asset path — `Image.asset(path)` and
/// `SvgPicture.asset(path)` in one.
///
/// Rasters load from the `assets/` folder reference (webp/avif included);
/// SVGs load from the asset catalog, where `sync_resources.sh` stored them as
/// vector image sets named by file stem.
///
/// ```swift
/// AppImage(AppAssets.brandLogo, height: 36)
/// AppImage(AppAssets.amenityWifi, width: 20, height: 20, tint: AppColors.primary)
/// AppImage(AppAssets.header, fit: .cover)
/// ```
struct AppImage: View {
    let path: String
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var fit: BoxFit = .contain
    /// SvgPicture's `colorFilter: ColorFilter.mode(c, BlendMode.srcIn)` / Image's `color:`.
    var tint: Color? = nil

    init(_ path: String, width: CGFloat? = nil, height: CGFloat? = nil, fit: BoxFit = .contain, tint: Color? = nil) {
        self.path = path
        self.width = width
        self.height = height
        self.fit = fit
        self.tint = tint
    }

    var body: some View {
        if let image = Self.image(for: path) {
            fitted(tint == nil ? image : image.renderingMode(.template))
                .foregroundStyle(tint ?? Colors.white)
        } else {
            Color.clear.frame(width: width, height: height)
        }
    }

    @ViewBuilder
    private func fitted(_ image: Image) -> some View {
        switch fit {
        case .cover:
            image.resizable().scaledToFill().frame(width: width, height: height).clipped()
        case .fill:
            image.resizable().frame(width: width, height: height)
        case .none:
            image.frame(width: width, height: height)
        case .contain, .fitWidth, .fitHeight:
            image.resizable().scaledToFit().frame(width: width, height: height)
        }
    }

    // MARK: - Loading

    private static let cache = NSCache<NSString, UIImage>()

    /// The SwiftUI image for a Flutter asset path, or nil when missing.
    static func image(for path: String) -> Image? {
        if path.lowercased().hasSuffix(".svg") {
            let stem = (path as NSString).lastPathComponent.replacingOccurrences(of: ".svg", with: "", options: [.caseInsensitive, .anchored, .backwards])
            return UIImage(named: stem).map { _ in Image(stem) }
        }
        return uiImage(for: path).map { Image(uiImage: $0) }
    }

    /// The decoded raster for a Flutter asset path (`assets/images/b4.jpg`).
    static func uiImage(for path: String) -> UIImage? {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let url = Bundle.main.bundleURL.appendingPathComponent(path)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}

/// `CachedNetworkImage` / `Image.network`: a remote image with a memory and
/// URL cache, a placeholder while loading and an error view on failure.
///
/// ```swift
/// NetworkImage(url, fit: .cover) {
///     Color(AppColors.primarySurface)            // placeholder
/// } error: {
///     Icon(Icons.broken_image_outlined)
/// }
/// ```
struct NetworkImage<Placeholder: View, ErrorView: View>: View {
    let url: String
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var fit: BoxFit = .cover
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var errorView: () -> ErrorView

    @State private var loaded: UIImage?
    @State private var failed = false

    init(
        _ url: String,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        fit: BoxFit = .cover,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder error: @escaping () -> ErrorView
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.fit = fit
        self.placeholder = placeholder
        self.errorView = error
    }

    var body: some View {
        Group {
            if let image = loaded ?? ImageLoader.cached(url) {
                switch fit {
                case .cover:
                    Image(uiImage: image).resizable().scaledToFill().frame(width: width, height: height).clipped()
                case .fill:
                    Image(uiImage: image).resizable().frame(width: width, height: height)
                default:
                    Image(uiImage: image).resizable().scaledToFit().frame(width: width, height: height)
                }
            } else if failed {
                errorView().frame(width: width, height: height)
            } else {
                placeholder().frame(width: width, height: height)
            }
        }
        .task(id: url) {
            failed = false
            if let image = ImageLoader.cached(url) { loaded = image; return }
            loaded = nil
            do {
                loaded = try await ImageLoader.load(url)
            } catch {
                failed = true
            }
        }
    }
}

extension NetworkImage where Placeholder == Color, ErrorView == Color {
    init(_ url: String, width: CGFloat? = nil, height: CGFloat? = nil, fit: BoxFit = .cover) {
        self.init(url, width: width, height: height, fit: fit, placeholder: { Color.clear }, error: { Color.clear })
    }
}

/// Shared remote-image loader behind `NetworkImage`.
enum ImageLoader {
    private static let memory = NSCache<NSString, UIImage>()
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 256 << 20)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()

    static func cached(_ url: String) -> UIImage? {
        memory.object(forKey: url as NSString)
    }

    static func load(_ url: String) async throws -> UIImage {
        if let hit = cached(url) { return hit }
        guard let endpoint = URL(string: url) else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: endpoint)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
        memory.setObject(image, forKey: url as NSString)
        return image
    }
}

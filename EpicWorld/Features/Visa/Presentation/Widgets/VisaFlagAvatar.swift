// Port of lib/features/visa/presentation/widgets/visa_flag_avatar.dart

import SwiftUI

/// Circular country flag with a ring, used by every visa surface.
///
/// Falls back to the shared flag CDN when the catalogue has no `flagUrl`, and
/// to the ISO code itself when even that fails to load.
struct VisaFlagAvatar: View {
    let flagUrl: String
    let flagCode: String
    let size: CGFloat

    init(flagUrl: String, flagCode: String, size: CGFloat = 50) {
        self.flagUrl = flagUrl
        self.flagCode = flagCode
        self.size = size
    }

    private var url: String {
        !flagUrl.isEmpty
            ? flagUrl
            : "https://flagcdn.com/w160/\(flagCode.lowercased()).png"
    }

    var body: some View {
        // 2pt padding plus the 1pt border, which Container also insets its
        // child by.
        let inner = max(0, size - 6)
        NetworkImage(url, width: inner, height: inner, fit: .cover) {
            AppColors.primarySurface
        } error: {
            ZStack {
                AppColors.primarySurface
                Text(flagCode.uppercased())
                    .textStyle(AppTypography.body(size < 44 ? 8 : 9, weight: .w700, color: AppColors.primary))
            }
        }
        .clipShape(Circle())
        .padding(3)
        .frame(width: size, height: size)
        .boxDecoration(
            color: AppColors.surface,
            circle: true,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 9, offset: Offset(0, 4))]
        )
    }
}

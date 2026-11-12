// Port of lib/features/profile/presentation/pages/language_page.dart
import SwiftUI

/// LANGUAGE — switch the app between English and Myanmar, with country flags.
struct LanguagePage: View {
    init() {}

    // Real flag images (the OS may not render flag emoji, so use flagcdn PNGs).
    private static let options: [(code: String, name: String, native: String, flag: String)] = [
        (
            code: "en",
            name: "English",
            native: "English",
            flag: "https://flagcdn.com/w80/gb.png"
        ),
        (
            code: "my",
            name: "Myanmar",
            native: "မြန်မာဘာသာ",
            flag: "https://flagcdn.com/w80/mm.png"
        ),
    ]

    var body: some View {
        // `context.locale.languageCode` — observed, so the page re-renders
        // when the language changes.
        let current = LocaleStore.shared.code

        Scaffold(
            backgroundColor: AppColors.surface,
            appBar: {
                AppBar(
                    title: LocaleKeys.profile_language.tr(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    centerTitle: true
                )
            }
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(LocaleKeys.profile_choose_preferred_language.tr())
                        .textStyle(AppTypography.body(13.5, color: AppColors.textSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VGap(16)
                    ForEach(LanguagePage.options, id: \.code) { o in
                        LanguageTile(
                            flag: o.flag,
                            name: o.name,
                            native: o.native,
                            selected: current == o.code,
                            onTap: { L10n.change(o.code) }
                        )
                        VGap(12)
                    }
                }
                .padding(20, 24, 20, 24)
            }
        }
    }
}

private struct LanguageTile: View {
    let flag: String
    let name: String
    let native: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        // AnimatedContainer adds the border width to its padding, so the
        // content shifts by the 0.6pt the selected border is thicker.
        let borderWidth: CGFloat = selected ? 1.6 : 1
        HStack(spacing: 0) {
            // Circular country flag.
            NetworkImage(flag, width: 42, height: 42, fit: .cover) {
                AppColors.primarySurface
            } error: {
                Icon(Icons.flag_rounded, color: AppColors.textTertiary)
            }
            .clipShape(Circle())
            // The 1pt border insets the clipped flag inside the 44pt circle.
            .padding(1)
            .frame(width: 44, height: 44)
            .boxDecoration(
                circle: true,
                borderColor: AppColors.border,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
            )
            HGap(14)
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .textStyle(AppTypography.heading(15.5))
                VGap(2)
                Text(native)
                    .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : AppColors.textTertiary
            )
        }
        .padding(horizontal: 16 + borderWidth, vertical: 14 + borderWidth)
        .boxDecoration(
            color: selected ? AppColors.primarySurface : AppColors.surface,
            radius: 16,
            borderColor: selected ? AppColors.primary : AppColors.border,
            borderWidth: borderWidth,
            shadows: selected
                ? []
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 4))]
        )
        .animation(.linear(duration: 0.18), value: selected)
        // GestureDetector(behavior: HitTestBehavior.opaque).
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// Port of lib/features/visa/presentation/pages/visa_country_page.dart

import SwiftUI

/// VISA COUNTRY — one destination's profile and the visas we handle for it.
///
/// Opened from the Global Visa grid on the Visa screen. Two calls back it:
/// `GetVisaCountryBySlug` for the profile (artwork + intro), then
/// `GetVisaTypes` for the visa list, keyed by the ID the first call returns.
///
/// `countryName`, `flagUrl` and `flagCode` are the values the grid already
/// had, so the header can name the country while the profile is still in
/// flight (and on a cold deep link they are simply absent).
struct VisaCountryPage: View {
    let slug: String
    let countryName: String?
    let flagUrl: String?
    let flagCode: String?

    @Environment(AppContainer.self) private var container

    init(
        slug: String,
        countryName: String? = nil,
        flagUrl: String? = nil,
        flagCode: String? = nil
    ) {
        self.slug = slug
        self.countryName = countryName
        self.flagUrl = flagUrl
        self.flagCode = flagCode
    }

    /// The count chip's label: `typeCount == 1 ? '1 visa type' : '$typeCount visa types'`
    /// (inline in the Dart `_CountryIntro`, lifted out so it can be unit tested).
    static func typeCountLabel(_ typeCount: Int) -> String {
        typeCount == 1 ? "1 visa type" : "\(typeCount) visa types"
    }

    var body: some View {
        let country = container.visaCountryDetail(slug).state

        Scaffold(backgroundColor: AppColors.background) {
            GeometryReader { proxy in
                let topPad = proxy.safeAreaInsets.top
                // MediaQuery.sizeOf(context): the whole window.
                let mediaWidth = proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing
                let mediaHeight = proxy.size.height + proxy.safeAreaInsets.bottom

                ScrollView {
                    country.when(
                        data: { (detail: VisaCountryDetail?) -> AnyView in
                            if let detail {
                                return AnyView(VisaCountryBody(country: detail, topPad: topPad))
                            }
                            return AnyView(shell(
                                VisaCountryMessage(
                                    icon: Icons.travel_explore_rounded,
                                    title: "Destination not available",
                                    message: "This country is no longer part of our visa catalogue. Please pick another destination."
                                ),
                                topPad: topPad,
                                minHeight: mediaHeight * 0.8
                            ))
                        },
                        error: { _ in
                            AnyView(shell(
                                VisaCountryMessage(
                                    icon: Icons.cloud_off_rounded,
                                    title: "Could not load this destination",
                                    message: "Check your connection and try again.",
                                    onRetry: { container.visaCountryDetail.invalidate(slug) }
                                ),
                                topPad: topPad,
                                minHeight: mediaHeight * 0.8
                            ))
                        },
                        loading: {
                            AnyView(shell(
                                VisaCountryLoading(),
                                topPad: topPad,
                                minHeight: mediaHeight * 0.8
                            ))
                        }
                    )
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
                .environment(\.visaMediaWidth, mediaWidth)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    /// Loading / error / empty states still show a back button and whatever the
    /// grid already knew about the country, so the screen never looks blank.
    private func shell<Child: View>(_ child: Child, topPad: CGFloat, minHeight: CGFloat) -> some View {
        CountryShell(
            title: countryName,
            flagUrl: flagUrl,
            flagCode: flagCode,
            topPad: topPad,
            minHeight: minHeight
        ) {
            child
        }
    }
}

/// Frame used by the non-data states: the soft header background, a back
/// button, the country's name if we already have it, and `child` underneath.
private struct CountryShell<Child: View>: View {
    let title: String?
    let flagUrl: String?
    let flagCode: String?
    let topPad: CGFloat
    /// `MediaQuery.sizeOf(context).height * 0.8`.
    let minHeight: CGFloat
    let child: Child

    init(
        title: String?,
        flagUrl: String?,
        flagCode: String?,
        topPad: CGFloat,
        minHeight: CGFloat,
        @ViewBuilder child: () -> Child
    ) {
        self.title = title
        self.flagUrl = flagUrl
        self.flagCode = flagCode
        self.topPad = topPad
        self.minHeight = minHeight
        self.child = child()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButtonView()
            if let title, !title.isEmpty {
                VGap(AppSpacing.xl)
                HStack(spacing: 0) {
                    FlagPlate(url: flagUrl ?? "", code: flagCode ?? "")
                    HGap(AppSpacing.md)
                    Text(title)
                        .textStyle(AppTypography.heading(26, color: AppColors.primaryDark, height: 1.15))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            VGap(AppSpacing.section)
            child
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.screenH, topPad + 8, AppSpacing.screenH, AppSpacing.section)
        .frame(minHeight: minHeight, alignment: .top)
        .background(headerGradient)
    }
}

private let headerGradient = LinearGradient(
    stops: [
        .init(color: Color(0xFFFFFFFF), location: 0),
        .init(color: Color(0xFFF1F7EC), location: 0.55),
        .init(color: Color(0xFFFDF7EA), location: 1),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// ---------------------------------------------------------------------------
// Body — header, visa types, department contact
// ---------------------------------------------------------------------------

private struct VisaCountryBody: View {
    let country: VisaCountryDetail
    let topPad: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Country profile — globe, flag, emblem, intro.
            CountryHeader(country: country, topPad: topPad)
            VGap(AppSpacing.section)

            // 2. What we handle — the published visa types.
            Band { VisaTypesSection(countryId: country.id) }
            VGap(AppSpacing.section)

            // 3. Talk to the visa desk.
            Band {
                DepartmentsSection(
                    title: LocaleKeys.visa_need_help_with_visa.tr(),
                    subtitle: "Send us your documents and our visa specialists will take it from there — checking, filling, and following up until the visa is issued.",
                    include: [.visa]
                )
            }
            VGap(AppSpacing.section)
        }
    }
}

/// Centres a section and caps it on desktop.
private struct Band<Content: View>: View {
    let child: Content

    init(@ViewBuilder child: () -> Content) {
        self.child = child()
    }

    var body: some View {
        child
            .padding(.horizontal, AppSpacing.screenH)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity)
    }
}

// ---------------------------------------------------------------------------
// 1. Country header
// ---------------------------------------------------------------------------

private struct CountryHeader: View {
    let country: VisaCountryDetail
    let topPad: CGFloat

    @Environment(\.visaMediaWidth) var mediaWidth

    var body: some View {
        let wide = mediaWidth >= 860

        VStack(alignment: .leading, spacing: 0) {
            BackButtonView()
            VGap(AppSpacing.lg)
            if wide {
                HStack(alignment: .center, spacing: 0) {
                    CountryGlobe(url: country.globeUrl)
                        .frame(maxWidth: .infinity)
                    HGap(AppSpacing.section)
                    CountryIntro(country: country)
                        .frame(maxWidth: .infinity)
                }
            } else {
                CountryGlobe(url: country.globeUrl)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                VGap(AppSpacing.lg)
                CountryIntro(country: country)
            }
        }
        .frame(maxWidth: 1180, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.screenH, topPad + 8, AppSpacing.screenH, AppSpacing.xl)
        .background(headerGradient)
    }
}

/// The greyscale globe with the country highlighted. Falls back to a plain
/// globe mark when the catalogue has no artwork yet.
private struct CountryGlobe: View {
    let url: String

    var body: some View {
        VisaReveal {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if url.isEmpty {
                        globeMark
                    } else {
                        NetworkImage(url, fit: .contain) {
                            ProgressView()
                                .tint(AppColors.primary)
                                .frame(width: 26, height: 26)
                        } error: {
                            globeMark
                        }
                    }
                }
        }
    }

    private var globeMark: some View {
        Icon(Icons.public_rounded, size: 120, color: AppColors.primary.withValues(alpha: 0.18))
    }
}

private struct CountryIntro: View {
    let country: VisaCountryDetail

    @Environment(AppContainer.self) var container
    @Environment(\.visaMediaWidth) var mediaWidth

    var body: some View {
        let wide = mediaWidth >= 860
        let types = container.visaTypeList(country.id).state
        let typeCount = types.valueOrNull?.count

        VStack(alignment: .leading, spacing: 0) {
            VisaReveal(index: 1) {
                HStack(spacing: 0) {
                    FlagPlate(url: country.flagUrl, code: country.flagCode)
                    if !country.emblemUrl.isEmpty {
                        HGap(AppSpacing.lg)
                        EmblemPlate(url: country.emblemUrl)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VGap(AppSpacing.lg)
            VisaReveal(index: 2) {
                Text("VISA SERVICES")
                    .textStyle(AppTypography.body(12, weight: .w800, color: AppColors.accent, letterSpacing: 0.9))
            }
            VGap(6)
            VisaReveal(index: 3) {
                Text(country.headline)
                    .textStyle(AppTypography.heading(wide ? 42 : 30, color: AppColors.primaryDark, height: 1.12))
            }
            if !country.intro.isEmpty {
                VGap(AppSpacing.lg)
                VisaReveal(index: 4) {
                    Text(country.intro)
                        .textStyle(AppTypography.body(wide ? 15 : 14, color: AppColors.textSecondary, height: 1.85))
                }
            }
            if let typeCount, typeCount > 0 {
                VGap(AppSpacing.lg)
                VisaReveal(index: 5) {
                    TypeCountChip(label: VisaCountryPage.typeCountLabel(typeCount))
                }
            }
        }
    }
}

/// Rectangular flag card — the flag reads better here than in the circular
/// avatar the grids use.
private struct FlagPlate: View {
    let url: String
    let code: String

    /// Dart `_url`.
    private var resolvedUrl: String {
        !url.isEmpty
            ? url
            : "https://flagcdn.com/w320/\(code.lowercased()).png"
    }

    var body: some View {
        // The 1pt border insets the photo, as Container does for a border.
        NetworkImage(resolvedUrl, width: 90, height: 60, fit: .cover) {
            AppColors.primarySurface
        } error: {
            ZStack {
                AppColors.primarySurface
                Text(code.uppercased())
                    .textStyle(AppTypography.body(12, weight: .w800, color: AppColors.primary))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(1)
        .frame(width: 92, height: 62)
        .boxDecoration(
            color: AppColors.surface,
            radius: 10,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: Offset(0, 6))]
        )
    }
}

private struct EmblemPlate: View {
    let url: String

    var body: some View {
        // Placeholder and error are `SizedBox.shrink()`.
        NetworkImage(url, width: 62, height: 62, fit: .contain)
            .frame(width: 62, height: 62)
    }
}

private struct TypeCountChip: View {
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            Icon(Icons.event_note_rounded, size: 17, color: AppColors.primary)
            HGap(8)
            Text(label)
                .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.primaryDark))
        }
        .padding(horizontal: 16, vertical: 11)
        .boxDecoration(
            color: AppColors.surface,
            radius: 30,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: Offset(0, 5))]
        )
    }
}

// ---------------------------------------------------------------------------
// 2. Visa types
// ---------------------------------------------------------------------------

private struct VisaTypesSection: View {
    let countryId: String

    @Environment(AppContainer.self) var container

    var body: some View {
        let types = container.visaTypeList(countryId).state

        VStack(spacing: 0) {
            VisaReveal {
                VisaSectionHeading(
                    eyebrow: "What we handle",
                    title: "Visa",
                    highlight: "types"
                )
            }
            VGap(AppSpacing.xl)
            types.when(
                data: { items in
                    items.isEmpty
                        ? AnyView(VisaCountryMessage(
                            icon: Icons.description_outlined,
                            title: "No visa types published yet",
                            message: "Our visa desk can still help — get in touch and we will guide you through the options."
                        ))
                        : AnyView(VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                                if i > 0 { VGap(AppSpacing.xl) }
                                VisaReveal(index: i, stagger: .milliseconds(60)) {
                                    VisaTypeCard(type: item)
                                }
                            }
                        })
                },
                error: { _ in
                    AnyView(VisaCountryMessage(
                        icon: Icons.cloud_off_rounded,
                        title: "Could not load visa types",
                        message: "Check your connection and try again.",
                        onRetry: { container.visaTypeList.invalidate(countryId) }
                    ))
                },
                loading: {
                    AnyView(
                        ProgressView()
                            .tint(AppColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.xl)
                    )
                }
            )
        }
    }
}

/// One visa type: photo, title, what it is for, and the document checklist.
/// Photo sits beside the copy on a wide screen and above it on a phone.
private struct VisaTypeCard: View {
    let type: VisaTypeModel

    @Environment(\.visaMediaWidth) var mediaWidth

    var body: some View {
        let wide = mediaWidth >= 860

        Group {
            if wide {
                // IntrinsicHeight + CrossAxisAlignment.stretch.
                HStack(spacing: 0) {
                    TypeImage(url: type.imageUrl)
                        .frame(width: 320)
                    TypeContent(type: type, wide: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(28)
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    TypeImage(url: type.imageUrl)
                        .frame(height: 180)
                    TypeContent(type: type, wide: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.lg)
                }
            }
        }
        .boxDecoration(
            color: AppColors.surface,
            radius: 24,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: Offset(0, 8))]
        )
    }
}

private struct TypeImage: View {
    let url: String

    var body: some View {
        if url.isEmpty {
            AppColors.primarySurface
        } else {
            Color.clear
                .overlay {
                    NetworkImage(url, fit: .cover) {
                        AppColors.primarySurface
                    } error: {
                        ZStack {
                            AppColors.primarySurface
                            Icon(Icons.image_not_supported_outlined, color: AppColors.primaryLight)
                        }
                    }
                }
                .clipped()
        }
    }
}

private struct TypeContent: View {
    let type: VisaTypeModel
    let wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(type.headline)
                .textStyle(AppTypography.heading(wide ? 24 : 20, color: AppColors.primaryDark, height: 1.2))
            if !type.description.isEmpty {
                VGap(AppSpacing.md)
                Text(type.description)
                    .textStyle(AppTypography.body(14, color: AppColors.textSecondary, height: 1.6))
            }
            if !type.documents.isEmpty {
                VGap(AppSpacing.lg)
                MaterialDivider(height: 1, thickness: 1, color: AppColors.divider)
                VGap(AppSpacing.lg)
                Text("REQUIRED DOCUMENTS")
                    .textStyle(AppTypography.body(11, weight: .w800, color: AppColors.textPrimary, letterSpacing: 0.9))
                VGap(AppSpacing.md)
                ForEach(Array(type.documents.enumerated()), id: \.offset) { _, document in
                    DocumentRow(label: document)
                }
            }
        }
    }
}

private struct DocumentRow: View {
    let label: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Icon(Icons.check_rounded, size: 13, color: AppColors.primary)
                .frame(width: 20, height: 20)
                .boxDecoration(color: AppColors.primarySurface, circle: true)
            HGap(10)
            Text(label)
                .textStyle(AppTypography.body(13.5, color: AppColors.textPrimary, height: 1.45))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 10)
    }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

/// Back button for the light header — the Visa screen's frosted one would
/// disappear against this background. (Dart `_BackButton`, suffixed so it
/// does not shadow the foundation's `BackButton`.)
private struct BackButtonView: View {
    @Environment(AppRouter.self) var router

    var body: some View {
        Button {
            Task { await router.maybePop() }
        } label: {
            Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary)
                .frame(width: 42, height: 42)
                .boxDecoration(color: AppColors.surface, circle: true, borderColor: AppColors.border)
        }
        .buttonStyle(.ink(radius: 21))
    }
}

private struct VisaCountryLoading: View {
    var body: some View {
        ProgressView()
            .tint(AppColors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.section)
    }
}

private struct VisaCountryMessage: View {
    let icon: IconData
    let title: String
    let message: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Icon(icon, size: 44, color: AppColors.textTertiary)
            VGap(AppSpacing.md)
            Text(title)
                .textStyle(AppTypography.heading(16, color: AppColors.textPrimary))
                .multilineTextAlignment(.center)
            VGap(6)
            Text(message)
                .textStyle(AppTypography.body(13, color: AppColors.textSecondary, height: 1.5))
                .multilineTextAlignment(.center)
            if let onRetry {
                VGap(AppSpacing.sm)
                Button {
                    onRetry()
                } label: {
                    Text("Retry").textStyle(AppTypography.labelLarge.copyWith(color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
            }
        }
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
}

// Port of lib/features/visa/presentation/pages/visa_page.dart

import SwiftUI

/// VISA SERVICE — the public visa catalogue, in two halves.
///
/// **Global Visa** lists the destinations the visa desk actually processes
/// applications for: active countries which also have a published visa type.
/// Tapping one opens the country screen for its profile and visa types.
///
/// **Visa-Free Countries** is informational — where a Myanmar passport needs
/// no application at all — and is curated in `visaFreeCountries` because the
/// catalogue API only covers destinations the desk handles.
///
/// Mobile-first: one scrolling column, every grid reflows by width.
struct VisaPage: View {
    init() {}

    var body: some View {
        Scaffold(backgroundColor: AppColors.surface) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Photo hero — static banner, headline and back button.
                        VisaHero()
                        VGap(AppSpacing.md)

                        //    …and the three visa types the desk handles, just below it.
                        VisaBand { VisaTypeCards() }
                        VGap(AppSpacing.xl)

                        // 2. Global Visa — destinations we process; tap for the details.
                        VisaBand { GlobalVisaSection() }
                        VGap(AppSpacing.section)

                        // 3. Visa-Free — no application needed on a Myanmar passport.
                        VisaBand { VisaFreeSection() }
                        VGap(AppSpacing.section)

                        // 4. Talk to the right team — Visa Department contact card.
                        VisaBand {
                            DepartmentsSection(
                                title: LocaleKeys.visa_need_help_with_visa.tr(),
                                subtitle: "Our visa specialists are just a message away — reach out for guidance on paperwork, approvals, and next steps.",
                                include: [.visa]
                            )
                        }
                        VGap(AppSpacing.section)
                    }
                }
                .scrollIndicators(.hidden)
                // MediaQuery.sizeOf(context).width, for VisaSectionHeading.
                .environment(
                    \.visaMediaWidth,
                    proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing
                )
            }
        }
    }
}

/// Centres a section and caps it on desktop, so every band shares one measure.
private struct VisaBand<Content: View>: View {
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
// 1. Hero — "Your Global Visa Partner"
// ---------------------------------------------------------------------------
private struct VisaHero: View {
    var body: some View {
        PhotoHero(
            image: {
                // Image.asset(fit: BoxFit.cover, alignment: Alignment.bottomCenter).
                Color.clear
                    .overlay(alignment: .bottom) {
                        AppImage(AppAssets.versionTwoBanner, fit: .cover)
                    }
            },
            title: "Your Global\nVisa Partner",
            subtitle: LocaleKeys.visa_from_paperwork_to_approval_we_handle.tr(),
            // The headline shares the bands' measure so it lines up with the
            // sections below on desktop.
            contentMaxWidth: 1180
        )
    }
}

/// Tourist, Business and Family — one card each, side by side.
private struct VisaTypeCards: View {
    // (icon, label) for each visa type the desk handles.
    private static let types: [(IconData, String)] = [
        (Icons.beach_access_rounded, "Tourist"),
        (Icons.business_center_rounded, "Business"),
        (Icons.groups_rounded, "Family"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.types.enumerated()), id: \.offset) { i, type in
                if i > 0 { HGap(10) }
                VisaTypeCard(icon: type.0, label: type.1)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct VisaTypeCard: View {
    let icon: IconData
    let label: String

    var body: some View {
        VStack(spacing: 0) {
            Icon(icon, size: 22, color: Colors.white)
                .frame(width: 44, height: 44)
                .boxDecoration(color: AppColors.primary, radius: 13)
            VGap(10)
            Text(label)
                .textStyle(AppTypography.body(14, weight: .w800, color: AppColors.textPrimary))
                .lineLimit(1)
                .truncationMode(.tail)
            VGap(2)
            Text("Visa")
                .textStyle(AppTypography.body(11, color: AppColors.textSecondary))
        }
        .frame(maxWidth: .infinity)
        .padding(horizontal: 6, vertical: 14)
        .boxDecoration(
            color: AppColors.surface,
            radius: 18,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 12, offset: Offset(0, 5))]
        )
    }
}

// ---------------------------------------------------------------------------
// 2. Global Visa — destinations we process applications for
// ---------------------------------------------------------------------------

private struct GlobalVisaSection: View {
    @Environment(AppContainer.self) var container

    var body: some View {
        container.publishedVisaCountryList.state.when(
            data: { items in
                items.isEmpty
                    ? AnyView(VisaMessage(
                        icon: Icons.public_off_rounded,
                        message: "No visa destinations are available right now."
                    ))
                    : AnyView(GlobalVisaGrid(countries: items))
            },
            error: { _ in
                AnyView(VisaMessage(
                    icon: Icons.cloud_off_rounded,
                    message: "Unable to load visa destinations. Please try again.",
                    onRetry: {
                        container.activeVisaCountryList.invalidate()
                        container.publishedVisaTypeCountryList.invalidate()
                        container.publishedVisaCountryList.invalidate()
                    }
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

private struct GlobalVisaGrid: View {
    let countries: [VisaCountryModel]

    /// `LayoutBuilder`'s `constraints.maxWidth`.
    @State var width: CGFloat = 0

    var body: some View {
        let columns = width >= 940
            ? 7
            : width >= 650
            ? 5
            : width >= 430
            ? 4
            : 3

        VStack(spacing: 0) {
            VisaReveal {
                VisaSectionHeading(
                    eyebrow: "Visa services we handle",
                    title: "Global",
                    highlight: "Visa",
                    subtitle: "Tap a destination to see its visa types and the documents each one needs."
                )
            }
            VGap(AppSpacing.lg)
            VisaGrid(
                count: countries.count,
                columns: columns,
                spacing: 10,
                extent: 118,
                width: width
            ) { i in
                VisaReveal(index: i, stagger: .milliseconds(35)) {
                    GlobalVisaTile(country: countries[i])
                }
            }
        }
        .frame(maxWidth: .infinity)
        .readWidth($width)
    }
}

/// Circular flag above the country name — the whole tile opens the country
/// screen. A country with no slug cannot be looked up, so it stays inert.
private struct GlobalVisaTile: View {
    let country: VisaCountryModel

    @Environment(AppRouter.self) var router

    var body: some View {
        let slug = country.slug.trimmingCharacters(in: .whitespacesAndNewlines)

        Button {
            router.push(.visaCountry(
                slug: slug,
                countryName: country.name,
                flagUrl: country.flagUrl,
                flagCode: country.flagCode
            ))
        } label: {
            VStack(spacing: 0) {
                VisaFlagAvatar(
                    flagUrl: country.flagUrl,
                    flagCode: country.flagCode,
                    size: 54
                )
                VGap(8)
                Text(country.name)
                    .textStyle(AppTypography.body(12, weight: .w700, color: AppColors.primaryDark, height: 1.2))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
            }
            .padding(horizontal: 4, vertical: 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ink(radius: 16))
        .disabled(slug.isEmpty)
    }
}

// ---------------------------------------------------------------------------
// 3. Visa-Free Countries — no application needed
// ---------------------------------------------------------------------------

private struct VisaFreeSection: View {
    /// `LayoutBuilder`'s `constraints.maxWidth`.
    @State var width: CGFloat = 0

    var body: some View {
        let columns = width >= 940
            ? 4
            : width >= 650
            ? 3
            : width >= 430
            ? 2
            : 1

        VStack(spacing: 0) {
            VisaReveal {
                VisaSectionHeading(
                    eyebrow: "For Myanmar passport holders",
                    title: "Visa-Free",
                    highlight: "Countries",
                    subtitle: "Myanmar citizens can travel to these destinations without a visa."
                )
            }
            VGap(AppSpacing.lg)
            VisaGrid(
                count: visaFreeCountries.count,
                columns: columns,
                spacing: 14,
                extent: columns == 1 ? 84 : 88,
                width: width
            ) { i in
                VisaReveal(index: i, stagger: .milliseconds(40)) {
                    VisaFreeTile(country: visaFreeCountries[i])
                }
            }
        }
        .frame(maxWidth: .infinity)
        .readWidth($width)
    }
}

private struct VisaFreeTile: View {
    let country: VisaFreeCountry

    var body: some View {
        HStack(spacing: 0) {
            VisaFlagAvatar(flagUrl: country.flagUrl, flagCode: country.flagCode)
            HGap(12)
            VStack(alignment: .leading, spacing: 0) {
                Text(country.name)
                    .textStyle(AppTypography.body(14, weight: .w800, color: AppColors.primaryDark, height: 1.12))
                    .lineLimit(2)
                    .truncationMode(.tail)
                VGap(4)
                HStack(spacing: 0) {
                    Icon(Icons.check_rounded, size: 15, color: AppColors.primary)
                    HGap(4)
                    Text("Visa-free")
                        .textStyle(AppTypography.body(10.5, weight: .w700, color: AppColors.primary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(horizontal: 14, vertical: 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .boxDecoration(
            color: AppColors.surface,
            radius: 18,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 12, offset: Offset(0, 5))]
        )
    }
}

/// Empty / failed state for a section, with an optional retry.
private struct VisaMessage: View {
    let icon: IconData
    let message: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Icon(icon, size: 42, color: AppColors.textTertiary)
            VGap(10)
            Text(message)
                .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                .multilineTextAlignment(.center)
            if let onRetry {
                VGap(10)
                Button {
                    onRetry()
                } label: {
                    Text("Retry").textStyle(AppTypography.labelLarge.copyWith(color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
}

// ---------------------------------------------------------------------------
// 4. Our Departments — see `DepartmentsSection` (shared with the Tour screen).
// ---------------------------------------------------------------------------

/// `GridView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
/// gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(...))`: `columns`
/// equal cells per row, each `extent` tall, `spacing` apart on both axes.
private struct VisaGrid<Cell: View>: View {
    let count: Int
    let columns: Int
    let spacing: CGFloat
    let extent: CGFloat
    /// The grid's own width (`constraints.maxWidth`).
    let width: CGFloat
    @ViewBuilder let cell: (Int) -> Cell

    var body: some View {
        let cellWidth = max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))

        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(stride(from: 0, to: count, by: columns)), id: \.self) { start in
                HStack(spacing: spacing) {
                    ForEach(start..<min(start + columns, count), id: \.self) { i in
                        cell(i).frame(width: cellWidth, height: extent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    /// Reports this view's laid-out width — `LayoutBuilder`'s `maxWidth`.
    func readWidth(_ width: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width.wrappedValue = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newWidth in width.wrappedValue = newWidth }
            }
        )
    }
}

// Port of lib/features/booking/presentation/pages/location_picker_page.dart

import SwiftUI

/// Searchable origin/destination picker. Push it and await the chosen location:
///
/// ```swift
/// let loc = await router.pushForResult(
///     .locationPicker(title: LocaleKeys.common_from.tr()),
///     as: LocationModel.self
/// )
/// ```
struct LocationPickerPage: View {
    let title: String

    /// Location to exclude from the list (e.g. don't let To == From).
    let exclude: LocationModel?

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var query = ""

    init(title: String, exclude: LocationModel? = nil) {
        self.title = title
        self.exclude = exclude
    }

    private func filtered(_ locations: [LocationModel]) -> [LocationModel] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return locations.filter { l in
            if let exclude, l.code == exclude.code {
                return false
            }
            return q.isEmpty || l.searchable.contains(q)
        }
    }

    var body: some View {
        let locations = container.locationList

        Scaffold(
            backgroundColor: AppColors.surface,
            appBar: {
                AppBar(
                    title: LocaleKeys.booking_select.tr(args: [title]),
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white
                )
                // Same green heading gradient as the air-ticket search page,
                // filling the whole app-bar area (flexibleSpace).
                .background(AppColors.heroGradient.ignoresSafeArea(edges: .top))
            }
        ) {
            VStack(spacing: 0) {
                // Search box.
                LocationSearchField(
                    text: $query,
                    hintText: LocaleKeys.booking_search_city_or_airport.tr()
                )
                .padding(AppSpacing.screenH)
                locations.state.when(
                    data: { locations in AnyView(results(filtered(locations))) },
                    error: { error in
                        AnyView(
                            LocationLoadError(
                                message: Dart.describe(error),
                                onRetry: { container.locationList.invalidate() }
                            )
                        )
                    },
                    loading: {
                        AnyView(
                            ProgressView()
                                .tint(AppColors.primary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        )
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    @MainActor
    private func results(_ results: [LocationModel]) -> some View {
        if results.isEmpty {
            Text(LocaleKeys.booking_no_matches_for.tr(args: [query]))
                .textStyle(AppTypography.body(14, color: AppColors.textSecondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, loc in
                        if index > 0 {
                            MaterialDivider(height: 1, color: AppColors.divider)
                        }
                        LocationTile(location: loc) { router.pop(loc) }
                    }
                }
                .padding(.horizontal, AppSpacing.screenH)
            }
        }
    }
}

/// The `ListTile` for one location: a red pin, the airport name with its
/// primary-coloured code on top, and the city/country beneath.
private struct LocationTile: View {
    let location: LocationModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Icon(Icons.location_on, size: 28, color: AppColors.error)
                HGap(16)
                VStack(alignment: .leading, spacing: 0) {
                    // Airport name (+ primary-coloured code) on top,
                    // country beneath.
                    (
                        Text("\(location.facilityName) ")
                            .styled(AppTypography.body(15, weight: .w600, color: AppColors.textPrimary))
                            + Text("(\(location.code))")
                            .styled(AppTypography.body(15, weight: .w700, color: AppColors.primary))
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                    Text(
                        [location.city, location.country]
                            .filter { !$0.isEmpty }
                            .joined(separator: ", ")
                    )
                    .textStyle(AppTypography.body(12, color: AppColors.textPrimary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ink)
    }
}

/// The search `TextField` with the app's input decoration (`AppTextField`'s
/// look) plus `autofocus: true`, which `AppTextField` cannot express.
private struct LocationSearchField: View {
    @Binding var text: String
    let hintText: String

    @FocusState private var focused: Bool

    private let style = AppTypography.body(15)

    var body: some View {
        HStack(spacing: 0) {
            Icon(Icons.search, size: 22, color: focused ? AppColors.primary : AppColors.textSecondary)
                .frame(width: 48)
            TextField(
                "",
                text: $text,
                prompt: Text(hintText).font(style.font).foregroundColor(AppColors.textPlaceholder)
            )
            .font(style.font)
            .foregroundStyle(style.color)
            .tint(AppColors.primary)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(true)
            .submitLabel(.done)
            .focused($focused)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusSm, style: .continuous)
                .fill(AppColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusSm, style: .continuous)
                .stroke(focused ? AppColors.primary : AppColors.border, lineWidth: focused ? 1.6 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .task {
            // autofocus: true — focus once the route has appeared.
            try? await Task.sleep(for: .milliseconds(100))
            focused = true
        }
    }
}

/// Dart `_LocationLoadError`.
private struct LocationLoadError: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Icon(Icons.cloud_off_outlined, size: 32, color: AppColors.error)
            VGap(12)
            Text(message)
                .textStyle(AppTypography.body(14, color: AppColors.textSecondary))
                .multilineTextAlignment(.center)
            VGap(12)
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Icon(Icons.refresh, size: 18)
                    Text("Retry")
                }
            }
            .buttonStyle(OutlinedButtonStyle())
        }
        .padding(AppSpacing.screenH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

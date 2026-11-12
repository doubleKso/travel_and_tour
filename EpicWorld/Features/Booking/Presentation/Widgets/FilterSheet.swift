// Port of lib/features/booking/presentation/widgets/filter_sheet.dart

import SwiftUI

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// Result returned by `FilterSheet`. All fields are nullable; nil means "no
/// filter applied for this dimension".
struct FilterResult: Equatable {
    let maxStops: Int?
    let travelClass: TravelClass?
    let maxPrice: Double?
    let airlines: Set<String>?
    let departureTimes: Set<String>?

    /// Price sort direction: true = cheapest first, false = highest first.
    let sortAscending: Bool

    init(
        maxStops: Int? = nil,
        travelClass: TravelClass? = nil,
        maxPrice: Double? = nil,
        airlines: Set<String>? = nil,
        departureTimes: Set<String>? = nil,
        sortAscending: Bool = true
    ) {
        self.maxStops = maxStops
        self.travelClass = travelClass
        self.maxPrice = maxPrice
        self.airlines = airlines
        self.departureTimes = departureTimes
        self.sortAscending = sortAscending
    }
}

// ---------------------------------------------------------------------------
// Sheet widget
// ---------------------------------------------------------------------------

struct FilterSheet: View {
    let initial: FilterResult
    let priceCeiling: Double
    let availableAirlines: [String]
    let availableAirlineLogoUrls: [String: String]
    let availableAirlineCodes: [String: String]

    // ---- State (Dart `_FilterSheetState`) ----
    @State private var airlines: Set<String>
    @State private var departureTimes: Set<String>
    @State private var price: Double
    @State private var `class`: TravelClass?
    @State private var maxStops: Int?
    @State private var sortAsc: Bool

    @Environment(\.dismissModal) private var dismissModal

    init(
        initial: FilterResult,
        priceCeiling: Double,
        availableAirlines: [String] = [],
        availableAirlineLogoUrls: [String: String] = [:],
        availableAirlineCodes: [String: String] = [:]
    ) {
        self.initial = initial
        self.priceCeiling = priceCeiling
        self.availableAirlines = availableAirlines
        self.availableAirlineLogoUrls = availableAirlineLogoUrls
        self.availableAirlineCodes = availableAirlineCodes
        // initState
        _airlines = State(initialValue: initial.airlines ?? [])
        _departureTimes = State(initialValue: initial.departureTimes ?? [])
        // Clamped: a max price carried over from an earlier search can sit above
        // this search's ceiling, and Slider asserts its value is within range.
        _price = State(initialValue: min(max(initial.maxPrice ?? priceCeiling, 0), priceCeiling))
        _class = State(initialValue: initial.travelClass)
        _maxStops = State(initialValue: initial.maxStops)
        _sortAsc = State(initialValue: initial.sortAscending)
    }

    /// Dart `FilterSheet.show(context, …)`.
    @MainActor
    static func show(
        initial: FilterResult,
        priceCeiling: Double,
        availableAirlines: [String] = [],
        availableAirlineLogoUrls: [String: String] = [:],
        availableAirlineCodes: [String: String] = [:]
    ) async -> FilterResult? {
        await showModalBottomSheet(
            isScrollControlled: true,
            backgroundColor: Colors.transparent
        ) { _ in
            FilterSheet(
                initial: initial,
                priceCeiling: priceCeiling,
                availableAirlines: availableAirlines,
                availableAirlineLogoUrls: availableAirlineLogoUrls,
                availableAirlineCodes: availableAirlineCodes
            )
        }
    }

    // Time bucket records: (id, label, range)
    private static let timeBuckets: [(String, String, String)] = [
        ("morning", "Morning", "6am – 12pm"),
        ("afternoon", "Afternoon", "12pm – 6pm"),
        ("evening", "Evening", "After 6pm"),
        ("night", "Night", "12am – 6am"),
    ]

    @MainActor
    private func reset() {
        airlines = []
        departureTimes = []
        price = priceCeiling
        `class` = nil
        maxStops = nil
        sortAsc = true
    }

    @MainActor
    private func apply() {
        dismissModal(
            FilterResult(
                maxStops: maxStops,
                travelClass: `class`,
                maxPrice: price >= priceCeiling ? nil : price,
                airlines: airlines.isEmpty ? nil : airlines,
                departureTimes: departureTimes.isEmpty ? nil : departureTimes,
                sortAscending: sortAsc
            )
        )
    }

    // DraggableScrollableSheet(initialChildSize: 0.88, …, expand: false): the
    // sheet opens at 88% of the screen.
    var body: some View {
        VStack(spacing: 0) {
            // ---- drag handle + header ----
            header
            // Separator between the "Filters" header and the filter options.
            MaterialDivider(height: 1, color: AppColors.divider)
                .padding(20, 6, 20, 10)
            // ---- scrollable content ----
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Airlines section (only when list is non-empty)
                    if !availableAirlines.isEmpty {
                        FilterSectionHeader(title: "Airlines")
                        ForEach(availableAirlines, id: \.self) { airline in
                            CheckRow(
                                label: airline,
                                leading: AnyView(
                                    AirlineLogo(
                                        name: airline,
                                        logoUrl: availableAirlineLogoUrls[airline] ?? "",
                                        carrierCode: availableAirlineCodes[airline],
                                        size: 30
                                    )
                                ),
                                checked: airlines.contains(airline),
                                onChanged: { _ in
                                    if airlines.contains(airline) {
                                        airlines.remove(airline)
                                    } else {
                                        airlines.insert(airline)
                                    }
                                }
                            )
                        }
                        sectionDivider
                    }

                    // Departure time section
                    FilterSectionHeader(title: "Departure Time")
                    ForEach(0..<Self.timeBuckets.count, id: \.self) { index in
                        let bucket = Self.timeBuckets[index]
                        CheckRow(
                            label: bucket.1,
                            trailing: bucket.2,
                            checked: departureTimes.contains(bucket.0),
                            onChanged: { _ in
                                if departureTimes.contains(bucket.0) {
                                    departureTimes.remove(bucket.0)
                                } else {
                                    departureTimes.insert(bucket.0)
                                }
                            }
                        )
                    }
                    sectionDivider

                    // Price section
                    priceSection
                    // Sort by price — cheapest / highest.
                    FilterSectionHeader(title: "Sort by price")
                    CheckRow(
                        label: LocaleKeys.booking_cheapest_first.tr(),
                        checked: sortAsc,
                        radio: true,
                        onChanged: { _ in sortAsc = true }
                    )
                    CheckRow(
                        label: LocaleKeys.booking_highest_first.tr(),
                        checked: !sortAsc,
                        radio: true,
                        onChanged: { _ in sortAsc = false }
                    )
                    sectionDivider

                    // Class section
                    FilterSectionHeader(title: "Class")
                    ForEach(TravelClass.values, id: \.self) { c in
                        CheckRow(
                            label: c.label,
                            checked: `class` == c,
                            radio: true,
                            onChanged: { _ in `class` = c }
                        )
                    }
                    // A search seeds this from the cabin class picked on the
                    // home form, so there has to be a way back to every class.
                    CheckRow(
                        label: LocaleKeys.booking_any.tr(),
                        checked: `class` == nil,
                        radio: true,
                        onChanged: { _ in `class` = nil }
                    )
                    sectionDivider

                    // Stops section
                    FilterSectionHeader(title: "Stops")
                    CheckRow(
                        label: LocaleKeys.booking_non_stop.tr(),
                        checked: maxStops == 0,
                        radio: true,
                        onChanged: { _ in maxStops = 0 }
                    )
                    CheckRow(
                        label: LocaleKeys.booking_1_stop.tr(),
                        checked: maxStops == 1,
                        radio: true,
                        onChanged: { _ in maxStops = 1 }
                    )
                    CheckRow(
                        label: LocaleKeys.booking_any.tr(),
                        checked: maxStops == nil,
                        radio: true,
                        onChanged: { _ in maxStops = nil }
                    )
                    VGap(12)
                }
                .padding(20, 0, 20, 8)
            }
            // ---- bottom action bar ----
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(top: 24), style: .circular)
                .fill(AppColors.surface)
                .ignoresSafeArea(edges: .bottom)
        )
        .containerRelativeFrame(.vertical) { length, _ in length * 0.88 }
    }

    // ---------- sub-builders ----------

    @MainActor
    private var header: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.border)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
            VGap(14)
            HStack(spacing: 0) {
                Text(LocaleKeys.booking_filters.tr())
                    .textStyle(AppTypography.heading(20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Reset everything — icon button keeps the header compact.
                Button {
                    reset()
                } label: {
                    Icon(Icons.refresh_rounded, size: 24, color: AppColors.primary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocaleKeys.booking_reset_filters.tr())
            }
        }
        .padding(20, 14, 8, 8)
    }

    private var priceSection: some View {
        let priceLabel = "\(Formatters.grouped(Int(price.rounded()))) MMK"
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                FilterSectionHeader(title: "Price")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(priceLabel)
                    .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.primary))
            }
            MaterialSlider(value: $price, max: priceCeiling)
            VGap(4)
        }
    }

    @MainActor
    private var bottomBar: some View {
        Button {
            apply()
        } label: {
            Text(LocaleKeys.booking_apply_filters.tr())
                .textStyle(AppTypography.body(15, weight: .w600, color: AppColors.surface))
        }
        .buttonStyle(
            ElevatedButtonStyle(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                cornerRadius: 12,
                padding: EdgeInsets(top: 15, leading: 24, bottom: 15, trailing: 24),
                elevation: 0
            )
        )
        .padding(20, 10, 20, 16)
    }

    private var sectionDivider: some View {
        MaterialDivider(height: 1, color: AppColors.divider)
            .padding(.vertical, 12)
    }
}

// ---------------------------------------------------------------------------
// Private helper widgets
// ---------------------------------------------------------------------------

/// Dart `_SectionHeader`.
private struct FilterSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .textStyle(AppTypography.heading(15))
            .padding(.top, 4)
            .padding(.bottom, 10)
    }
}

/// A row that renders either a checkbox or a radio button on the right side.
///
/// `radio` = true → circle radio button style.
/// `radio` = false (default) → 20×20 square checkbox with 4px border radius.
private struct CheckRow: View {
    let label: String
    var trailing: String? = nil
    var leading: AnyView? = nil
    let checked: Bool
    var radio = false
    let onChanged: (Bool) -> Void

    var body: some View {
        Button {
            onChanged(!checked)
        } label: {
            HStack(spacing: 0) {
                // Optional leading widget (e.g. airline logo)
                if let leading {
                    leading
                    HGap(12)
                }
                // Label
                Text(label)
                    .textStyle(AppTypography.body(14, weight: .w400, color: AppColors.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Optional trailing time-range text
                if let trailing {
                    Text(trailing)
                        .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                    HGap(12)
                }
                // Checkbox or radio indicator
                if radio {
                    RadioIndicator(selected: checked)
                } else {
                    CheckIndicator(checked: checked)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ink(radius: 8))
    }
}

/// 20×20 square checkbox with 4px corner radius.
private struct CheckIndicator: View {
    let checked: Bool

    var body: some View {
        ZStack {
            if checked {
                Icon(Icons.check, size: 14, color: Colors.white)
            }
        }
        .frame(width: 20, height: 20)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(checked ? AppColors.primary : Colors.transparent)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(checked ? AppColors.primary : AppColors.border, lineWidth: 1.5)
        )
        .animation(.linear(duration: 0.15), value: checked)
    }
}

/// Circle radio button: thick border (5px) when selected, thin when not.
private struct RadioIndicator: View {
    let selected: Bool

    var body: some View {
        Circle()
            .strokeBorder(selected ? AppColors.primary : AppColors.border, lineWidth: selected ? 5 : 1.5)
            .frame(width: 20, height: 20)
            .animation(.linear(duration: 0.15), value: selected)
    }
}

/// Material `Slider` with the sheet's `SliderTheme`: primary active track and
/// thumb, `AppColors.border` inactive track, 12% primary overlay while
/// dragging. 48pt tall with the track inset by the 24pt overlay radius, as in
/// Flutter.
private struct MaterialSlider: View {
    @Binding var value: Double
    let max: Double

    @State private var dragging = false

    private static let inset: CGFloat = 24
    private static let trackHeight: CGFloat = 4
    private static let thumbSize: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = Swift.max(geometry.size.width - Self.inset * 2, 1)
            let fraction = max > 0 ? Swift.min(Swift.max(value / max, 0), 1) : 0
            let thumbX = Self.inset + trackWidth * fraction
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.border)
                    .frame(width: trackWidth, height: Self.trackHeight)
                    .offset(x: Self.inset)
                Capsule()
                    .fill(AppColors.primary)
                    .frame(width: trackWidth * fraction, height: Self.trackHeight)
                    .offset(x: Self.inset)
                Circle()
                    .fill(AppColors.primary.withValues(alpha: 0.12))
                    .frame(width: 40, height: 40)
                    .opacity(dragging ? 1 : 0)
                    .offset(x: thumbX - 20)
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: Self.thumbSize, height: Self.thumbSize)
                    .shadow(color: Colors.black.withValues(alpha: 0.2), radius: 1, y: 1)
                    .offset(x: thumbX - Self.thumbSize / 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        dragging = true
                        let x = Swift.min(Swift.max(drag.location.x - Self.inset, 0), trackWidth)
                        value = max * Double(x / trackWidth)
                    }
                    .onEnded { _ in dragging = false }
            )
        }
        .frame(height: 48)
    }
}

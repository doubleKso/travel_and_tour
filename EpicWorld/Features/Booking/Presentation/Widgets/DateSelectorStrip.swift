// Port of lib/features/booking/presentation/widgets/date_selector_strip.dart

import SwiftUI

/// Horizontal, scrollable date picker shown above the flight/bus results.
///
/// Each chip shows the day + weekday with a "from" fare beneath it; the selected
/// day is coloured in brand green with an underline. A trailing calendar button
/// opens the full picker for dates outside the visible range. Drives
/// `FlightBookingState.activeDate` via `onSelected`.
struct DateSelectorStrip: View {
    let selectedDate: DateTime
    let onSelected: (DateTime) -> Void

    /// Lowest fare for a given day, shown under the date. Returns nil to hide it.
    let priceForDate: ((DateTime) -> Double?)?

    /// Minimum number of days to render starting from today.
    let dayCount: Int

    init(
        selectedDate: DateTime,
        onSelected: @escaping (DateTime) -> Void,
        priceForDate: ((DateTime) -> Double?)? = nil,
        dayCount: Int = 14
    ) {
        self.selectedDate = selectedDate
        self.onSelected = onSelected
        self.priceForDate = priceForDate
        self.dayCount = dayCount
    }

    // Chip is 66 wide with a 6px separator → 72px per day. 16px leading pad.
    private static let lead: CGFloat = 16

    private static func sameDay(_ a: DateTime, _ b: DateTime) -> Bool {
        a.year == b.year && a.month == b.month && a.day == b.day
    }

    private var start: DateTime {
        let now = DateTime.now()
        return DateTime(now.year, now.month, now.day)
    }

    private var total: Int {
        let spanToSelected = selectedDate.difference(start).inDays
        return min(max(spanToSelected + 3, dayCount), 90)
    }

    var body: some View {
        let start = self.start
        let total = self.total
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { i in
                        let date = start.add(Duration(days: i))
                        DateChip(
                            date: date,
                            selected: Self.sameDay(date, selectedDate),
                            onTap: { onSelected(date) }
                        )
                        .id(i)
                    }
                    // +1 for the trailing calendar button
                    CalendarButton(onTap: { Task { await openCalendar(start) } })
                        .id(total)
                }
                .padding(.horizontal, Self.lead)
                .frame(height: 64)
            }
            .frame(height: 64)
            .onAppear {
                // `addPostFrameCallback((_) => _scrollToSelected())`.
                Task { @MainActor in scrollToSelected(proxy) }
            }
            .onChange(of: selectedDate.dateOnly) {
                Task { @MainActor in scrollToSelected(proxy) }
            }
        }
    }

    /// Centres the selected chip, clamped to the scroll extent — Dart's
    /// `lead + index * stride + chipHalf - viewport / 2`.
    @MainActor
    private func scrollToSelected(_ proxy: ScrollViewProxy) {
        let index = selectedDate.difference(start).inDays
        if index <= 0 {
            proxy.scrollTo(0, anchor: .leading)
            return
        }
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(min(index, total), anchor: .center)
        }
    }

    @MainActor
    private func openCalendar(_ first: DateTime) async {
        let initialDate = selectedDate.isBefore(first) ? first : selectedDate
        let lastDate = first.add(Duration(days: 365))
        let picked: DateTime? = await showDialog { dismiss in
            BookingDatePickerDialog(
                initialDate: initialDate,
                firstDate: first,
                lastDate: lastDate,
                onCancel: { dismiss(nil) },
                onConfirm: { dismiss($0) }
            )
        }
        if let picked { onSelected(picked) }
    }
}

/// Dart `_DateChip`.
private struct DateChip: View {
    let date: DateTime
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        // Big day number over a "month · weekday" caption, wrapped in a light-gray
        // bordered card that fills yellow (accent) when it's the selected date.
        VStack(spacing: 0) {
            Text("\(date.day)")
                .textStyle(AppTypography.heading(20, color: selected ? Colors.white : AppColors.textTertiary))
            VGap(1)
            Text("\(DateFormat("MMM").format(date)) · \(DateFormat("EEE").format(date))")
                .textStyle(
                    AppTypography.body(10, weight: .w600, color: selected ? Colors.white : AppColors.textTertiary)
                )
        }
        .padding(.vertical, 8)
        .frame(width: 66)
        // Selected date is a solid yellow card; inactive dates have no
        // border or fill — just grey text — so the selection stands out.
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(selected ? AppColors.accent : Colors.transparent)
        )
        .animation(.linear(duration: 0.18), value: selected)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

/// Dart `_CalendarButton`.
private struct CalendarButton: View {
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Icon(Icons.calendar_month_rounded, size: 19, color: AppColors.primary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.primarySurface))
            VGap(4)
            Text(LocaleKeys.booking_more.tr())
                .textStyle(AppTypography.body(10.5, weight: .w600, color: AppColors.primary))
        }
        .frame(width: 52)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

/// Flutter's `showDatePicker` dialog: a white Material card with the calendar
/// and Cancel / OK actions. Returns the picked day as a local `DateTime(y, m, d)`.
private struct BookingDatePickerDialog: View {
    let initialDate: DateTime
    let firstDate: DateTime
    let lastDate: DateTime
    let onCancel: () -> Void
    let onConfirm: (DateTime) -> Void

    @State private var selection: Date

    init(
        initialDate: DateTime,
        firstDate: DateTime,
        lastDate: DateTime,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (DateTime) -> Void
    ) {
        self.initialDate = initialDate
        self.firstDate = firstDate
        self.lastDate = lastDate
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selection = State(initialValue: initialDate.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DatePicker(
                "",
                selection: $selection,
                in: firstDate.date...lastDate.date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(AppColors.primary)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(action: onCancel) {
                    Text("Cancel").textStyle(AppTypography.labelLarge.copyWith(color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
                Button {
                    onConfirm(DateTime(date: selection).dateOnly)
                } label: {
                    Text("OK").textStyle(AppTypography.labelLarge.copyWith(color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
            }
        }
        .padding(16)
        .boxDecoration(color: AppColors.surface, radius: 28)
    }
}

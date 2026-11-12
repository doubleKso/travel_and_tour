// Port of lib/features/booking/presentation/pages/find_my_booking_page.dart
import SwiftUI
import UIKit

/// "Find my booking" — the way back into a reservation for a customer who
/// never signed in, or who booked on another device.
///
/// Two routes to the same place: the bookings this device remembers, and the
/// reference/email pair from the confirmation email. Both land on the
/// reservation confirmation, where payment can be finished.
struct FindMyBookingPage: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(\.routeEntryID) private var entryID

    @State private var reference = ""
    @State private var email = ""
    @State private var searching = false

    /// `AutovalidateMode.onUserInteraction` plus `validate()`: a field shows
    /// its validator's message once the customer has edited it, or once a
    /// search has been attempted.
    @State private var referenceValidated = false
    @State private var emailValidated = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case reference, email
    }

    init() {}

    // MARK: - Validation (internal so the unit tests reach it)

    /// `\w` spelled out as ASCII, as Dart's (JavaScript-flavoured) `RegExp`
    /// reads it.
    static let emailPattern = #"^[A-Za-z0-9_.+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$"#

    static func referenceValidator(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { return "Booking reference is required." }
        if text.count < 5 { return "Enter the full reference from your email." }
        return nil
    }

    static func emailValidator(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { return "Email is required." }
        if text.range(of: emailPattern, options: .regularExpression) == nil {
            return "Enter a valid email address, e.g. name@gmail.com."
        }
        return nil
    }

    // MARK: - Actions

    /// Dart `mounted`: this route is still on the stack.
    private var mounted: Bool {
        guard let entryID else { return true }
        return router.entries.contains { $0.id == entryID }
    }

    /// `FocusManager.instance.primaryFocus?.unfocus()`.
    private func unfocus() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func find() async {
        unfocus()
        referenceValidated = true
        emailValidated = true
        guard Self.referenceValidator(reference) == nil, Self.emailValidator(email) == nil else { return }

        searching = true
        let error = await openGuestBooking(
            container,
            router,
            reference: reference,
            email: email,
            isMounted: { mounted }
        )
        if !mounted { return }
        searching = false
        if let error {
            SnackBarCenter.shared.show(error, floating: true)
        }
    }

    // MARK: - Build

    var body: some View {
        let signedIn = container.authNotifier.state.isAuthenticated

        Scaffold(backgroundColor: AppColors.background, appBar: { appBar }) {
            ScrollView {
                VStack(spacing: 0) {
                    Icon(Icons.search_rounded, size: 26, color: AppColors.primary)
                        .frame(width: 54, height: 54)
                        .boxDecoration(color: AppColors.primarySurface, radius: 16)
                    VGap(14)
                    Text("Find my booking")
                        .textStyle(AppTypography.heading(24))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    VGap(6)
                    Text("Pick up where you left off, or enter a booking "
                        + "reference and email.")
                        .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    VGap(22)
                    DeviceBookingsSection(compact: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VGap(18)
                    OrDivider()
                    VGap(18)
                    form()
                    if !signedIn {
                        VGap(18)
                        signInPrompt()
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.screenH, 20, AppSpacing.screenH, 32)
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { unfocus() }
                }
            }
        }
        .onChange(of: reference) { oldValue, newValue in
            // The reference is printed in capitals on the confirmation, and
            // the lookup uppercases it anyway — so show what will be sent.
            let formatted = UpperCaseTextFormatter().formatEditUpdate(oldValue, newValue)
            if formatted != newValue {
                reference = formatted
                return
            }
            referenceValidated = true
        }
        .onChange(of: email) { _, _ in
            emailValidated = true
        }
    }

    /// `AppBar(title: Text('Find my booking'), centerTitle: true,
    /// backgroundColor: primary, foregroundColor: white,
    /// titleTextStyle: heading(19, white))`.
    private var appBar: some View {
        ZStack {
            HStack(spacing: 0) {
                if router.canPop {
                    BackButton(color: Colors.white)
                } else {
                    HGap(16)
                }
                Spacer(minLength: 0)
            }
            Text("Find my booking")
                .textStyle(AppTypography.heading(19, color: Colors.white))
                .lineLimit(1)
                .padding(.horizontal, 72)
        }
        .frame(height: AppTheme.toolbarHeight)
        .frame(maxWidth: .infinity)
        .background(AppColors.primary.ignoresSafeArea(edges: .top))
    }

    private func form() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            label("Booking reference", required: true)
            VGap(6)
            formField(
                $reference,
                field: .reference,
                hint: "EW-XXXXXXXX",
                helper: "On your confirmation — it starts with EW-.",
                error: referenceValidated ? Self.referenceValidator(reference) : nil,
                keyboardType: .default,
                capitalization: .characters,
                submitLabel: .next,
                onSubmit: { focusedField = .email }
            )
            VGap(14)
            label("Email", required: true)
            VGap(6)
            formField(
                $email,
                field: .email,
                hint: "you@example.com",
                helper: nil,
                error: emailValidated ? Self.emailValidator(email) : nil,
                keyboardType: .emailAddress,
                capitalization: .never,
                submitLabel: .done,
                onSubmit: { Task { await find() } }
            )
            VGap(18)
            Button {
                Task { await find() }
            } label: {
                if searching {
                    ProgressSpinner(size: 20, color: Colors.white)
                } else {
                    Text("Find my booking")
                        .textStyle(AppTypography.body(15, weight: .w700, color: Colors.white))
                }
            }
            .buttonStyle(ElevatedButtonStyle(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                minimumHeight: 48,
                cornerRadius: 10
            ))
            .frame(height: 48)
            .disabled(searching)
        }
        .padding(16, 18, 16, 18)
        .frame(maxWidth: .infinity)
        .boxDecoration(color: AppColors.surface, radius: 16, borderColor: AppColors.border)
    }

    /// The form's own `InputDecoration`: background fill, 14pt content padding,
    /// 10pt corners, a brand-green focus border, and the helper line under the
    /// field (replaced by the validator's message when there is one).
    @ViewBuilder
    private func formField(
        _ text: Binding<String>,
        field: Field,
        hint: String,
        helper: String?,
        error: String?,
        keyboardType: UIKeyboardType,
        capitalization: TextInputAutocapitalization,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        let isFocused = focusedField == field
        let borderColor: Color = error != nil
            ? AppColors.error
            : (isFocused ? AppColors.primary : AppColors.border)
        // A focused field in error falls back to the decoration's `border`
        // with Flutter's default 2pt focused width.
        let borderWidth: CGFloat = (error != nil && isFocused) ? 2 : 1
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "",
                text: text,
                prompt: Text(hint)
                    .font(AppTypography.body(13.5).font)
                    .foregroundColor(AppColors.textPlaceholder)
            )
            .font(AppTypography.bodyLarge.font)
            .foregroundStyle(AppColors.textPrimary)
            .tint(AppColors.primary)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(capitalization)
            .submitLabel(submitLabel)
            .focused($focusedField, equals: field)
            .onSubmit(onSubmit)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 10, style: .circular).fill(AppColors.background))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .circular)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            if let error {
                Text(error)
                    .textStyle(AppTypography.bodySmall.copyWith(color: AppColors.error))
                    .padding(.top, 6)
                    .padding(.horizontal, 14)
            } else if let helper {
                Text(helper)
                    .textStyle(AppTypography.body(11, color: AppColors.textPrimary))
                    .lineLimit(2)
                    .padding(.top, 6)
                    .padding(.horizontal, 14)
            }
        }
    }

    private func signInPrompt() -> some View {
        WrapLayout(alignment: .center) {
            Text("Have an account? ")
                .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
            Text("Sign in")
                .textStyle(AppTypography.body(12.5, weight: .w700, color: AppColors.primary))
                .onTapGesture { router.push(.login()) }
            Text(" to see all your bookings in one place.")
                .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
        }
    }

    private func label(_ text: String, required: Bool = false) -> some View {
        let style = AppTypography.body(12.5, weight: .w700, color: AppColors.textPrimary)
        let star = AppTypography.body(12.5, weight: .w700, color: AppColors.error)
        return (Text(verbatim: text).styled(style) + Text(verbatim: required ? " *" : "").styled(star))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Keeps a booking reference in the capitals it is printed in.
struct UpperCaseTextFormatter {
    init() {}

    /// Dart's `formatEditUpdate(oldValue, newValue)` on the field's text.
    func formatEditUpdate(_ oldValue: String, _ newValue: String) -> String {
        newValue.uppercased()
    }
}

private struct OrDivider: View {
    var body: some View {
        HStack(spacing: 0) {
            MaterialDivider(color: AppColors.border)
                .frame(maxWidth: .infinity)
            Text("OR")
                .textStyle(AppTypography.body(11.5, weight: .w700, color: AppColors.textPrimary))
                .padding(.horizontal, 12)
            MaterialDivider(color: AppColors.border)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Flutter's `CircularProgressIndicator` at a fixed size.
private struct ProgressSpinner: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(color)
            .scaleEffect(size / 20)
            .frame(width: size, height: size)
    }
}

/// Flutter's `Wrap(alignment:, crossAxisAlignment: WrapCrossAlignment.center)`:
/// children laid out in runs, each run aligned horizontally, children centred
/// within their run.
private struct WrapLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 0
    var runSpacing: CGFloat = 0

    private struct Run {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRuns(maxWidth: CGFloat, subviews: Subviews) -> [Run] {
        var runs: [Run] = []
        var current = Run()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            let extra = current.indices.isEmpty ? size.width : spacing + size.width
            if !current.indices.isEmpty && current.width + extra > maxWidth {
                runs.append(current)
                current = Run()
            }
            current.width += current.indices.isEmpty ? size.width : spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { runs.append(current) }
        return runs
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let runs = computeRuns(maxWidth: maxWidth, subviews: subviews)
        let width = runs.map(\.width).max() ?? 0
        let height = runs.map(\.height).reduce(0, +) + runSpacing * CGFloat(max(runs.count - 1, 0))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let runs = computeRuns(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for run in runs {
            var x: CGFloat
            switch alignment {
            case .center: x = bounds.minX + (bounds.width - run.width) / 2
            case .trailing: x = bounds.maxX - run.width
            default: x = bounds.minX
            }
            for index in run.indices {
                let proposalForChild = ProposedViewSize(width: bounds.width, height: nil)
                let size = subviews[index].sizeThatFits(proposalForChild)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (run.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: proposalForChild
                )
                x += size.width + spacing
            }
            y += run.height + runSpacing
        }
    }
}

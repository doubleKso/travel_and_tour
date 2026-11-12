// Port of lib/features/profile/presentation/pages/manage_profile_page.dart
import SwiftUI
import PhotosUI
import UIKit

/// MANAGE PROFILE — edit the member's photo, name and email. The membership
/// tier and points are auto-filled from the account and shown read-only.
struct ManageProfilePage: View {
    init() {}

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var name = ""
    @State private var email = ""
    @State private var didInitState = false

    // Form validation results (`_formKey.currentState!.validate()`).
    @State private var nameError: String?
    @State private var emailError: String?

    /// Newly picked image (previewed before saving); nil until the user picks.
    @State private var pickedBytes: Data?
    @State private var pickedContentType = "image/jpeg"

    // `ImagePicker().pickImage(source: ImageSource.gallery, …)`.
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        let auth = container.authNotifier.state
        let points = container.currentMemberPoints
        let tier = tierForPoints(points)

        Scaffold(
            backgroundColor: AppColors.surface,
            appBar: {
                AppBar(
                    title: LocaleKeys.profile_manage_profile.tr(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    centerTitle: true
                )
            }
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    // Avatar with an edit / camera button.
                    ZStack(alignment: .bottomTrailing) {
                        avatar(auth)
                            .frame(width: 104, height: 104)
                            .background(AppColors.primarySurface)
                            .clipShape(Circle())
                            // The 3pt border a Flutter Container adds around its child.
                            .padding(3)
                            .boxDecoration(
                                circle: true,
                                borderColor: AppColors.primary,
                                borderWidth: 3,
                                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 14, offset: Offset(0, 6))]
                            )
                        Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white)
                            // padding 8 plus the 2.5pt border.
                            .padding(10.5)
                            .boxDecoration(color: AppColors.primary, circle: true, borderColor: Colors.white, borderWidth: 2.5)
                            .onTapGesture { pickImage() }
                    }
                    VGap(10)
                    Button {
                        pickImage()
                    } label: {
                        HStack(spacing: 0) {
                            Icon(Icons.upload_rounded, size: 18)
                            HGap(8)
                            Text(LocaleKeys.profile_upload_new_photo.tr())
                        }
                    }
                    .buttonStyle(TextButtonStyle(foregroundColor: AppColors.primary))
                    VGap(20)

                    FloatingLabelBox(label: LocaleKeys.common_full_name.tr()) {
                        InnerField(
                            text: $name,
                            hint: "Enter your full name",
                            errorText: nameError,
                            submitLabel: .next
                        )
                    }
                    VGap(20)

                    FloatingLabelBox(label: LocaleKeys.common_email.tr()) {
                        // `readOnly: true` — shown, never edited.
                        VStack(alignment: .leading, spacing: 0) {
                            Text(email.isEmpty ? "Enter your email" : email)
                                .textStyle(
                                    email.isEmpty
                                        ? AppTypography.body(14, color: AppColors.textPlaceholder)
                                        : AppTypography.body(14, weight: .w600, color: AppColors.textPrimary)
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let emailError {
                                Text(emailError)
                                    .textStyle(AppTypography.bodySmall.copyWith(color: AppColors.error))
                                    .padding(.top, 4)
                            }
                        }
                    }
                    VGap(20)

                    // Read-only, auto-filled account fields.
                    FloatingLabelBox(label: LocaleKeys.profile_member_tier.tr(), readOnly: true) {
                        ReadOnlyValue(value: tier.memberTitle)
                    }
                    VGap(20)
                    FloatingLabelBox(label: LocaleKeys.profile_points.tr(), readOnly: true) {
                        ReadOnlyValue(value: "\(Formatters.grouped(points)) points")
                    }
                    VGap(8)
                    Text(LocaleKeys.profile_member_tier_and_points_update_automatically.tr())
                        .textStyle(AppTypography.body(12, color: AppColors.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VGap(28)

                    Button {
                        Task { await save() }
                    } label: {
                        if auth.isLoading {
                            ProgressView()
                                .tint(Colors.white)
                                .frame(width: 22, height: 22)
                        } else {
                            Text(LocaleKeys.profile_save_changes.tr())
                        }
                    }
                    .buttonStyle(ElevatedButtonStyle())
                    .disabled(auth.isLoading)
                }
                .padding(24, 28, 24, 32)
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPicked(item) }
        }
        .onAppear {
            // initState: seed the controllers from the signed-in account once.
            guard !didInitState else { return }
            didInitState = true
            name = container.authNotifier.state.displayName
            email = container.authNotifier.state.email ?? ""
        }
    }

    /// Preview: freshly picked bytes → previously saved bytes → account photo →
    /// bundled asset.
    @ViewBuilder
    private func avatar(_ auth: AuthState) -> some View {
        if let bytes = pickedBytes ?? auth.avatarBytes {
            if let image = UIImage(data: bytes) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                AppColors.primarySurface
            }
        } else if let url = auth.user?.avatarUrl, !url.isEmpty {
            NetworkImage(url, fit: .cover) {
                AppColors.primarySurface
            } error: {
                AppColors.primarySurface
            }
        } else {
            AppImage(AppAssets.profilePlaceholder, fit: .cover)
        }
    }

    // MARK: - Logic

    private func pickImage() {
        pickerItem = nil
        showPicker = true
    }

    /// `pickImage(maxWidth: 800, imageQuality: 85)` then `readAsBytes()`: the
    /// picked photo is scaled down to at most 800pt wide and re-encoded as
    /// JPEG at 85% quality, as image_picker does on iOS.
    private func loadPicked(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let maxWidth: CGFloat = 800
        var output = image
        if image.size.width > maxWidth {
            let scale = maxWidth / image.size.width
            let size = CGSize(width: maxWidth, height: (image.size.height * scale).rounded())
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            output = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        guard let bytes = output.jpegData(compressionQuality: 0.85) else { return }
        if Task.isCancelled { return }
        pickedBytes = bytes
        // `file.mimeType ?? 'image/jpeg'` — the re-encoded file is a JPEG.
        pickedContentType = "image/jpeg"
    }

    /// `_formKey.currentState!.validate()`.
    private func validate() -> Bool {
        nameError = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter your name" : nil
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emailError = "Enter your email"
        } else if !email.contains("@") {
            emailError = "Enter a valid email"
        } else {
            emailError = nil
        }
        return nameError == nil && emailError == nil
    }

    private func save() async {
        guard validate() else { return }
        let auth = container.authNotifier
        let ok = await auth.saveProfile(
            name: name,
            avatarBytes: pickedBytes,
            contentType: pickedContentType
        )
        if Task.isCancelled { return }
        if !ok {
            guard let error = container.authNotifier.state.error?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !error.isEmpty else { return }
            SnackBarCenter.shared.show(error, floating: true)
            return
        }
        SnackBarCenter.shared.show(LocaleKeys.profile_profile_updated.tr(), floating: true)
        await router.maybePop()
    }
}

/// A borderless field for a `FloatingLabelBox` — the box supplies the border,
/// radius and padding (`_innerDecoration`: dense, unfilled, no border, zero
/// content padding). The validator's message sits under the text, as an
/// `InputDecorator` lays out `errorText`.
private struct InnerField: View {
    @Binding var text: String
    let hint: String
    let errorText: String?
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .done

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "",
                text: $text,
                prompt: Text(hint)
                    .font(AppTypography.body(14).font)
                    .foregroundColor(AppColors.textPlaceholder)
            )
            .font(AppTypography.body(14, weight: .w600).font)
            .foregroundStyle(AppColors.textPrimary)
            .tint(AppColors.primary)
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(submitLabel)
            if let errorText {
                Text(errorText)
                    .textStyle(AppTypography.bodySmall.copyWith(color: AppColors.error))
                    .padding(.top, 4)
            }
        }
    }
}

/// A rounded, bordered input box with an uppercase caption floating on its top
/// border — the label's surface background notches the border, matching the
/// search form's field design. `readOnly` adds a subtle grey fill.
private struct FloatingLabelBox<Child: View>: View {
    let label: String
    var readOnly = false
    @ViewBuilder let child: () -> Child

    var body: some View {
        child()
            // EdgeInsets.symmetric(14, 15) plus the 1pt border.
            .padding(horizontal: 15, vertical: 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .boxDecoration(
                color: readOnly ? AppColors.background : AppColors.surface,
                radius: 14,
                borderColor: AppColors.border
            )
            .padding(.top, 7)
            .overlay(alignment: .topLeading) {
                Text(label.uppercased())
                    .textStyle(AppTypography.body(11.5, weight: .w400, color: AppColors.textPrimary, letterSpacing: 0.5))
                    .padding(.horizontal, 4)
                    .background(AppColors.surface)
                    .padding(.leading, 12)
            }
    }
}

/// The value row for a read-only `FloatingLabelBox`: value text with a
/// trailing lock icon to signal it can't be edited.
private struct ReadOnlyValue: View {
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            Text(value)
                .textStyle(AppTypography.body(14, weight: .w600, color: AppColors.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
            Icon(Icons.lock_outline, size: 18, color: AppColors.textTertiary)
        }
    }
}

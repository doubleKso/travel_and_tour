import SwiftUI

/// Material `AppBar` as themed by `AppTheme.light`: 56pt tall, page-coloured,
/// start-aligned title in Inter 20 bold, back button when the route can pop.
///
/// Pages hide the system navigation bar (`RouteView` does it for every
/// route) and draw this instead, so headers look exactly like the Flutter app.
///
/// ```swift
/// // Scaffold(appBar: AppBar(title: Text(LocaleKeys.profile_language.tr())), body: …)
/// Scaffold(appBar: AppBar(title: LocaleKeys.profile_language.tr())) { … }
/// ```
struct AppBar<Leading: View, Actions: View, TitleView: View>: View {
    var backgroundColor: Color = AppColors.background
    var foregroundColor: Color = AppColors.textPrimary
    var centerTitle = false
    var automaticallyImplyLeading = true
    var titleStyle: TextStyle = AppTypography.heading(20)
    var height: CGFloat = AppTheme.toolbarHeight
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var title: () -> TitleView

    @Environment(AppRouter.self) var router

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if Leading.self != EmptyView.self {
                    leading()
                } else if automaticallyImplyLeading && router.canPop {
                    BackButton(color: foregroundColor)
                } else {
                    HGap(16)
                }
                if !centerTitle {
                    title()
                        .textStyle(titleStyle.copyWith(color: foregroundColor))
                        .lineLimit(1)
                        .padding(.leading, (Leading.self == EmptyView.self && !(automaticallyImplyLeading && router.canPop)) ? 0 : 4)
                }
                Spacer(minLength: 0)
                HStack(spacing: 0) { actions() }
                    .foregroundStyle(foregroundColor)
            }
            if centerTitle {
                title()
                    .textStyle(titleStyle.copyWith(color: foregroundColor))
                    .lineLimit(1)
                    .padding(.horizontal, 72)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(backgroundColor.ignoresSafeArea(edges: .top))
    }
}

extension AppBar where Leading == EmptyView, Actions == EmptyView, TitleView == Text {
    init(
        title: String,
        backgroundColor: Color = AppColors.background,
        foregroundColor: Color = AppColors.textPrimary,
        centerTitle: Bool = false,
        automaticallyImplyLeading: Bool = true
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.centerTitle = centerTitle
        self.automaticallyImplyLeading = automaticallyImplyLeading
        self.leading = { EmptyView() }
        self.actions = { EmptyView() }
        self.title = { Text(title) }
    }
}

extension AppBar where Leading == EmptyView, TitleView == Text {
    init(
        title: String,
        backgroundColor: Color = AppColors.background,
        foregroundColor: Color = AppColors.textPrimary,
        centerTitle: Bool = false,
        automaticallyImplyLeading: Bool = true,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.centerTitle = centerTitle
        self.automaticallyImplyLeading = automaticallyImplyLeading
        self.leading = { EmptyView() }
        self.actions = actions
        self.title = { Text(title) }
    }
}

/// Flutter's `BackButton` on iOS: the rounded chevron, popping through
/// `router.maybePop()` so a page's `popScope` can veto it.
struct BackButton: View {
    var color: Color = AppColors.textPrimary
    var onPressed: (() -> Void)? = nil

    @Environment(AppRouter.self) var router

    var body: some View {
        Button {
            if let onPressed { onPressed() } else { Task { await router.maybePop() } }
        } label: {
            Icon(Icons.arrow_back_ios_new_rounded, size: 24, color: color)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .padding(.leading, 4)
        .accessibilityLabel("Back")
    }
}

/// Flutter's `Scaffold`: page background, optional app bar on top, optional
/// bottom bar, body in between.
struct Scaffold<Bar: View, Content: View, Bottom: View>: View {
    var backgroundColor: Color = AppColors.background
    @ViewBuilder var appBar: () -> Bar
    @ViewBuilder var bottomNavigationBar: () -> Bottom
    @ViewBuilder var content: () -> Content

    init(
        backgroundColor: Color = AppColors.background,
        @ViewBuilder appBar: @escaping () -> Bar,
        @ViewBuilder bottomNavigationBar: @escaping () -> Bottom,
        @ViewBuilder body: @escaping () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.appBar = appBar
        self.bottomNavigationBar = bottomNavigationBar
        self.content = body
    }

    var body: some View {
        VStack(spacing: 0) {
            appBar()
            content().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            bottomNavigationBar()
        }
        .background(backgroundColor.ignoresSafeArea())
    }
}

extension Scaffold where Bottom == EmptyView {
    init(
        backgroundColor: Color = AppColors.background,
        @ViewBuilder appBar: @escaping () -> Bar,
        @ViewBuilder body: @escaping () -> Content
    ) {
        self.init(backgroundColor: backgroundColor, appBar: appBar, bottomNavigationBar: { EmptyView() }, body: body)
    }
}

extension Scaffold where Bar == EmptyView, Bottom == EmptyView {
    init(backgroundColor: Color = AppColors.background, @ViewBuilder body: @escaping () -> Content) {
        self.init(backgroundColor: backgroundColor, appBar: { EmptyView() }, bottomNavigationBar: { EmptyView() }, body: body)
    }
}

extension Scaffold where Bottom == EmptyView, Bar == AppBar<EmptyView, EmptyView, Text> {
    /// `Scaffold(appBar: AppBar(title: Text(title)), body: …)`.
    init(title: String, backgroundColor: Color = AppColors.background, @ViewBuilder body: @escaping () -> Content) {
        self.init(backgroundColor: backgroundColor, appBar: { AppBar(title: title) }, bottomNavigationBar: { EmptyView() }, body: body)
    }
}

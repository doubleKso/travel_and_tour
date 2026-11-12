import SwiftUI

/// App shell with the bottom navigation bar: Home · Member · History · About ·
/// Profile/Login — the port of lib/app/shell/main_shell_page.dart.
///
/// Tabs stay alive once visited (Flutter's `IndexedStack`), so each keeps its
/// scroll position and state. The last tab is auth-aware: it reads "Login"
/// (and opens the login flow as a route) until the user signs in, then
/// becomes "Profile".
struct MainShellPage: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    /// Building every tab at launch would make Welcome → Home needlessly
    /// build network-backed pages that are not yet visible.
    @State private var visitedTabs: Set<Int> = [0]

    /// The redesigned V2 shell (V2 home + About tab) is the app's home for
    /// every state.
    private let showV2 = true

    var body: some View {
        let isAuthed = container.authNotifier.state.isAuthenticated
        let index = container.mainShellTab.value

        VStack(spacing: 0) {
            ZStack {
                tab(0, index) { HomePageV2() }
                if visitedTabs.contains(1) { tab(1, index) { MemberPage(onBack: goHome) } }
                if visitedTabs.contains(2) { tab(2, index) { HistoryPage(onBack: goHome) } }
                if visitedTabs.contains(3) { tab(3, index) { ProfilePage(onBack: goHome) } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar(index: index, isAuthed: isAuthed)
        }
        .background(AppColors.background.ignoresSafeArea())
        // Start both account reward calls as soon as authentication succeeds,
        // including while Login is covering this shell.
        .task(id: isAuthed) {
            guard isAuthed else { return }
            container.discountTierList.startIfNeeded()
            container.myPoints.startIfNeeded()
        }
        // If the user logs out on the Profile tab, fall back to Home rather
        // than stranding them on a signed-out profile page.
        .onChange(of: isAuthed) { _, authed in
            if !authed && container.mainShellTab.value == 3 {
                container.mainShellTab.value = 0
            }
        }
        // A flow can select a tab directly (`mainShellTab.value = 2`).
        .onChange(of: index) { _, newIndex in visitedTabs.insert(newIndex) }
    }

    private func goHome() { container.mainShellTab.value = 0 }

    @ViewBuilder
    private func tab<Content: View>(_ i: Int, _ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(index == i ? 1 : 0)
            .allowsHitTesting(index == i)
            .accessibilityHidden(index != i)
    }

    private func onNavTap(_ i: Int, isAuthed: Bool) {
        // About (v2 only) is an extra tab that opens as a route.
        if showV2 && i == 4 {
            router.push(.about)
            return
        }
        // The Profile tab is "Login" until the user authenticates.
        if i == 3 && !isAuthed {
            router.push(.login())
            return
        }
        visitedTabs.insert(i)
        container.mainShellTab.value = i
    }

    private func bottomBar(index: Int, isAuthed: Bool) -> some View {
        HStack(spacing: 0) {
            navItem(selected: index == 0, icon: Icons.home_outlined, activeIcon: Icons.home_rounded,
                    label: LocaleKeys.common_home.tr()) { onNavTap(0, isAuthed: isAuthed) }
            navItem(selected: index == 1, icon: Icons.workspace_premium_outlined, activeIcon: Icons.workspace_premium,
                    label: LocaleKeys.common_member.tr()) { onNavTap(1, isAuthed: isAuthed) }
            navItem(selected: index == 2, icon: Icons.history_outlined, activeIcon: Icons.history,
                    label: LocaleKeys.common_history.tr()) { onNavTap(2, isAuthed: isAuthed) }
            if showV2 {
                navItem(selected: false, icon: Icons.info_outline, activeIcon: Icons.info,
                        label: LocaleKeys.common_about.tr()) { onNavTap(4, isAuthed: isAuthed) }
            }
            navItem(selected: index == 3,
                    icon: isAuthed ? Icons.person_outline_rounded : Icons.login_rounded,
                    activeIcon: Icons.person_rounded,
                    label: isAuthed ? "Profile" : "Login") { onNavTap(3, isAuthed: isAuthed) }
        }
        .padding(.horizontal, 8)
        .frame(height: 62)
        .background(
            AppColors.surface
                // Hairline separator over a soft top shadow.
                .overlay(alignment: .top) { Rectangle().fill(AppColors.divider).frame(height: 1) }
                .shadow(color: Colors.black.withValues(alpha: 0.05), radius: 8, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// A single bottom-nav item: icon over label, tightly stacked and centred.
    private func navItem(selected: Bool, icon: IconData, activeIcon: IconData, label: String, onTap: @escaping () -> Void) -> some View {
        let color = selected ? AppColors.primary : AppColors.textTertiary
        return Button(action: onTap) {
            VStack(spacing: 0) {
                Icon(selected ? activeIcon : icon, size: 25, color: color)
                VGap(4)
                Text(label)
                    .textStyle(AppTypography.body(11.5, weight: selected ? .w700 : .w500, color: color, height: 1.0, letterSpacing: 0.1))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(InkButtonStyle(cornerRadius: 40, highlight: AppColors.primary.withValues(alpha: 0.08)))
    }
}

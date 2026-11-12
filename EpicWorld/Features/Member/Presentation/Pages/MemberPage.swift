// Port of lib/features/member/presentation/pages/member_page.dart
import SwiftUI
import UIKit

/// `_ignoreMemberRefreshError(request)`.
@MainActor
private func ignoreMemberRefreshError(_ request: () async throws -> Void) async {
    do {
        try await request()
    } catch {
        // Providers expose their own error state; never leak it from onRefresh.
    }
}

/// `_refreshMemberData(ref)`.
@MainActor
private func refreshMemberData(_ container: AppContainer) async {
    // `authMe` is the source that persists the profile avatar for the whole
    // app. Refresh it alongside the member-specific data so a newly uploaded
    // photo is reflected on this card as well.
    container.discountTierList.invalidate()
    container.myPoints.invalidate()
    container.memberAccount.invalidate()
    container.myPointLedger.invalidate()
    container.membershipTierList.invalidate()
    container.memberTierBenefitList.invalidate()
    container.memberTierPerkList.invalidate()
    container.memberGlobalAirlineRateList.invalidate()
    container.memberTierAirlineRateList.invalidate()
    // `Future.wait([...])`.
    await withTaskGroup(of: Void.self) { group in
        group.addTask { @MainActor in
            await ignoreMemberRefreshError { _ = await container.authNotifier.refreshCurrentUser() }
        }
        group.addTask { @MainActor in
            await ignoreMemberRefreshError { _ = try await container.discountTierList.future }
        }
        group.addTask { @MainActor in
            await ignoreMemberRefreshError { _ = try await container.myPoints.future }
        }
        group.addTask { @MainActor in
            await ignoreMemberRefreshError { _ = try await container.memberAccount.future }
        }
        group.addTask { @MainActor in
            await ignoreMemberRefreshError { _ = try await container.myPointLedger.future }
        }
        group.addTask { @MainActor in
            await ignoreMemberRefreshError { _ = try await container.membershipTierList.future }
        }
        group.addTask { @MainActor in
            await ignoreMemberRefreshError { _ = try await container.memberTierBenefitList.future }
        }
        group.addTask { @MainActor in
            await ignoreMemberRefreshError { _ = try await container.memberTierPerkList.future }
        }
        group.addTask { @MainActor in
            await ignoreMemberRefreshError { _ = try await container.memberGlobalAirlineRateList.future }
        }
        group.addTask { @MainActor in
            await ignoreMemberRefreshError { _ = try await container.memberTierAirlineRateList.future }
        }
    }
}

/// MEMBER — the "Epic Member" tab (replaces the old Tickets tab).
///
/// Two faces, driven by `AuthState.isAuthenticated`:
///  • Signed out → a "Join Epic Member" hero prompting sign-in / register,
///    followed by the benefits pitch and the partner-brand perks.
///  • Signed in  → the member's tier card with a live progress bar toward the
///    next tier, the membership tiers, benefits and partner perks.
///
/// Both faces share the "Member Benefits" and "Perks from our partner brands"
/// sections at the bottom.
struct MemberPage: View {
    let onBack: (() -> Void)?

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    private func open(_ route: Route) {
        router.push(route)
    }

    var body: some View {
        let auth = container.authNotifier.state
        let isAuthed = auth.isAuthenticated
        let points = container.currentMemberPoints
        let tiers = container.membershipTierList.state
        let account: MemberAccount? = container.memberAccount.state.valueOrNull ?? nil
        // The authenticated user is restored from local preferences, populated
        // from `/authMe`. Prefer it so the photo displays before (and even if)
        // the separate member `GetMe` request finishes.
        let avatarUrl = memberAvatarUrl(auth.user?.avatarUrl, account?.avatarUrl)
        let username: String? = auth.username

        Scaffold(backgroundColor: AppColors.surface, appBar: { appBar }) {
            ScrollView {
                VStack(spacing: 0) {
                    VGap(AppSpacing.lg)

                    // Top card differs by auth state.
                    topCard(
                        isAuthed: isAuthed,
                        tiers: tiers,
                        account: account,
                        points: points,
                        username: username,
                        avatarUrl: avatarUrl
                    )
                    .padding(.horizontal, AppSpacing.screenH)

                    // Membership tiers only make sense to a signed-in member comparing
                    // where they are against where they could go.
                    if isAuthed {
                        VGap(AppSpacing.section)
                        tiersBlock(tiers: tiers, account: account, points: points)
                    }

                    VGap(AppSpacing.section)
                    TierPerksSection()

                    VGap(AppSpacing.section)
                    BenefitsSection()

                    VGap(AppSpacing.section)
                    AirlineRatesSection()

                    VGap(AppSpacing.section)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { await refreshMemberData(container) }
        }
    }

    private var appBar: some View {
        AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            centerTitle: true,
            titleStyle: AppTypography.heading(20, color: Colors.white),
            leading: {
                Button {
                    if let onBack {
                        onBack()
                    } else {
                        Task { await router.maybePop() }
                    }
                } label: {
                    Icon(Icons.arrow_back, size: 24, color: Colors.white)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            },
            actions: { EmptyView() },
            title: { Text(LocaleKeys.member_epic_member.tr()) }
        )
    }

    private func topCard(
        isAuthed: Bool,
        tiers: AsyncValue<[MembershipTierData]>,
        account: MemberAccount?,
        points: Int,
        username: String?,
        avatarUrl: String
    ) -> AnyView {
        guard isAuthed else {
            return AnyView(JoinHero(
                onSignIn: { open(.login()) },
                onRegister: { open(.signUp) }
            ))
        }
        return tiers.when(
            data: { items -> AnyView in
                guard let tier = tierForMember(
                    reportedTier: account?.tier ?? "",
                    points: points,
                    tiers: items
                ) else {
                    return AnyView(MemberDataMessage(message: "No membership tiers are available."))
                }
                return AnyView(MemberStatusCard(
                    username: memberName(account, username),
                    points: points,
                    lifetimePoints: account?.lifetimePoints ?? points,
                    avatarUrl: avatarUrl,
                    tier: tier,
                    tiers: items
                ))
            },
            error: { _ -> AnyView in
                AnyView(MemberDataMessage(
                    message: "Unable to load membership tiers.",
                    onRetry: { container.membershipTierList.invalidate() }
                ))
            },
            loading: { () -> AnyView in
                AnyView(MemberDataMessage(message: "Loading your membership status…"))
            }
        )
    }

    private func tiersBlock(
        tiers: AsyncValue<[MembershipTierData]>,
        account: MemberAccount?,
        points: Int
    ) -> AnyView {
        tiers.when(
            data: { items -> AnyView in
                guard let currentTier = tierForMember(
                    reportedTier: account?.tier ?? "",
                    points: points,
                    tiers: items
                ) else {
                    return AnyView(MemberDataMessage(message: "No membership tiers are available."))
                }
                return AnyView(TiersSection(currentTier: currentTier, tiers: items))
            },
            error: { _ -> AnyView in
                AnyView(MemberDataMessage(
                    message: "Unable to load membership tiers.",
                    onRetry: { container.membershipTierList.invalidate() }
                ))
            },
            loading: { () -> AnyView in
                AnyView(MemberDataMessage(message: "Loading membership tiers…"))
            }
        )
    }
}

private func memberName(_ account: MemberAccount?, _ fallback: String?) -> String {
    let name = account?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !name.isEmpty { return name }
    let trimmedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !trimmedFallback.isEmpty ? trimmedFallback : "Member"
}

/// Resolves the photo stored from `/authMe`, falling back to the member
/// profile response for older sessions that have not received it yet.
private func memberAvatarUrl(_ savedAvatarUrl: String?, _ memberAvatarUrl: String?) -> String {
    let saved = savedAvatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !saved.isEmpty ? saved : (memberAvatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
}

/// Dart's `double.toStringAsFixed(0)` (halves round away from zero).
private func memberAsFixed0(_ value: Double) -> String {
    guard value.isFinite else { return value.isNaN ? "NaN" : (value < 0 ? "-Infinity" : "Infinity") }
    return String(format: "%.0f", value.rounded(.toNearestOrAwayFromZero))
}

/// `Center(child: CircularProgressIndicator())`.
private struct MemberSpinner: View {
    var body: some View {
        ProgressView()
            .tint(AppColors.primary)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
    }
}

// ===========================================================================
// Signed-out: "Join Epic Member" hero
// ===========================================================================
private struct JoinHero: View {
    let onSignIn: () -> Void
    let onRegister: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 3D price icon + a "members love it" rating pill.
            HStack(alignment: .top, spacing: 0) {
                Price3dIcon()
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Icon(Icons.star_rounded, size: 15, color: Colors.white)
                    HGap(4)
                    Text("4.9")
                        .textStyle(AppTypography.body(12.5, weight: .w800, color: Colors.white))
                    Text(LocaleKeys.member_members_love_it.tr())
                        .textStyle(AppTypography.body(
                            11.5,
                            weight: .w600,
                            color: Colors.white.withValues(alpha: 0.92)
                        ))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .boxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFFBD68C), Color(0xFFE8A33D)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    radius: 30,
                    shadows: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 10, offset: Offset(0, 4))]
                )
            }
            VGap(22)
            Text(LocaleKeys.member_join_epic_member.tr())
                .textStyle(AppTypography.heading(28, color: AppColors.textPrimary, height: 1.1))
            VGap(10)
            Text(LocaleKeys.member_unlock_member_only_fares_earn_points.tr())
                .textStyle(AppTypography.body(13.5, color: AppColors.textSecondary, height: 1.5))
            VGap(22)

            // Primary CTA — Sign In (brand green gradient).
            FilledGradientButton(
                label: LocaleKeys.common_sign_in.tr(),
                icon: Icons.login_rounded,
                onTap: onSignIn
            )
            VGap(12)

            // Secondary CTA — Register (outlined green).
            Button(action: onRegister) {
                HStack(spacing: 0) {
                    Icon(Icons.person_add_alt_1_rounded, size: 18)
                    HGap(8)
                    Text(LocaleKeys.member_create_account.tr())
                }
            }
            .buttonStyle(OutlinedButtonStyle(
                foregroundColor: AppColors.primary,
                borderColor: AppColors.primary,
                borderWidth: 1.4,
                cornerRadius: 16,
                padding: EdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0),
                textStyle: AppTypography.body(15, weight: .w700)
            ))
            VGap(18)

            // Social proof — avatar stack + member count.
            HStack(spacing: 0) {
                AvatarStack()
                HGap(12)
                (Text("12,000+ ").styled(AppTypography.body(12.5, weight: .w800, color: AppColors.textPrimary))
                    + Text("members already saving").styled(AppTypography.body(12.5, color: AppColors.textSecondary)))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .padding(1) // the 1pt border insets the Container's child
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            // Soft amber wash behind the 3D icon, top-right corner.
            Circle()
                .fill(RadialGradient(
                    colors: [
                        AppColors.accent.withValues(alpha: 0.16),
                        AppColors.accent.withValues(alpha: 0.0),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 95
                ))
                .frame(width: 190, height: 190)
                .offset(x: 60, y: -70)
        }
        .boxDecoration(
            color: AppColors.surface,
            radius: 28,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 24, offset: Offset(0, 12))]
        )
    }
}

/// A 3D-style membership trophy — a gold cup on a purple pedestal with a gold
/// plaque, echoing the reference 3D icon. Built in code since the project ships
/// no 3D asset; swap for an `AppImage(...)` if a real 3D PNG is added.
private struct Price3dIcon: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // Purple pedestal base with a gold plaque.
            Color.clear
                .frame(width: 22, height: 9)
                .boxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFFBD68C), Color(0xFFE8A33D)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    radius: 3
                )
                .frame(width: 62, height: 24)
                .boxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF9E72AB), Color(0xFF784E86)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    radius: 8,
                    shadows: [BoxShadow(color: Color(0xFF784E86).withValues(alpha: 0.45), blurRadius: 14, offset: Offset(0, 7))]
                )
            // Gold trophy cup sitting on the pedestal.
            LinearGradient(
                colors: [Color(0xFFFCE293), Color(0xFFE79A22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 60, height: 60)
            .mask(Icon(Icons.emoji_events_rounded, size: 60, color: Colors.white))
            .padding(.bottom, 13)
        }
        .frame(width: 76, height: 80, alignment: .bottom)
    }
}

/// Full-width brand-green gradient CTA.
private struct FilledGradientButton: View {
    let label: String
    let icon: IconData
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Icon(icon, size: 18, color: Colors.white)
                HGap(8)
                Text(label)
                    .textStyle(AppTypography.body(15.5, weight: .w800, color: Colors.white))
            }
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(InkButtonStyle(cornerRadius: 16))
        .boxDecoration(
            gradient: AppColors.primaryGradient,
            radius: 16,
            shadows: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 16, offset: Offset(0, 8))]
        )
    }
}

/// Overlapping real member photos hinting at a community of members.
private struct AvatarStack: View {
    private static let urls = [
        "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop",
        "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop",
        "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop",
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<Self.urls.count, id: \.self) { i in
                // 32pt circle with a 2pt surface ring; the ring insets the photo.
                NetworkImage(Self.urls[i], width: 28, height: 28, fit: .cover) {
                    AppColors.primarySurface
                } error: {
                    AppColors.primarySurface
                        .overlay { Icon(Icons.person_rounded, size: 16, color: AppColors.textTertiary) }
                }
                .clipShape(Circle())
                .padding(2)
                .boxDecoration(
                    circle: true,
                    borderColor: AppColors.surface,
                    borderWidth: 2,
                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                )
                .padding(.leading, CGFloat(i) * 22)
            }
        }
        .frame(width: 76, height: 32, alignment: .topLeading)
    }
}

// ===========================================================================
// Signed-in: member status card with points balance + progress to next tier
// ===========================================================================
private struct MemberStatusCard: View {
    let username: String
    let points: Int
    let lifetimePoints: Int
    let avatarUrl: String
    let tier: MembershipTierData
    let tiers: [MembershipTierData]

    /// The next tier, plus the fraction of the way from this tier's floor to
    /// the next tier's floor and the points still missing.
    private var progressToNext: (next: MembershipTierData?, progress: Double, remaining: Int) {
        guard let next = nextLiveTierAfter(tier, tiers) else { return (nil, 1, 0) }
        let span = next.requiredPoints - tier.requiredPoints
        let gained = min(max(points - tier.requiredPoints, 0), span)
        let progress: Double = span == 0 ? 1 : Double(gained) / Double(span)
        let remaining = min(max(next.requiredPoints - points, 0), next.requiredPoints)
        return (next, progress, remaining)
    }

    var body: some View {
        let info = progressToNext

        VStack(alignment: .leading, spacing: 0) {
            // Identity — avatar with a tier badge, name and tier pill.
            HStack(spacing: 0) {
                AvatarWithTierBadge(tier: tier, avatarUrl: avatarUrl)
                HGap(14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(username)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textStyle(AppTypography.heading(22, color: Colors.white))
                    VGap(6)
                    TierPill(tier: tier)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VGap(20)

            // Points balance tile.
            HStack(spacing: 0) {
                Icon(Icons.star_rounded, size: 26, color: Colors.white)
                    .frame(width: 46, height: 46)
                    .boxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFFFBD68C), AppColors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        radius: 14,
                        shadows: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 10, offset: Offset(0, 4))]
                    )
                HGap(14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Formatters.grouped(points))
                        .textStyle(AppTypography.heading(28, color: Colors.white, height: 1.1))
                    VGap(2)
                    Text(LocaleKeys.member_points_balance.tr())
                        .textStyle(AppTypography.body(
                            10.5,
                            weight: .w800,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 1.2
                        ))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .padding(1) // border inset
            .frame(maxWidth: .infinity)
            .boxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                radius: 18,
                borderColor: Colors.white.withValues(alpha: 0.22)
            )
            VGap(18)

            Text("Lifetime points: \(Formatters.grouped(lifetimePoints))")
                .textStyle(AppTypography.body(12, weight: .w700, color: Colors.white.withValues(alpha: 0.82)))
            VGap(18)

            // Progress toward the next tier.
            if let next = info.next {
                HStack(spacing: 0) {
                    TierMarker(tier: tier)
                    Spacer(minLength: 0)
                    TierMarker(tier: next, dotTrailing: true)
                }
                VGap(8)
                ProgressBar(value: info.progress)
                VGap(8)
                (Text("\(Formatters.grouped(info.remaining)) points")
                    .styled(AppTypography.body(12.5, weight: .w800, color: Colors.white))
                    + Text(" to ")
                    .styled(AppTypography.body(12.5, color: Colors.white.withValues(alpha: 0.82)))
                    + Text(next.name)
                    .styled(AppTypography.body(12.5, weight: .w800, color: Colors.white)))
            } else {
                ProgressBar(value: 1)
                VGap(8)
                Text("You've reached our top tier — enjoy every perk 🎉")
                    .textStyle(AppTypography.body(12.5, weight: .w600, color: Colors.white.withValues(alpha: 0.9)))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            // Faint tier watermark.
            Icon(tier.icon, size: 118, color: Colors.white.withValues(alpha: 0.08))
                .offset(x: 14, y: -6)
        }
        .background(alignment: .bottomTrailing) {
            // Soft decorative glow for a modern, clean loyalty-card feel.
            GlowCircle(size: 150, color: Colors.black.withValues(alpha: 0.08))
                .offset(x: -46, y: 74)
        }
        .boxDecoration(
            gradient: LinearGradient(
                stops: [
                    .init(color: AppColors.primaryLight, location: 0.0),
                    .init(color: AppColors.primary, location: 0.55),
                    .init(color: AppColors.primaryDark, location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            radius: 26,
            shadows: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.38), blurRadius: 26, offset: Offset(0, 14))]
        )
    }
}

/// The member photo with a small tier-coloured badge tucked into its corner.
private struct AvatarWithTierBadge: View {
    let tier: MembershipTierData
    let avatarUrl: String

    var body: some View {
        let url = avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        ZStack(alignment: .topLeading) {
            // CircleAvatar(radius: 25, backgroundColor: Colors.white, backgroundImage: …)
            Group {
                if url.isEmpty {
                    AppImage(AppAssets.profilePlaceholder, width: 50, height: 50, fit: .cover)
                } else {
                    NetworkImage(url, width: 50, height: 50, fit: .cover) {
                        Colors.white
                    } error: {
                        Colors.white
                    }
                }
            }
            .background(Circle().fill(Colors.white))
            .clipShape(Circle())
            .padding(2.5)
            .padding(2) // the 2pt border insets the Container's child
            .boxDecoration(
                circle: true,
                borderColor: Colors.white.withValues(alpha: 0.55),
                borderWidth: 2
            )
        }
        .frame(width: 60, height: 60, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            Icon(tier.icon, size: 12, color: Colors.white)
                .frame(width: 24, height: 24)
                .boxDecoration(
                    gradient: LinearGradient(colors: tier.gradient, startPoint: .leading, endPoint: .trailing),
                    circle: true,
                    borderColor: Colors.white,
                    borderWidth: 2
                )
                .offset(x: 2, y: 2)
        }
    }
}

/// "Silver member" pill sitting under the name on the status card.
private struct TierPill: View {
    let tier: MembershipTierData

    var body: some View {
        HStack(spacing: 0) {
            Icon(tier.icon, size: 14, color: Colors.white)
            HGap(5)
            Text(LocaleKeys.member_member.tr(args: [tier.name]))
                .textStyle(AppTypography.body(12, weight: .w700, color: Colors.white))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .padding(1) // border inset
        .boxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            radius: 30,
            borderColor: Colors.white.withValues(alpha: 0.3)
        )
    }
}

/// A "● Silver" / "Gold ●" end label on the tier progress bar.
private struct TierMarker: View {
    let tier: MembershipTierData

    /// Puts the dot after the label (used for the right-hand, next-tier end).
    var dotTrailing = false

    var body: some View {
        HStack(spacing: 0) {
            if dotTrailing {
                label
                HGap(6)
                dot
            } else {
                dot
                HGap(6)
                label
            }
        }
    }

    private var dot: some View {
        Circle()
            .fill(Colors.white.withValues(alpha: dotTrailing ? 1 : 0.75))
            .frame(width: 8, height: 8)
    }

    private var label: some View {
        Text(tier.name)
            .textStyle(AppTypography.body(
                12,
                weight: .w700,
                color: Colors.white.withValues(alpha: dotTrailing ? 1 : 0.85)
            ))
    }
}

/// Soft translucent circle used as a decorative glow on the member card.
private struct GlowCircle: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

/// Rounded, white-on-translucent progress bar used inside the member card.
private struct ProgressBar: View {
    let value: Double // 0..1

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Colors.white.withValues(alpha: 0.25)
                Color.clear
                    .frame(width: proxy.size.width * CGFloat(min(max(value, 0), 1)))
                    .boxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFFFFE3AE), AppColors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        radius: 10,
                        shadows: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 6)]
                    )
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct MemberDataMessage: View {
    let message: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Text(message)
                .multilineTextAlignment(.center)
                .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
            if let onRetry {
                VGap(8)
                Button("Retry", action: onRetry)
                    .buttonStyle(TextButtonStyle())
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .boxDecoration(color: AppColors.primarySurface, radius: 20)
    }
}

// ===========================================================================
// Membership Tiers (signed-in only)
// ===========================================================================
private struct TiersSection: View {
    let currentTier: MembershipTierData
    let tiers: [MembershipTierData]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(
                eyebrow: "THE MORE YOU TRAVEL, THE MORE YOU EARN",
                titleDark: "Membership ",
                titleAccent: "Tiers",
                subtitle:
                    "Every booking earns points that move you up the tiers. The "
                    + "higher your tier, the bigger your discounts, perks and "
                    + "priority — and your status never expires.",
                align: .center
            )
            .padding(.horizontal, AppSpacing.screenH)
            VGap(AppSpacing.lg)
            // Horizontal `ListView.separated` (height 288, 12pt vertical
            // padding, so each card is 264 tall), unclipped.
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(Array(tiers.enumerated()), id: \.offset) { _, tier in
                        TierCard(tier: tier, isCurrent: tier == currentTier)
                            .frame(height: 288 - 24)
                    }
                }
                .padding(.horizontal, AppSpacing.screenH)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .frame(height: 288)
        }
    }
}

private struct TierCard: View {
    let tier: MembershipTierData
    let isCurrent: Bool

    var body: some View {
        let popular = tier.isPopular
        // A tier is emphasised if it's the marketing "most popular" plan or the
        // member's own current tier — both get the coloured border treatment.
        let highlighted = popular || isCurrent

        // Float a "MOST POPULAR" (or "CURRENT PLAN") pill above emphasised cards.
        if highlighted {
            card(highlighted: true)
                .overlay(alignment: .top) {
                    ribbon(popular ? "MOST POPULAR" : "CURRENT PLAN")
                        .offset(y: -12)
                }
        } else {
            card(highlighted: false)
        }
    }

    private func card(highlighted: Bool) -> some View {
        VStack(spacing: 0) {
            // Coloured accent bar across the top of the card.
            Color.clear
                .frame(height: 6)
                .frame(maxWidth: .infinity)
                .boxDecoration(
                    gradient: LinearGradient(colors: tier.gradient, startPoint: .leading, endPoint: .trailing),
                    corners: BorderRadius.vertical(top: 20)
                )
            VStack(spacing: 0) {
                // Tier icon on its identity-coloured tile.
                Icon(tier.icon, size: 32, color: Colors.white)
                    .frame(width: 64, height: 64)
                    .boxDecoration(
                        gradient: LinearGradient(
                            colors: tier.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        radius: 18,
                        shadows: [BoxShadow(color: tier.accent.withValues(alpha: 0.35), blurRadius: 12, offset: Offset(0, 6))]
                    )
                VGap(14)
                Text(tier.name)
                    .textStyle(AppTypography.heading(20, color: AppColors.textPrimary))
                VGap(10)
                // Points threshold pill.
                HStack(spacing: 0) {
                    Icon(Icons.star_rounded, size: 13, color: tier.accent)
                    HGap(5)
                    Text(LocaleKeys.member_points.tr(args: [Formatters.grouped(tier.requiredPoints)]))
                        .lineLimit(1)
                        // FittedBox(fit: BoxFit.scaleDown).
                        .minimumScaleFactor(0.5)
                        .textStyle(AppTypography.body(11.5, weight: .w800, color: tier.accent))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .boxDecoration(color: tier.accent.withValues(alpha: 0.12), radius: 30)
                VGap(14)
                MaterialDivider(height: 1, color: AppColors.divider)
                VGap(14)
                Text(tier.tagline)
                    .multilineTextAlignment(.center)
                    .textStyle(AppTypography.body(13, color: AppColors.textSecondary, height: 1.45))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(18, 20, 18, 18)
            .frame(maxHeight: .infinity)
        }
        .padding(highlighted ? 2 : 1) // the border insets the Container's child
        .frame(width: 214)
        .frame(maxHeight: .infinity)
        .boxDecoration(
            color: AppColors.surface,
            radius: 22,
            borderColor: highlighted ? tier.accent : AppColors.border,
            borderWidth: highlighted ? 2 : 1,
            shadows: [
                BoxShadow(
                    color: highlighted
                        ? tier.accent.withValues(alpha: 0.20)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: highlighted ? 22 : 14,
                    offset: Offset(0, 10)
                ),
            ]
        )
    }

    private func ribbon(_ ribbonText: String) -> some View {
        Text(ribbonText)
            .lineLimit(1)
            .textStyle(AppTypography.body(9.5, weight: .w800, color: Colors.white, letterSpacing: 0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .boxDecoration(
                gradient: LinearGradient(colors: tier.gradient, startPoint: .leading, endPoint: .trailing),
                radius: 30,
                shadows: [BoxShadow(color: tier.accent.withValues(alpha: 0.4), blurRadius: 10, offset: Offset(0, 4))]
            )
            .fixedSize()
    }
}

// ===========================================================================
// Tier perks
// ===========================================================================
private struct TierPerksSection: View {
    @Environment(AppContainer.self) private var container

    private static let accents: [Color] = [
        AppColors.primary,
        Color(0xFF5D913C),
        AppColors.violet,
        AppColors.accent,
    ]

    var body: some View {
        let perks = container.memberTierPerkList.state
        let auth = container.authNotifier.state
        let account: MemberAccount? = container.memberAccount.state.valueOrNull ?? nil
        let points = container.currentMemberPoints
        let tiers = container.membershipTierList.state.valueOrNull ?? []
        let currentTier: MembershipTierData? = auth.isAuthenticated
            ? tierForMember(reportedTier: account?.tier ?? "", points: points, tiers: tiers)
            : nil

        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(
                eyebrow: "PERKS OF MEMBERSHIP",
                titleDark: "Member ",
                titleAccent: "Benefits"
            )
            VGap(AppSpacing.lg)
            perks.when(
                data: { items -> AnyView in
                    let visibleItems = auth.isAuthenticated
                        ? perksForTier(items, currentTier?.id ?? "")
                        : items
                    if visibleItems.isEmpty {
                        return AnyView(
                            Text(auth.isAuthenticated
                                ? "No perks are available for your current tier."
                                : "No membership perks are available right now.")
                                .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                        )
                    }
                    return AnyView(
                        VStack(spacing: 0) {
                            ForEach(Array(visibleItems.enumerated()), id: \.offset) { i, perk in
                                TierPerkTile(
                                    perk: perk,
                                    color: Self.accents[i % Self.accents.count]
                                )
                                if i < visibleItems.count - 1 { VGap(12) }
                            }
                        }
                    )
                },
                error: { _ -> AnyView in
                    AnyView(Text("Unable to load membership perks.").textStyle(AppTypography.bodyMedium))
                },
                loading: { () -> AnyView in AnyView(MemberSpinner()) }
            )
        }
        .padding(AppSpacing.lg)
        .padding(1) // border inset
        .frame(maxWidth: .infinity, alignment: .leading)
        .boxDecoration(
            color: Color(0xFFF7FAF5),
            radius: 26,
            borderColor: AppColors.primary.withValues(alpha: 0.08)
        )
        .padding(.horizontal, AppSpacing.screenH)
    }
}

private struct TierPerkTile: View {
    let perk: TierPerkModel
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            Icon(perkIcon(perk.icon), size: 24, color: color)
                .frame(width: 50, height: 50)
                .boxDecoration(
                    color: color.withValues(alpha: 0.12),
                    radius: 15,
                    borderColor: color.withValues(alpha: 0.65)
                )
            HGap(14)
            VStack(alignment: .leading, spacing: 0) {
                Text(perk.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Member benefit" : perk.title)
                    .textStyle(AppTypography.heading(15.5))
                if !perk.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VGap(3)
                    Text(perk.detail)
                        .textStyle(AppTypography.body(13, color: AppColors.textSecondary, height: 1.35))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .boxDecoration(
            color: AppColors.surface,
            radius: 18,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: Offset(0, 6))]
        )
    }
}

private func perkIcon(_ icon: String) -> IconData {
    switch icon.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "ticket", "ticket_alt", "ticket_alt_rounded": return Icons.confirmation_number_outlined
    case "gift", "redeem": return Icons.card_giftcard_rounded
    case "support", "headset": return Icons.support_agent_rounded
    case "flight", "plane": return Icons.flight_rounded
    case "star", "premium": return Icons.workspace_premium_rounded
    default: return Icons.card_membership_rounded
    }
}

// ===========================================================================
// Percentage benefits (shared)
// ===========================================================================
private struct BenefitsSection: View {
    @Environment(AppContainer.self) private var container

    // A distinct accent per benefit so the list feels lively, not monotone.
    private static let accents: [Color] = [
        AppColors.primary,
        AppColors.accent,
        AppColors.violet,
        AppColors.teal,
    ]

    var body: some View {
        let benefits = container.memberTierBenefitList.state
        let auth = container.authNotifier.state
        let points = container.currentMemberPoints
        let account: MemberAccount? = container.memberAccount.state.valueOrNull ?? nil
        let tiers = container.membershipTierList.state.valueOrNull ?? []
        let tierNames = Self.tierNamesById(tiers)
        let currentTier: MembershipTierData? = auth.isAuthenticated
            ? tierForMember(reportedTier: account?.tier ?? "", points: points, tiers: tiers)
            : nil

        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(
                eyebrow: "MEMBER-ONLY SAVINGS",
                titleDark: "Savings by ",
                titleAccent: "service"
            )
            VGap(AppSpacing.lg)
            benefits.when(
                data: { items -> AnyView in
                    let visibleItems = auth.isAuthenticated
                        ? benefitsForTier(items, currentTier?.id ?? "")
                        : items
                    if visibleItems.isEmpty {
                        return AnyView(
                            Text(auth.isAuthenticated
                                ? "No benefits are available for your current tier."
                                : "No membership benefits are available right now.")
                                .textStyle(AppTypography.bodyMedium)
                        )
                    }
                    return AnyView(
                        VStack(spacing: 0) {
                            ForEach(Array(visibleItems.enumerated()), id: \.offset) { i, benefit in
                                BenefitTile(
                                    benefit: benefit,
                                    tierName: currentTier?.name
                                        ?? tierNames[benefit.tierId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
                                        ?? "member",
                                    color: Self.accents[i % Self.accents.count]
                                )
                                if i < visibleItems.count - 1 { VGap(12) }
                            }
                        }
                    )
                },
                error: { _ -> AnyView in
                    AnyView(Text("Unable to load membership benefits.").textStyle(AppTypography.bodyMedium))
                },
                loading: { () -> AnyView in AnyView(MemberSpinner()) }
            )
        }
        .padding(AppSpacing.lg)
        .padding(1) // border inset
        .frame(maxWidth: .infinity, alignment: .leading)
        .boxDecoration(
            color: Color(0xFFF7FAF5),
            radius: 26,
            borderColor: AppColors.primary.withValues(alpha: 0.08)
        )
        .padding(.horizontal, AppSpacing.screenH)
    }

    /// `{for (final tier in tiers) tier.id.trim().toLowerCase(): tier.name}`
    /// (a later duplicate id wins, as in a Dart map literal).
    private static func tierNamesById(_ tiers: [MembershipTierData]) -> [String: String] {
        var names: [String: String] = [:]
        for tier in tiers {
            names[tier.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = tier.name
        }
        return names
    }
}

/// A single, clean benefit tile — coloured icon chip + copy on a soft card.
private struct BenefitTile: View {
    let benefit: TierBenefitModel
    let tierName: String
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            Icon(serviceIcon(benefit.service), size: 24, color: color)
                .frame(width: 50, height: 50)
                .boxDecoration(color: color.withValues(alpha: 0.12), radius: 15)
            HGap(14)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(serviceLabel(benefit.service)) discount")
                    .textStyle(AppTypography.heading(15.5))
                VGap(3)
                Text(
                    "\(memberAsFixed0(benefit.discountPct))% off "
                        + "\(serviceLabel(benefit.service).lowercased()) for "
                        + "\(tierName) members."
                )
                .textStyle(AppTypography.body(13, color: AppColors.textSecondary, height: 1.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .boxDecoration(
            color: AppColors.surface,
            radius: 18,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: Offset(0, 6))]
        )
    }
}

private func serviceLabel(_ service: String) -> String {
    service.isEmpty ? "Service" : "\(service.prefix(1).uppercased())\(service.dropFirst())"
}

private func serviceIcon(_ service: String) -> IconData {
    switch service.lowercased() {
    case "flight": return Icons.flight_rounded
    case "visa": return Icons.badge_rounded
    case "tour": return Icons.map_rounded
    default: return Icons.workspace_premium_rounded
    }
}

private struct AirlineRatesSection: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        let global = container.memberGlobalAirlineRateList.state
        let tierRates = container.memberTierAirlineRateList.state
        let tiers = container.membershipTierList.state.valueOrNull ?? []
        let tierNames = Self.tierNamesById(tiers)

        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(
                eyebrow: "FLIGHT REWARDS",
                titleDark: "Airline ",
                titleAccent: "Rates"
            )
            VGap(AppSpacing.lg)
            global.when(
                data: { globalRates -> AnyView in
                    tierRates.when(
                        data: { tierItems -> AnyView in
                            if globalRates.isEmpty && tierItems.isEmpty {
                                return AnyView(
                                    Text("No airline rates are available right now.")
                                        .textStyle(AppTypography.bodyMedium)
                                )
                            }
                            return AnyView(
                                VStack(spacing: 0) {
                                    ForEach(Array(globalRates.enumerated()), id: \.offset) { _, rate in
                                        RateRow(
                                            label: "\(rate.carrierCode) · Global rate",
                                            percent: rate.ratePct
                                        )
                                    }
                                    ForEach(Array(tierItems.enumerated()), id: \.offset) { _, rate in
                                        RateRow(
                                            label: "\(rate.carrierCode) · \(tierNames[rate.tierId] ?? "Member") rate",
                                            percent: rate.ratePct
                                        )
                                    }
                                }
                            )
                        },
                        error: { _ -> AnyView in
                            AnyView(Text("Unable to load airline rates.").textStyle(AppTypography.bodyMedium))
                        },
                        loading: { () -> AnyView in AnyView(MemberSpinner()) }
                    )
                },
                error: { _ -> AnyView in
                    AnyView(Text("Unable to load airline rates.").textStyle(AppTypography.bodyMedium))
                },
                loading: { () -> AnyView in AnyView(MemberSpinner()) }
            )
        }
        .padding(AppSpacing.lg)
        .padding(1) // border inset
        .frame(maxWidth: .infinity, alignment: .leading)
        .boxDecoration(color: AppColors.surface, radius: 26, borderColor: AppColors.border)
        .padding(.horizontal, AppSpacing.screenH)
    }

    /// `{for (final tier in tiers) tier.id: tier.name}` (a later duplicate id
    /// wins, as in a Dart map literal).
    private static func tierNamesById(_ tiers: [MembershipTierData]) -> [String: String] {
        var names: [String: String] = [:]
        for tier in tiers { names[tier.id] = tier.name }
        return names
    }
}

private struct RateRow: View {
    let label: String
    let percent: Double

    var body: some View {
        HStack(spacing: 0) {
            Icon(Icons.flight_rounded, size: 18, color: AppColors.primary)
            HGap(10)
            Text(label)
                .textStyle(AppTypography.body(13))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(memberAsFixed0(percent))%")
                .textStyle(AppTypography.body(14, weight: .w800, color: AppColors.primary))
        }
        .padding(.vertical, 8)
    }
}

// ===========================================================================
// Perks from our partner brands (shared) — Gold & Diamond exclusive
// ===========================================================================
// No public partner-catalogue operation exists, so this legacy presentation
// component is intentionally not rendered while mock partner data is retired.
private struct PartnerPerksSection: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        let partners = container.memberPartnerList.state.valueOrNull ?? []

        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(
                eyebrow: "GOLD & DIAMOND EXCLUSIVE",
                titleDark: "Perks from our ",
                titleAccent: "partner brands",
                subtitle:
                    "Hotels, restaurants, spas and shops that give Epic Gold and "
                    + "Diamond members a member-only rate — on top of everything "
                    + "you already save on travel.",
                align: .center
            )
            .padding(.horizontal, AppSpacing.screenH)
            VGap(AppSpacing.lg)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(Array(partners.enumerated()), id: \.offset) { _, brand in
                        PartnerCard(brand: brand)
                            .frame(height: 336)
                    }
                }
                .padding(.horizontal, AppSpacing.screenH)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .frame(height: 336)
        }
    }
}

/// One partner brand — photo with a category pill and the brand pitch, its
/// per-tier savings, and the member code to quote at checkout.
private struct PartnerCard: View {
    /// The tap-to-copy member code chip is hidden on the partner cards. Flip
    /// this back to true to show (and copy) the code again.
    static let kShowCodeChip = false

    let brand: PartnerBrand

    private func copyCode() {
        UIPasteboard.general.string = brand.code
        SnackBarCenter.shared.show(
            LocaleKeys.member_code_copied.tr(args: [brand.code]),
            floating: true
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ---- Photo with the category pill and the brand pitch ----
            Color.clear
                .frame(height: 186)
                .frame(maxWidth: .infinity)
                .overlay {
                    GeometryReader { proxy in
                        NetworkImage(brand.imageUrl, width: proxy.size.width, height: proxy.size.height, fit: .cover) {
                            AppColors.primarySurface
                        } error: {
                            AppColors.primarySurface
                                .overlay { Icon(Icons.storefront_outlined, color: AppColors.textTertiary) }
                        }
                    }
                }
                .overlay {
                    // Bottom-up dark gradient for text legibility.
                    LinearGradient(
                        stops: [
                            .init(color: Color(0xF2000000), location: 0.05),
                            .init(color: Color(0x00000000), location: 0.75),
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                }
                .overlay(alignment: .topLeading) {
                    Text(brand.category.label)
                        .textStyle(AppTypography.body(10, weight: .w800, color: Colors.white, letterSpacing: 0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .boxDecoration(
                            color: brand.category.color,
                            radius: 30,
                            shadows: [BoxShadow(color: brand.category.color.withValues(alpha: 0.4), blurRadius: 8, offset: Offset(0, 3))]
                        )
                        .padding(.top, 12)
                        .padding(.leading, 12)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(brand.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .textStyle(AppTypography.heading(17, color: Colors.white))
                        VGap(5)
                        Text(brand.description)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .textStyle(AppTypography.body(
                                12.5,
                                color: Colors.white.withValues(alpha: 0.88),
                                height: 1.35
                            ))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .clipped()

            // ---- Per-tier savings, then the footnote + copyable member code ----
            // Expanded so every card fills the fixed carousel height and the
            // code row always sits flush with the bottom edge.
            VStack(spacing: 0) {
                ForEach(Array(brand.offers.enumerated()), id: \.offset) { i, offer in
                    PartnerOfferRow(offer: offer)
                    if i < brand.offers.count - 1 { VGap(10) }
                }
                Spacer(minLength: 0)
                MaterialDivider(height: 1, color: AppColors.divider)
                VGap(12)
                HStack(spacing: 0) {
                    Text(brand.footnote)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .textStyle(AppTypography.body(11.5, color: AppColors.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if Self.kShowCodeChip {
                        HGap(10)
                        CodeChip(code: brand.code, onTap: { copyCode() })
                    }
                }
            }
            .padding(16, 14, 16, 12)
            .frame(maxHeight: .infinity)
        }
        .padding(1) // border inset
        .frame(width: 304)
        .frame(maxHeight: .infinity)
        .boxDecoration(
            color: AppColors.surface,
            radius: 20,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: Offset(0, 8))]
        )
    }
}

/// "GOLD · 12% off room rates" row inside a partner card.
private struct PartnerOfferRow: View {
    let offer: PartnerOffer

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(offer.tier.label.uppercased())
                .textStyle(AppTypography.body(10.5, weight: .w800, color: offer.tier.accent, letterSpacing: 0.7))
                .frame(width: 68, alignment: .leading)
            Text(verbatim: "\(offer.percent)%")
                .textStyle(AppTypography.heading(19, color: AppColors.textPrimary))
            HGap(7)
            Text(offer.detail)
                .lineLimit(1)
                .truncationMode(.tail)
                .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The outlined, tap-to-copy member code chip on a partner card.
private struct CodeChip: View {
    let code: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Icon(Icons.copy_rounded, size: 13, color: AppColors.textSecondary)
                HGap(6)
                Text(code)
                    .textStyle(AppTypography.body(11, weight: .w800, color: AppColors.textSecondary, letterSpacing: 0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .padding(1) // border inset
            .boxDecoration(radius: 30, borderColor: AppColors.border)
        }
        .buttonStyle(InkButtonStyle(cornerRadius: 30))
    }
}

// ===========================================================================
// Shared: two-tone section heading with eyebrow + optional subtitle
// ===========================================================================
private struct SectionHeading: View {
    let eyebrow: String
    let titleDark: String
    let titleAccent: String
    var subtitle: String? = nil
    /// Dart's `CrossAxisAlignment align` (`start` / `center`).
    var align: HorizontalAlignment = .leading

    var body: some View {
        let centered = align == .center
        let textAlign: TextAlignment = centered ? .center : .leading

        VStack(alignment: align, spacing: 0) {
            Text(eyebrow)
                .multilineTextAlignment(textAlign)
                .textStyle(AppTypography.body(11.5, weight: .w800, color: AppColors.accent, letterSpacing: 1.4))
            VGap(6)
            (Text(titleDark).styled(AppTypography.heading(24, color: AppColors.textPrimary))
                + Text(titleAccent).styled(AppTypography.heading(24, color: AppColors.accent)))
                .multilineTextAlignment(textAlign)
            if let subtitle {
                VGap(8)
                Text(subtitle)
                    .multilineTextAlignment(textAlign)
                    .textStyle(AppTypography.body(13.5, color: AppColors.textSecondary, height: 1.45))
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

import SwiftUI

// Flutter layout idioms with exact SwiftUI equivalents, so pages port line by
// line. SwiftUI stacks add default spacing and Flutter's do not — always
// write `VStack(alignment: …, spacing: 0)` / `HStack(spacing: 0)` and spell
// gaps out with `Gap`, as the Dart code does with `SizedBox`.

/// `SizedBox(height: n)` in a Column / `SizedBox(width: n)` in a Row.
/// Takes `n` points along whichever axis the parent stack lays out.
struct Gap: View {
    let size: CGFloat
    init(_ size: CGFloat) { self.size = size }
    var body: some View { Color.clear.frame(width: size, height: size).layoutPriority(-1) }
}

/// `SizedBox(height: n)` — vertical only.
struct VGap: View {
    let height: CGFloat
    init(_ height: CGFloat) { self.height = height }
    var body: some View { Color.clear.frame(height: height) }
}

/// `SizedBox(width: n)` — horizontal only.
struct HGap: View {
    let width: CGFloat
    init(_ width: CGFloat) { self.width = width }
    var body: some View { Color.clear.frame(width: width) }
}

/// Flutter's `BoxShadow`. `blurRadius` is Flutter's value; `boxDecoration`
/// converts it to the Gaussian sigma Flutter uses.
struct BoxShadow: Equatable {
    var color: Color
    var blurRadius: CGFloat = 0
    var offset: CGSize = .zero
    var spreadRadius: CGFloat = 0

    init(color: Color, blurRadius: CGFloat = 0, offset: CGSize = .zero, spreadRadius: CGFloat = 0) {
        self.color = color
        self.blurRadius = blurRadius
        self.offset = offset
        self.spreadRadius = spreadRadius
    }
}

/// Flutter `Offset(dx, dy)` for shadows.
func Offset(_ dx: CGFloat, _ dy: CGFloat) -> CGSize { CGSize(width: dx, height: dy) }

/// Flutter's `BoxDecoration` for a `Container`.
///
/// ```swift
/// // Container(decoration: BoxDecoration(color: AppColors.surface,
/// //   borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border),
/// //   boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: Offset(0, 4))]))
/// content
///     .padding(16)
///     .boxDecoration(color: AppColors.surface, radius: 16, borderColor: AppColors.border,
///                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: Offset(0, 4))])
/// ```
struct BoxDecorationModifier: ViewModifier {
    var color: Color?
    var gradient: LinearGradient?
    var radius: CGFloat
    /// Per-corner radii (Flutter `BorderRadius.only` / `.vertical`).
    var corners: RectangleCornerRadii?
    var circle: Bool
    var borderColor: Color?
    var borderWidth: CGFloat
    var shadows: [BoxShadow]

    private var shape: AnyShape {
        if circle { return AnyShape(Circle()) }
        if let corners { return AnyShape(UnevenRoundedRectangle(cornerRadii: corners, style: .circular)) }
        return AnyShape(RoundedRectangle(cornerRadius: radius, style: .circular))
    }

    func body(content: Content) -> some View {
        content
            .background {
                if let gradient {
                    shape.fill(gradient)
                } else if let color {
                    shape.fill(color)
                }
            }
            .clipShape(shape)
            .overlay {
                if let borderColor, borderWidth > 0 {
                    shape.stroke(borderColor, lineWidth: borderWidth).padding(borderWidth / 2)
                }
            }
            .background {
                // Drawn outside the clip, like Flutter: the shape filled with
                // the shadow colour, grown by the spread, offset, then blurred
                // with Flutter's sigma (blurRadius · 0.57735 + 0.5).
                ZStack {
                    ForEach(Array(shadows.enumerated()), id: \.offset) { _, shadow in
                        shape
                            .fill(shadow.color)
                            .padding(-shadow.spreadRadius)
                            .offset(x: shadow.offset.width, y: shadow.offset.height)
                            .blur(radius: shadow.blurRadius > 0 ? shadow.blurRadius * 0.57735 + 0.5 : 0)
                    }
                }
                .allowsHitTesting(false)
            }
    }
}

extension View {
    /// A Flutter `Container(decoration: BoxDecoration(...))` around this view.
    /// Children are clipped to the shape, as Flutter does with `clipBehavior`.
    func boxDecoration(
        color: Color? = nil,
        gradient: LinearGradient? = nil,
        radius: CGFloat = 0,
        corners: RectangleCornerRadii? = nil,
        circle: Bool = false,
        borderColor: Color? = nil,
        borderWidth: CGFloat = 1,
        shadows: [BoxShadow] = []
    ) -> some View {
        modifier(BoxDecorationModifier(
            color: color,
            gradient: gradient,
            radius: radius,
            corners: corners,
            circle: circle,
            borderColor: borderColor,
            borderWidth: borderWidth,
            shadows: shadows
        ))
    }

    /// Applies `transform` only when `condition` holds.
    @ViewBuilder
    func `if`<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition { transform(self) } else { self }
    }

    /// Flutter `EdgeInsets.fromLTRB(l, t, r, b)`.
    func padding(_ left: CGFloat, _ top: CGFloat, _ right: CGFloat, _ bottom: CGFloat) -> some View {
        padding(EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right))
    }

    /// Flutter `EdgeInsets.symmetric(horizontal: h, vertical: v)`.
    func padding(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> some View {
        padding(EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal))
    }

    /// `Expanded` inside a Row/Column: take the remaining space on both axes'
    /// main direction.
    func expanded() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Flutter `BorderRadius.vertical(top:bottom:)` / `.only(...)` as corner radii.
enum BorderRadius {
    static func circular(_ r: CGFloat) -> RectangleCornerRadii {
        RectangleCornerRadii(topLeading: r, bottomLeading: r, bottomTrailing: r, topTrailing: r)
    }

    static func vertical(top: CGFloat = 0, bottom: CGFloat = 0) -> RectangleCornerRadii {
        RectangleCornerRadii(topLeading: top, bottomLeading: bottom, bottomTrailing: bottom, topTrailing: top)
    }

    static func horizontal(left: CGFloat = 0, right: CGFloat = 0) -> RectangleCornerRadii {
        RectangleCornerRadii(topLeading: left, bottomLeading: left, bottomTrailing: right, topTrailing: right)
    }

    static func only(topLeft: CGFloat = 0, topRight: CGFloat = 0, bottomLeft: CGFloat = 0, bottomRight: CGFloat = 0) -> RectangleCornerRadii {
        RectangleCornerRadii(topLeading: topLeft, bottomLeading: bottomLeft, bottomTrailing: bottomRight, topTrailing: topRight)
    }
}

/// Flutter's `Divider(height:, thickness:, color:)`.
struct MaterialDivider: View {
    var height: CGFloat = 16
    var thickness: CGFloat = 1
    var color: Color = AppColors.divider
    var indent: CGFloat = 0
    var endIndent: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: thickness)
            .padding(.leading, indent)
            .padding(.trailing, endIndent)
            .frame(height: max(height, thickness))
    }
}

/// A dashed horizontal line (the ticket seams drawn with CustomPaint in Dart).
struct DashedLine: View {
    var color: Color = AppColors.border
    var dash: CGFloat = 5
    var gap: CGFloat = 4
    var thickness: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: thickness / 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: thickness / 2))
            }
            .stroke(color, style: StrokeStyle(lineWidth: thickness, dash: [dash, gap]))
        }
        .frame(height: thickness)
    }
}

import SwiftUI
import UIKit

/// Palette and building blocks. Bright flat colors on white, like a picture book for teens.
enum P {
    static let coral = Color(hex: 0xEE5C3E)
    static let lavender = Color(hex: 0x8F95F9)
    static let navy = Color(hex: 0x1C2A87)
    static let yellow = Color(hex: 0xFFC47B)
    static let green = Color(hex: 0x48AD76)
    static let jungle = Color(hex: 0x173827)
    static let red = Color(hex: 0xEF1F0A)

    static let bg = Color(light: 0xFFFFFF, dark: 0x0F1020)
    static let card = Color(light: 0xF2F2F3, dark: 0x1B1D33)
    static let raised = Color(light: 0xFFFFFF, dark: 0x23264A)
    static let ink = Color(light: 0x1B1B2F, dark: 0xF1F1FA)
    static let muted = Color(light: 0xA79FA0, dark: 0x8C8FAD)
    static let line = Color(light: 0xE8E8F1, dark: 0x2D3052)

    /// Cell colors on the field.
    static let free = Color(light: 0xEEEEF5, dark: 0x22253F)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
}

extension Font {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

/// Square formatting without locale grouping: 2209, not 2 209.
func sq(_ n: Int) -> String { "\(n * n)" }

// MARK: - buttons

/// Big pill button with a decorative swoosh at its right end, pressed down on touch.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = P.green
    var accent: Color = P.coral
    var fg: Color = .white
    var swoosh = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color)
                    .overlay(alignment: .trailing) {
                        if swoosh { Swoosh(a: accent, b: P.lavender).frame(width: 64).clipped() }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct Swoosh: View {
    var a: Color
    var b: Color
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            p.move(to: CGPoint(x: size.width * 0.35, y: size.height))
            p.addCurve(to: CGPoint(x: size.width, y: 0),
                       control1: CGPoint(x: size.width * 0.2, y: size.height * 0.2),
                       control2: CGPoint(x: size.width * 0.7, y: -size.height * 0.1))
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.closeSubpath()
            ctx.fill(p, with: .color(a))
            var q = Path()
            q.move(to: CGPoint(x: size.width * 0.62, y: size.height))
            q.addCurve(to: CGPoint(x: size.width, y: size.height * 0.25),
                       control1: CGPoint(x: size.width * 0.55, y: size.height * 0.45),
                       control2: CGPoint(x: size.width * 0.8, y: size.height * 0.2))
            q.addLine(to: CGPoint(x: size.width, y: size.height))
            q.closeSubpath()
            ctx.fill(q, with: .color(b))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Presses with a haptic tick, for any tappable card.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - containers

extension View {
    func card(_ color: Color = P.card, padding: CGFloat = 16, radius: CGFloat = 22) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Tap feedback shared by every button in the app.
    func tapFeedback() -> some View {
        simultaneousGesture(TapGesture().onEnded { Feel.tap() })
    }
}

struct Pill: View {
    var text: String
    var color: Color
    var fg: Color = .white
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .foregroundStyle(fg)
            .background(color, in: Capsule())
    }
}

struct ProgressBar: View {
    var value: Double
    var color: Color = P.green
    var track: Color = P.line
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color).frame(width: max(8, g.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }
}

/// Header with a back chevron for full-screen game flows.
struct GameHeader<Trailing: View>: View {
    var title: LocalizedStringKey
    var close: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 17, weight: .bold))
                    .frame(width: 40, height: 40).background(P.card, in: Circle())
            }
            .foregroundStyle(P.ink)
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("close")
            Text(title).font(.system(size: 20, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            trailing
        }
    }
}

/// Coral underline used under screen titles, like in the reference.
struct Underlined: View {
    var text: LocalizedStringKey
    var size: CGFloat = 30
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(.system(size: size, weight: .heavy)).foregroundStyle(P.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Capsule().fill(P.coral).frame(width: 48, height: 4)
        }
    }
}

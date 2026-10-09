import SwiftUI

enum Avatars {
    static let names = ["av-fox", "av-zebra", "av-lion", "av-owl", "av-parrot", "av-monkey", "av-giraffe", "av-panda", "av-rabbit"]
    static func name(_ i: Int) -> String { names[((i % names.count) + names.count) % names.count] }
}

struct Avatar: View {
    var name: String
    var size: CGFloat = 56
    var body: some View {
        Image(name).resizable().scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - keypad

/// Number pad. Answers are checked as soon as enough digits are typed, so speed matters.
struct Keypad: View {
    var onDigit: (Int) -> Void
    var onErase: () -> Void
    var disabled = false

    private let rows: [[Int?]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [nil, 0, -1]]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 10) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        key(rows[r][c])
                    }
                }
            }
        }
        // phone keypads read 1 2 3 left to right in every language
        .environment(\.layoutDirection, .leftToRight)
        .disabled(disabled)
    }

    @ViewBuilder private func key(_ k: Int?) -> some View {
        if let k {
            Button {
                Feel.key()
                k < 0 ? onErase() : onDigit(k)
            } label: {
                Group {
                    if k < 0 { Image(systemName: "delete.left.fill").font(.system(size: 22, weight: .semibold)) }
                    else { Text(verbatim: "\(k)").font(.display(28, .bold)) }
                }
                .foregroundStyle(P.ink)
                // flexible height: tall keys on big phones, still fits an iPhone SE
                .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 58)
                .background(P.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(k < 0 ? Text("Erase") : Text(verbatim: "\(k)"))
            .accessibilityIdentifier(k < 0 ? "key-erase" : "key-\(k)")
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 42, maxHeight: 58)
        }
    }
}

enum Verdict { case none, right, wrong }

/// The typed answer, with green or red feedback and a shake on mistakes.
struct AnswerBox: View {
    var text: String
    var verdict: Verdict
    var placeholder = "?"

    var body: some View {
        let color: Color = verdict == .right ? P.green : verdict == .wrong ? P.red : P.line
        Text(text.isEmpty ? placeholder : text)
            .font(.display(40))
            .foregroundStyle(text.isEmpty ? P.muted : (verdict == .none ? P.ink : .white))
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 76)
            .background(verdict == .none ? P.bg : color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(color, lineWidth: verdict == .none ? 2.5 : 0))
            .modifier(Shake(amount: verdict == .wrong ? 1 : 0))
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: verdict)
            .contentTransition(.numericText())
            .accessibilityIdentifier("answer")
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat { get { amount } set { amount = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(amount * .pi * 4), y: 0))
    }
}

// MARK: - question

/// "47²" with a nicely raised exponent.
struct SquareLabel: View {
    var n: Int
    var size: CGFloat = 64
    var suffix = ""
    var body: some View {
        (Text(verbatim: "\(n)").font(.display(size)) + Text(verbatim: "2").font(.display(size * 0.45)).baselineOffset(size * 0.42)
            + Text(verbatim: suffix).font(.display(size)))
            .foregroundStyle(P.ink)
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(String(n)) squared"))
            .accessibilityIdentifier("question")
            .accessibilityValue(Text(verbatim: "\(n)"))
    }
}

// MARK: - confetti

/// Squares and dots raining down once, in the palette colors.
struct Confetti: View {
    var trigger: Int
    @State private var start: Date?
    private let pieces: [(x: Double, speed: Double, spin: Double, color: Color, size: Double, delay: Double)] = (0..<70).map { _ in
        (Double.random(in: 0...1), Double.random(in: 0.6...1.2), Double.random(in: -6...6),
         [P.coral, P.lavender, P.navy, P.yellow, P.green].randomElement()!, Double.random(in: 7...13), Double.random(in: 0...0.35))
    }

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { tl in
            Canvas { ctx, size in
                guard let start else { return }
                let t = tl.date.timeIntervalSince(start)
                for p in pieces {
                    let tt = t - p.delay
                    guard tt > 0 else { continue }
                    let y = -20 + tt * tt * 520 * p.speed + tt * 160
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(tt * 3 + p.spin) * 18
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(tt * p.spin))
                    c.fill(Path(roundedRect: CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.size * 0.7), cornerRadius: 2),
                           with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            start = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { start = nil }
        }
    }
}

/// Floating "+1" style pop over an element.
struct PopText: View {
    var text: String
    var color: Color
    var trigger: Int
    @State private var shown = false

    var body: some View {
        Text(text).font(.system(size: 22, weight: .heavy)).foregroundStyle(color)
            .offset(y: shown ? -40 : 0)
            .opacity(shown ? 0 : 1)
            .onChange(of: trigger) { _, _ in
                shown = false
                withAnimation(.easeOut(duration: 0.7)) { shown = true }
            }
            .opacity(trigger == 0 ? 0 : 1)
            .allowsHitTesting(false)
    }
}

/// Decorative quarter circle in a tile corner, like on the reference cards.
struct CornerBlob: View {
    var color: Color
    var corner: Alignment = .topTrailing
    var size: CGFloat = 70
    var body: some View {
        // drawn inside its own bounds, so nothing pokes out of the card it decorates
        Canvas { ctx, s in
            let right = corner == .topTrailing || corner == .bottomTrailing
            let top = corner == .topTrailing || corner == .topLeading
            let cx = right ? s.width - size * 0.15 : size * 0.15
            let cy = top ? size * 0.15 : s.height - size * 0.15
            ctx.fill(Path(ellipseIn: CGRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size)), with: .color(color))
        }
        .flipsForRightToLeftLayoutDirection(true)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

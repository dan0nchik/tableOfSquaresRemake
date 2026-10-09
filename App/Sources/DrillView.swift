import SwiftUI

/// Typed answer that checks itself once it has as many digits as the right answer.
struct Typing {
    var answer = 0
    var text = ""
    var verdict: Verdict = .none

    var locked: Bool { verdict != .none }

    /// Returns the verdict once the answer is complete.
    mutating func type(_ d: Int) -> Verdict? {
        guard !locked, text.count < 5 else { return nil }
        if text.isEmpty && d == 0 { return nil }
        text += "\(d)"
        guard text.count >= "\(answer)".count else { return nil }
        verdict = Int(text) == answer ? .right : .wrong
        return verdict
    }

    mutating func erase() { if !locked && !text.isEmpty { text.removeLast() } }

    mutating func reset(_ answer: Int) { self = Typing(answer: answer) }
}

/// "Defend the field": fading squares and new ones, answered on the keypad.
struct DrillView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [Int]
    @State private var index = 0
    @State private var typing = Typing()
    @State private var retried: Set<Int> = []
    @State private var captured: [Int] = []
    @State private var right = 0
    @State private var total = 0
    @State private var pop = 0
    @State private var finished = false

    init(deck: [Int]) { _queue = State(initialValue: deck.isEmpty ? [Store.range.randomElement()!] : deck) }

    private var n: Int { queue[min(index, queue.count - 1)] }

    var body: some View {
        if finished {
            ResultView(win: true,
                       title: captured.isEmpty ? "Nice work" : "Field grows",
                       subtitle: captured.isEmpty ? "Every right answer brings a square closer to being yours"
                                                  : "New squares are yours. Come back tomorrow so they do not fade",
                       stats: [(String(localized: "Right"), "\(right)/\(total)"), (String(localized: "Captured"), "\(captured.count)")],
                       squares: captured,
                       again: nil, done: { dismiss() })
        } else {
            VStack(spacing: 18) {
                GameHeader(title: "Defend the field", close: { dismiss() }) {
                    Text(verbatim: "\(min(index + 1, queue.count))/\(queue.count)").font(.system(size: 16, weight: .bold)).monospacedDigit()
                        .foregroundStyle(P.muted)
                }
                ProgressBar(value: Double(index) / Double(queue.count))
                Spacer(minLength: 0)
                VStack(spacing: 12) {
                    SquareLabel(n: n, size: 76)
                    HitDots(cell: store.cell(n), today: store.today)
                }
                .overlay(alignment: .top) { PopText(text: String(localized: "Captured!"), color: P.green, trigger: pop).offset(y: -30) }
                Spacer(minLength: 0)
                AnswerBox(text: typing.text, verdict: typing.verdict)
                Keypad(onDigit: type, onErase: { typing.erase() }, disabled: typing.locked)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(P.bg)
            .onAppear { typing.reset(n * n) }
        }
    }

    private func type(_ d: Int) {
        guard let v = typing.type(d) else { return }
        total += 1
        if v == .right {
            right += 1
            if store.record(n, correct: true) {
                captured.append(n)
                pop += 1
                Feel.capture()
            } else {
                Feel.correct()
            }
            advance(after: 0.45)
        } else {
            store.record(n, correct: false)
            Feel.wrong()
            typing.text = sq(n)
            if !retried.contains(n) { retried.insert(n); queue.append(n) }
            advance(after: 1.3)
        }
    }

    private func advance(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if index + 1 >= queue.count {
                store.finishSession()
                Feel.win()
                withAnimation { finished = true }
            } else {
                index += 1
                typing.reset(n * n)
            }
        }
    }
}

/// Three dots showing how close a square is to being captured.
struct HitDots: View {
    var cell: Cell
    var today: Int

    var body: some View {
        let state = cell.state(today: today)
        HStack(spacing: 6) {
            switch state {
            case .captured: label("Captured", P.green, "checkmark.circle.fill")
            case .fading: label("Fading, answer to keep it", P.coral, "exclamationmark.circle.fill")
            case .free, .progress:
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(i < cell.hits ? P.lavender : P.line).frame(width: 10, height: 10)
                }
                Text("Capture").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.muted).padding(.leading, 4)
            }
        }
        .animation(.spring, value: cell.hits)
    }

    private func label(_ t: LocalizedStringKey, _ c: Color, _ s: String) -> some View {
        Label(t, systemImage: s).font(.system(size: 14, weight: .semibold)).foregroundStyle(c)
    }
}

/// End of any game: illustration, numbers and what to do next.
struct ResultView: View {
    var win: Bool
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    var stats: [(String, String)]
    var squares: [Int] = []
    var share: AnyView? = nil
    var again: (() -> Void)?
    var done: () -> Void
    @State private var confetti = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(win ? "win" : "lose").resizable().scaledToFit()
                        .frame(maxHeight: 230)
                        .scaleEffect(appeared ? 1 : 0.6).opacity(appeared ? 1 : 0)
                        .padding(.top, 30)
                    Text(title).font(.system(size: 32, weight: .heavy)).foregroundStyle(P.ink).multilineTextAlignment(.center)
                    Text(subtitle).font(.system(size: 16, weight: .medium)).foregroundStyle(P.muted)
                        .multilineTextAlignment(.center).padding(.horizontal, 20)
                    HStack(spacing: 12) {
                        ForEach(stats.indices, id: \.self) { i in
                            VStack(spacing: 4) {
                                Text(verbatim: stats[i].1).font(.display(26)).foregroundStyle(P.ink)
                                Text(stats[i].0).font(.system(size: 13, weight: .semibold)).foregroundStyle(P.muted)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(P.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    if !squares.isEmpty {
                        FlowSquares(numbers: squares)
                    }
                    if let share { share }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, again == nil ? 90 : 160)
            }
            VStack(spacing: 12) {
                Spacer()
                if let again {
                    Button(action: again) { Text("Again") }.buttonStyle(ChunkyButtonStyle()).tapFeedback()
                        .accessibilityIdentifier("again")
                }
                Button(action: done) { Text("Done") }
                    .accessibilityIdentifier("done")
                    .buttonStyle(ChunkyButtonStyle(color: again == nil ? P.green : P.card, fg: again == nil ? .white : P.ink, swoosh: again == nil))
                    .tapFeedback()
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
            Confetti(trigger: confetti).ignoresSafeArea()
        }
        .background(P.bg)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
            if win { confetti += 1 }
        }
    }
}

struct FlowSquares: View {
    var numbers: [Int]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
            ForEach(numbers, id: \.self) { n in
                VStack(spacing: 0) {
                    Text(verbatim: "\(n)²").font(.system(size: 15, weight: .heavy))
                    Text(verbatim: sq(n)).font(.system(size: 12, weight: .semibold)).opacity(0.85)
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 52)
                .background(P.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

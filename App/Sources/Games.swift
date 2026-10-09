import SwiftUI

enum Choices {
    /// n² and three believable wrong squares.
    static func squares(_ n: Int) -> [Int] {
        var set: Set<Int> = [n * n]
        let fakes = [(n - 1) * (n - 1), (n + 1) * (n + 1), n * n + 10, n * n - 10, n * n + 100, n * n - 100].shuffled()
        for f in fakes where f > 0 && set.count < 4 { set.insert(f) }
        return set.shuffled()
    }

    /// n and three roots that are easy to confuse with it.
    static func roots(_ n: Int) -> [Int] {
        var set: Set<Int> = [n]
        let twin = n / 10 * 10 + (10 - n % 10) % 10
        let fakes = ([twin] + [n + 1, n - 1, n + 10, n - 10, n + 2].shuffled()).filter { (11...99).contains($0) && $0 != n }
        for f in fakes where set.count < 4 { set.insert(f) }
        return set.shuffled()
    }

    /// What the last digit of a square says about its root.
    static func tip(_ square: Int) -> String {
        let d = square % 10
        let ends: String
        switch d {
        case 1: ends = String(localized: "\(1) or \(9)")
        case 4: ends = String(localized: "\(2) or \(8)")
        case 9: ends = String(localized: "\(3) or \(7)")
        case 6: ends = String(localized: "\(4) or \(6)")
        default: ends = "\(d)"
        }
        return String(localized: "It ends in \(d), so the root ends in \(ends)")
    }
}

// MARK: - cards

struct CardsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var deck: [Int]
    @State private var index = 0
    @State private var flipped = false
    @State private var known = 0
    @State private var again: Set<Int> = []
    @State private var finished = false
    @State private var drag: CGFloat = 0

    init(deck: [Int]) { _deck = State(initialValue: deck) }

    var body: some View {
        if finished {
            ResultView(win: true, title: "Deck done", subtitle: "Cards you did not know came back until you did",
                       stats: [(String(localized: "Known"), "\(known)"), (String(localized: "Repeated"), "\(again.count)")],
                       again: nil, done: { dismiss() })
        } else {
            VStack(spacing: 18) {
                GameHeader(title: "Cards", close: { dismiss() }) {
                    Text(verbatim: "\(index + 1)/\(deck.count)").font(.system(size: 16, weight: .bold)).monospacedDigit().foregroundStyle(P.muted)
                }
                ProgressBar(value: Double(index) / Double(max(1, deck.count)), color: P.navy)
                card
                    .offset(x: drag)
                    .rotationEffect(.degrees(Double(drag) / 25))
                    .gesture(DragGesture()
                        .onChanged { drag = $0.translation.width }
                        .onEnded { v in
                            if v.translation.width > 110 { answer(true) }
                            else if v.translation.width < -110 { answer(false) }
                            else { withAnimation(.spring) { drag = 0 } }
                        })
                Text("Tap to flip. Swipe right if you knew it").font(.system(size: 14, weight: .medium)).foregroundStyle(P.muted)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button { answer(false) } label: { Text("Don't know") }
                        .buttonStyle(ChunkyButtonStyle(color: P.coral, swoosh: false))
                        .accessibilityIdentifier("dont-know")
                    Button { answer(true) } label: { Text("Know") }
                        .buttonStyle(ChunkyButtonStyle(color: P.green))
                        .accessibilityIdentifier("know")
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(P.bg)
        }
    }

    private var n: Int { deck[index] }

    private var card: some View {
        ZStack {
            face(back: false).opacity(flipped ? 0 : 1)
            face(back: true).opacity(flipped ? 1 : 0).rotation3DEffect(.degrees(180), axis: (0, 1, 0))
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0), perspective: 0.5)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: flipped)
        .onTapGesture { Feel.flip(); flipped.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("card")
        .accessibilityLabel(flipped ? Text(verbatim: "\(n)² = \(sq(n))") : Text("\(String(n)) squared"))
    }

    private func face(back: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous).fill(back ? P.navy : P.card)
            CornerBlob(color: back ? P.lavender : P.yellow, corner: back ? .bottomLeading : .topTrailing, size: 120)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            VStack(spacing: 14) {
                if back {
                    Text(verbatim: sq(n)).font(.display(80)).foregroundStyle(.white)
                    Text(verbatim: "\(n) × \(n)").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                } else {
                    Text("How much is").font(.system(size: 17, weight: .semibold)).foregroundStyle(P.muted)
                    SquareLabel(n: n, size: 88)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxHeight: .infinity)
    }

    private func answer(_ ok: Bool) {
        store.record(n, correct: ok)
        if ok { known += 1; Feel.correct() } else {
            Feel.wrong()
            again.insert(n)
            deck.append(n)
        }
        withAnimation(.easeIn(duration: 0.18)) { drag = ok ? 500 : -500 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            flipped = false
            drag = 0
            if index + 1 >= deck.count {
                store.finishSession()
                Feel.win()
                withAnimation { finished = true }
            } else {
                index += 1
            }
        }
    }
}

// MARK: - reverse

struct ReverseView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var numbers = Array((11...99).filter { $0 % 10 != 0 }.shuffled().prefix(10))
    @State private var index = 0
    @State private var options: [Int] = []
    @State private var picked: Int?
    @State private var right = 0
    @State private var finished = false

    var body: some View {
        if finished {
            ResultView(win: right >= 7, title: right >= 7 ? "Root master" : "Good practice",
                       subtitle: "Knowing squares both ways is what exams check",
                       stats: [(String(localized: "Right"), "\(right)/\(numbers.count)")],
                       again: { reset() }, done: { dismiss() })
        } else {
            VStack(spacing: 18) {
                GameHeader(title: "Reverse", close: { dismiss() }) {
                    Text(verbatim: "\(index + 1)/\(numbers.count)").font(.system(size: 16, weight: .bold)).monospacedDigit().foregroundStyle(P.muted)
                }
                ProgressBar(value: Double(index) / Double(numbers.count), color: P.yellow)
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    Text("Which number squared gives").font(.system(size: 17, weight: .semibold)).foregroundStyle(P.muted)
                        .multilineTextAlignment(.center)
                    Text(verbatim: sq(n)).font(.display(84)).foregroundStyle(P.ink)
                        .accessibilityIdentifier("reverse-square")
                }
                .frame(maxWidth: .infinity).padding(.vertical, 26)
                .background { ZStack { P.card; CornerBlob(color: P.yellow, corner: .bottomTrailing, size: 90) } }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                Text(Choices.tip(n * n)).font(.system(size: 15, weight: .medium)).foregroundStyle(P.muted)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(options, id: \.self) { o in
                        ChoiceButton(text: "\(o)", state: state(o)) { pick(o) }
                            .accessibilityIdentifier("choice-\(o)")
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(P.bg)
            .onAppear { if options.isEmpty { options = Choices.roots(n) } }
        }
    }

    private var n: Int { numbers[index] }

    private func state(_ o: Int) -> Verdict {
        guard let picked else { return .none }
        if o == n { return .right }
        return o == picked ? .wrong : .none
    }

    private func pick(_ o: Int) {
        guard picked == nil else { return }
        picked = o
        let ok = o == n
        store.record(n, correct: ok)
        if ok { right += 1; Feel.correct() } else { Feel.wrong() }
        DispatchQueue.main.asyncAfter(deadline: .now() + (ok ? 0.6 : 1.3)) {
            picked = nil
            if index + 1 >= numbers.count {
                store.finishSession()
                if right >= 7 { Feel.win() } else { Feel.lose() }
                withAnimation { finished = true }
            } else {
                index += 1
                options = Choices.roots(n)
            }
        }
    }

    private func reset() {
        numbers = Array((11...99).filter { $0 % 10 != 0 }.shuffled().prefix(10))
        index = 0; right = 0; picked = nil
        options = Choices.roots(numbers[0])
        finished = false
    }
}

struct ChoiceButton: View {
    var text: String
    var state: Verdict
    var size: CGFloat = 30
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: text).font(.display(size))
                .foregroundStyle(state == .none ? P.ink : .white)
                .frame(maxWidth: .infinity, minHeight: size * 2.3)
                .background(state == .right ? P.green : state == .wrong ? P.red : P.card,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .modifier(Shake(amount: state == .wrong ? 1 : 0))
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: state)
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - duel

/// Two players, one phone. The top half is upside down for the friend across the table.
struct DuelView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    static let target = 10

    @State private var n = Int.random(in: 11...99)
    @State private var options: [Int] = []
    @State private var score = [0, 0]
    @State private var locked = [false, false]
    @State private var flash: [Verdict] = [.none, .none]
    @State private var picks: [Int?] = [nil, nil]
    @State private var winner: Int?
    @State private var resolving = false

    var body: some View {
        VStack(spacing: 0) {
            half(1).rotationEffect(.degrees(180))
            middle
            half(0)
        }
        .background(P.bg)
        .onAppear { if options.isEmpty { options = Choices.squares(n) } }
    }

    private var middle: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("close")
            Spacer()
            Text(verbatim: "\(score[0]) : \(score[1])").font(.display(24)).foregroundStyle(.white)
                .contentTransition(.numericText())
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "flag.checkered")
                Text(verbatim: "\(DuelView.target)")
            }
            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.7))
            .frame(minWidth: 36, minHeight: 36)
        }
        .padding(.horizontal, 16).frame(height: 56)
        .background(P.navy)
    }

    private func half(_ p: Int) -> some View {
        let tint = p == 0 ? P.coral : P.lavender
        return ZStack {
            (flash[p] == .right ? P.green.opacity(0.18) : flash[p] == .wrong ? P.red.opacity(0.14) : Color.clear)
                .animation(.easeOut(duration: 0.25), value: flash[p])
            CornerBlob(color: tint.opacity(0.25), corner: .topLeading, size: 120)
            if let w = winner {
                VStack(spacing: 14) {
                    Avatar(name: avatar(p), size: 84)
                    Text(w == p ? "You win!" : "Next time!").font(.system(size: 30, weight: .heavy)).foregroundStyle(P.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 10) {
                        Button { restart() } label: { Text("Again") }.buttonStyle(ChunkyButtonStyle(color: tint, swoosh: false))
                            .accessibilityIdentifier("again-\(p)")
                        Button { dismiss() } label: { Text("Exit") }.buttonStyle(ChunkyButtonStyle(color: P.card, fg: P.ink, swoosh: false))
                            .accessibilityIdentifier("exit-\(p)")
                    }
                }
                .padding(24)
            } else {
                VStack(spacing: 14) {
                    HStack {
                        Avatar(name: avatar(p), size: 40)
                        Text(p == 0 ? "Player 1" : "Player 2").font(.system(size: 17, weight: .bold)).foregroundStyle(P.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Spacer()
                        Text(verbatim: "\(score[p])").font(.display(22)).foregroundStyle(tint)
                    }
                    SquareLabel(n: n, size: 46, suffix: " =")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        ForEach(options, id: \.self) { o in
                            ChoiceButton(text: "\(o)", state: picks[p] == o ? flash[p] : .none, size: 24) { pick(p, o) }
                                .disabled(locked[p] || resolving)
                                .accessibilityIdentifier("p\(p)-choice-\(o)")
                        }
                    }
                    .opacity(locked[p] ? 0.4 : 1)
                }
                .padding(18)
            }
        }
        .frame(maxHeight: .infinity)
        .clipped()
    }

    private func avatar(_ p: Int) -> String { Avatars.name(store.data.avatar + (p == 0 ? 0 : 4)) }

    private func pick(_ p: Int, _ o: Int) {
        guard winner == nil, !resolving, !locked[p] else { return }
        picks[p] = o
        if o == n * n {
            resolving = true
            flash[p] = .right
            score[p] += 1
            store.record(n, correct: true)
            Feel.correct(combo: score[p])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if score[p] >= DuelView.target {
                    winner = p
                    store.finishDuel()
                    Feel.win()
                } else {
                    nextQuestion()
                }
                resolving = false
            }
        } else {
            flash[p] = .wrong
            locked[p] = true
            Feel.wrong()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                locked[p] = false
                if flash[p] == .wrong { flash[p] = .none; picks[p] = nil }
            }
        }
    }

    private func nextQuestion() {
        var m = Int.random(in: 11...99)
        while m == n { m = Int.random(in: 11...99) }
        n = m
        options = Choices.squares(m)
        flash = [.none, .none]
        picks = [nil, nil]
        locked = [false, false]
    }

    private func restart() {
        score = [0, 0]
        winner = nil
        nextQuestion()
    }
}

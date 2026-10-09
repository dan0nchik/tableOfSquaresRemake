import SwiftUI

/// Race to 20 right answers against your own best run or a bot.
struct RaceView: View {
    let opponent: Store.Opponent
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var numbers: [Int] = []
    @State private var index = 0
    @State private var typing = Typing()
    @State private var splits: [Double] = []
    @State private var rival: [Double] = []
    @State private var start: Date?
    @State private var countdown = 3
    @State private var now = Date()
    @State private var outcome: Outcome?
    @State private var pressured = false

    private let goal = Store.raceLength
    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    struct Outcome { var won: Bool; var time: Double; var record: Bool; var mistakes: Int }

    private var elapsed: Double { start.map { now.timeIntervalSince($0) } ?? 0 }
    private var rivalDone: Int { rival.filter { $0 <= elapsed }.count }
    private var mine: Int { splits.count }

    var body: some View {
        Group {
            if let o = outcome { result(o) } else { race }
        }
        .onAppear(perform: setup)
        .onReceive(tick) { t in
            guard outcome == nil else { return }
            now = t
            guard start != nil else { return }
            if rivalDone >= goal { finish(won: false) }
            else if rivalDone >= goal - 3 && rivalDone > mine && !pressured { pressured = true; Feel.pressure() }
        }
    }

    private var rivalArt: String {
        if case .bot(let b) = opponent { return b.art }
        return "bot-ghost"
    }

    private var rivalName: LocalizedStringResource {
        if case .bot(let b) = opponent { return b.name }
        return "Ghost"
    }

    // MARK: race screen

    private var race: some View {
        VStack(spacing: 16) {
            GameHeader(title: "Race", close: { dismiss() }) {
                Label { Text(verbatim: String(format: "%.1f", elapsed)).monospacedDigit() } icon: { Image(systemName: "stopwatch.fill") }
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(P.ink)
            }
            VStack(spacing: 14) {
                Lane(art: rivalArt, done: rivalDone, goal: goal, color: P.lavender, ghost: opponent == .ghost)
                Lane(art: Avatars.name(store.data.avatar), done: mine, goal: goal, color: P.coral, ghost: false)
                Text(gap).font(.system(size: 15, weight: .semibold)).foregroundStyle(mine >= rivalDone ? P.green : P.coral)
                    .contentTransition(.numericText()).animation(.default, value: mine - rivalDone)
            }
            .card()
            Spacer(minLength: 0)
            ZStack {
                if start == nil {
                    Text(verbatim: countdown > 0 ? "\(countdown)" : "")
                        .font(.display(96)).foregroundStyle(P.coral)
                        .contentTransition(.numericText(countsDown: true))
                } else if index < numbers.count {
                    SquareLabel(n: numbers[index], size: 72)
                }
            }
            .frame(minHeight: 70, maxHeight: 100)
            Spacer(minLength: 0)
            AnswerBox(text: typing.text, verdict: typing.verdict)
            Keypad(onDigit: type, onErase: { typing.erase() }, disabled: start == nil || typing.locked)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(P.bg)
    }

    private var gap: String {
        let d = mine - rivalDone
        if start == nil { return String(localized: "Get ready") }
        if d > 0 { return String(localized: "Ahead by \(d)") }
        if d < 0 { return String(localized: "Behind by \(-d)") }
        return String(localized: "Neck and neck")
    }

    // MARK: logic

    private func setup() {
        guard numbers.isEmpty else { return }
        // more than enough questions in case of mistakes
        numbers = Array(Array(11...99).filter { $0 % 10 != 0 }.shuffled().prefix(goal + 15))
        typing.reset(numbers[0] * numbers[0])
        switch opponent {
        case .ghost: rival = store.data.bestSplits
        case .bot(let b):
            var t = 0.0
            rival = (0..<goal).map { _ in
                t += b.pace * Double.random(in: 0.7...1.3)
                if Double.random(in: 0...1) < b.missRate { t += b.pace * 1.5 }
                return t
            }
        }
        if rival.count < goal { rival += Array(repeating: .infinity, count: goal - rival.count) }
        Feel.tick()
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) {
                withAnimation { countdown = 3 - i }
                if i < 3 { Feel.tick() } else { Feel.correct(); start = Date() }
            }
        }
    }

    private func type(_ d: Int) {
        guard let v = typing.type(d), outcome == nil else { return }
        let n = numbers[index]
        if v == .right {
            store.record(n, correct: true)
            splits.append(elapsed)
            Feel.correct(combo: splits.count)
            if splits.count >= goal { finish(won: true); return }
            next(after: 0.18)
        } else {
            store.record(n, correct: false)
            Feel.wrong()
            typing.text = sq(n)
            next(after: 0.9)
        }
    }

    private func next(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard outcome == nil else { return }
            index = min(index + 1, numbers.count - 1)
            typing.reset(numbers[index] * numbers[index])
        }
    }

    private func finish(won: Bool) {
        guard outcome == nil else { return }
        let time = elapsed
        let mistakes = index + 1 - splits.count
        var record = false
        if won {
            record = store.finishRace(time: time, splits: splits, against: opponent, won: true)
            Feel.win()
        } else {
            store.finishRace(time: .infinity, splits: [], against: opponent, won: false)
            Feel.lose()
        }
        withAnimation { outcome = Outcome(won: won, time: time, record: record, mistakes: max(0, mistakes)) }
    }

    private func again() {
        numbers = []; index = 0; splits = []; start = nil; countdown = 3; pressured = false
        outcome = nil
        setup()
    }

    // MARK: result

    private func result(_ o: Outcome) -> some View {
        ResultView(
            win: o.won,
            title: o.won ? (o.record ? "New record!" : "You won!") : "So close",
            subtitle: o.won ? "Faster than your rival. Share the result and challenge a friend"
                            : "Your rival finished first. One more try?",
            stats: o.won ? [(String(localized: "Time"), seconds(o.time)), (String(localized: "Mistakes"), "\(o.mistakes)")]
                         : [(String(localized: "Right"), "\(mine)/\(goal)"), (String(localized: "Mistakes"), "\(o.mistakes)")],
            share: o.won ? AnyView(ShareRecord(time: o.time, avatar: Avatars.name(store.data.avatar))) : nil,
            again: again,
            done: { dismiss() })
    }
}

/// A track with the racer's avatar sliding towards the flag.
struct Lane: View {
    var art: String
    var done: Int
    var goal: Int
    var color: Color
    var ghost: Bool

    var body: some View {
        GeometryReader { g in
            let size: CGFloat = 40
            let x = (g.size.width - size) * CGFloat(done) / CGFloat(goal)
            ZStack(alignment: .leading) {
                Capsule().fill(P.line).frame(height: 10)
                Capsule().fill(color).frame(width: max(10, x + size / 2), height: 10)
                Image(systemName: "flag.checkered").font(.system(size: 16, weight: .bold)).foregroundStyle(P.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing).offset(y: -18)
                Avatar(name: art, size: size)
                    .overlay(Circle().strokeBorder(P.bg, lineWidth: 3))
                    .opacity(ghost ? 0.75 : 1)
                    .offset(x: x)
            }
            .frame(height: size)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: done)
        }
        .frame(height: 40)
    }
}

/// The card people share to stories, rendered to an image.
struct RecordCard: View {
    var time: Double
    var avatar: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Avatar(name: avatar, size: 64)
                Spacer()
                Image(systemName: "flag.checkered").font(.system(size: 30, weight: .bold)).foregroundStyle(.white.opacity(0.9))
            }
            Text("My race record").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            Text(verbatim: seconds(time)).font(.display(64)).foregroundStyle(.white)
            Text("20 squares from 11² to 99². Can you beat it?").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            Text("Table of squares").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.yellow)
        }
        .padding(24)
        .frame(width: 340)
        .background {
            ZStack { P.jungle; CornerBlob(color: P.coral, corner: .bottomTrailing, size: 180); CornerBlob(color: P.lavender, corner: .topTrailing, size: 90) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

struct ShareRecord: View {
    var time: Double
    var avatar: String
    @State private var image: Image?

    var body: some View {
        VStack(spacing: 12) {
            RecordCard(time: time, avatar: avatar)
            if let image {
                ShareLink(item: image, preview: SharePreview(Text("My race record"), image: image)) {
                    Label("Share", systemImage: "square.and.arrow.up").accessibilityIdentifier("share").font(.system(size: 17, weight: .bold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 22).frame(height: 48)
                        .background(P.card, in: Capsule()).foregroundStyle(P.ink)
                }
                .simultaneousGesture(TapGesture().onEnded { Feel.tap() })
            }
        }
        .onAppear {
            let r = ImageRenderer(content: RecordCard(time: time, avatar: avatar).padding(20).background(Color.white))
            r.scale = 3
            if let ui = r.uiImage { image = Image(uiImage: ui) }
        }
    }
}

import SwiftUI

struct LearnView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var table = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Underlined(text: "Learn").padding(.top, 16)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Count in your head").font(.system(size: 22, weight: .heavy)).foregroundStyle(P.ink)
                        Text("Four tricks that turn any square from 10 to 99 into a couple of easy steps")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(P.muted)
                    }
                    Image("learn").resizable().scaledToFit().frame(width: 130)
                }

                ForEach(Lesson.all) { l in
                    Button { router.open(.lesson(l.id)) } label: {
                        HStack(spacing: 14) {
                            LessonBadge(lesson: l, size: 58)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(l.title).font(.system(size: 18, weight: .bold)).foregroundStyle(P.ink)
                                Text(l.subtitle).font(.system(size: 14, weight: .medium)).foregroundStyle(P.muted)
                            }
                            Spacer(minLength: 0)
                            if store.data.lessonsDone.contains(l.id) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(P.green)
                            } else {
                                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(P.muted)
                            }
                        }
                        .card()
                    }
                    .buttonStyle(PressStyle()).tapFeedback()
                    .accessibilityIdentifier("lesson-\(l.id)")
                }

                HStack(spacing: 14) {
                    Tile(id: "tile-visual", title: "Why a square?", note: "See it in cells", symbol: "square.grid.4x3.fill",
                         color: P.jungle, blob: P.green, corner: .topLeading) { router.open(.visual) }
                    Tile(id: "tile-table", title: "Full table", note: "From 10 to 99", symbol: "tablecells.fill",
                         color: P.lavender, blob: P.navy, corner: .topLeading) { table = true }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(P.bg)
        .sheet(isPresented: $table) { TableSheet() }
    }
}

/// The classic table of squares, like in the first version.
struct TableSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Underlined(text: "Table of squares").padding(.top, 28)
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        Text(verbatim: "").gridCellUnsizedAxes(.horizontal)
                        ForEach(0..<10, id: \.self) { u in
                            Text(verbatim: "\(u)").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.coral)
                        }
                    }
                    ForEach(1..<10, id: \.self) { t in
                        GridRow {
                            Text(verbatim: "\(t)").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.coral)
                            ForEach(0..<10, id: \.self) { u in
                                let n = t * 10 + u
                                Text(verbatim: sq(n)).font(.system(size: 11, weight: .bold)).monospacedDigit()
                                    .minimumScaleFactor(0.6).lineLimit(1)
                                    .foregroundStyle(P.ink)
                                    .frame(maxWidth: .infinity, minHeight: 34)
                                    .background((t + u) % 2 == 0 ? P.card : P.bg, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                Text("Row is the tens digit, column is the units digit")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(P.muted)
            }
            .padding(.horizontal, 16)
        }
        .background(P.bg)
        .presentationDragIndicator(.visible)
    }
}

// MARK: - lesson

struct LessonView: View {
    let lesson: Lesson
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var practice: [Int] = []
    @State private var index = 0
    @State private var typing = Typing()
    @State private var right = 0
    @State private var finished = false
    @State private var showHint = false

    private var steps: [Lesson.Step] { lesson.steps(lesson.sample) }
    private var practicing: Bool { !practice.isEmpty }

    var body: some View {
        if finished {
            ResultView(win: true, title: "Trick learned", subtitle: "Use it in races and duels. It is faster than memorizing",
                       stats: [(String(localized: "Right"), "\(right)/\(practice.count)")], again: nil, done: { dismiss() })
        } else {
            VStack(spacing: 18) {
                GameHeader(title: lesson.title, close: { dismiss() }) { EmptyView() }
                HStack(spacing: 6) {
                    ForEach(0..<(steps.count + 1), id: \.self) { i in
                        Capsule().fill(i <= (practicing ? steps.count : step) ? lesson.color : P.line).frame(height: 6)
                    }
                }
                .animation(.spring, value: step)
                if practicing { practiceView } else { walkthrough }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(P.bg)
        }
    }

    private var walkthrough: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous).fill(P.card)
                CornerBlob(color: lesson.color.opacity(0.9), corner: .topTrailing, size: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                VStack(spacing: 22) {
                    Text(verbatim: steps[step].expr)
                        .font(.display(steps[step].expr.count > 14 ? 34 : 44)).foregroundStyle(P.ink)
                        .minimumScaleFactor(0.5).lineLimit(1)
                        .environment(\.layoutDirection, .leftToRight)
                        .id("e\(step)")
                        .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                    Text(steps[step].text).font(.system(size: 20, weight: .semibold)).foregroundStyle(P.ink)
                        .multilineTextAlignment(.center)
                        .id("t\(step)")
                        .transition(.opacity)
                }
                .padding(24)
            }
            .frame(maxHeight: .infinity)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: step)
            Button {
                if step + 1 < steps.count {
                    Feel.flip()
                    step += 1
                } else {
                    Feel.correct()
                    practice = Array(lesson.numbers.shuffled().prefix(5))
                    typing.reset(practice[0] * practice[0])
                }
            } label: { Text(step + 1 < steps.count ? "Next" : "Practice") }
            .accessibilityIdentifier("lesson-next")
            .buttonStyle(ChunkyButtonStyle(color: lesson.color == P.yellow ? P.coral : lesson.color, accent: P.coral))
        }
    }

    private var practiceView: some View {
        let n = practice[index]
        return VStack(spacing: 16) {
            Text("Use the trick").font(.system(size: 16, weight: .semibold)).foregroundStyle(P.muted)
            SquareLabel(n: n, size: 72)
            Button { showHint.toggle(); Feel.tap() } label: {
                if showHint {
                    Text(verbatim: lesson.steps(n).dropFirst().first?.expr ?? "").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(P.muted).environment(\.layoutDirection, .leftToRight)
                } else {
                    Label("Hint", systemImage: "lightbulb.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(P.coral).lineLimit(1)
                }
            }
            .accessibilityIdentifier("hint")
            Spacer(minLength: 0)
            AnswerBox(text: typing.text, verdict: typing.verdict)
            Keypad(onDigit: { d in
                guard let v = typing.type(d) else { return }
                store.record(n, correct: v == .right)
                if v == .right { right += 1; Feel.correct() } else { Feel.wrong(); typing.text = sq(n) }
                DispatchQueue.main.asyncAfter(deadline: .now() + (v == .right ? 0.5 : 1.3)) {
                    showHint = false
                    if index + 1 >= practice.count {
                        store.finishLesson(lesson.id)
                        Feel.win()
                        withAnimation { finished = true }
                    } else {
                        index += 1
                        typing.reset(practice[index] * practice[index])
                    }
                }
            }, onErase: { typing.erase() }, disabled: typing.locked)
        }
    }
}

// MARK: - visual square

struct VisualSquareView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var n = 12.0

    var body: some View {
        let k = Int(n)
        VStack(spacing: 18) {
            GameHeader(title: "Why a square?", close: { dismiss() }) { EmptyView() }
            Text("A number squared is literally a square made of cells")
                .font(.system(size: 16, weight: .medium)).foregroundStyle(P.muted).multilineTextAlignment(.center)
            Canvas { ctx, size in
                let side = min(size.width, size.height)
                let gap: CGFloat = k > 14 ? 1.5 : 2.5
                let cell = (side - gap * CGFloat(k - 1)) / CGFloat(k)
                let ox = (size.width - side) / 2, oy = (size.height - side) / 2
                for r in 0..<k {
                    for c in 0..<k {
                        let rect = CGRect(x: ox + CGFloat(c) * (cell + gap), y: oy + CGFloat(r) * (cell + gap), width: cell, height: cell)
                        let edge = r == k - 1 || c == k - 1
                        ctx.fill(Path(roundedRect: rect, cornerRadius: min(4, cell / 4)), with: .color(edge ? P.coral : P.lavender))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(18)
            .background(P.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .animation(.spring, value: k)
            .accessibilityHidden(true)
            Text(verbatim: "\(k)² = \(k * k)").font(.display(40)).foregroundStyle(P.ink)
                .contentTransition(.numericText()).animation(.default, value: k)
                .environment(\.layoutDirection, .leftToRight)
            if k > 1 {
                Text("Orange is what was added to \(k - 1)²: \(k - 1) + \(k) = \(2 * k - 1) cells")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(P.coral).multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            Slider(value: $n, in: 1...20, step: 1)
                .tint(P.coral)
                .onChange(of: Int(n)) { _, _ in Feel.tick() }
                .accessibilityLabel(Text("Side of the square"))
                .accessibilityIdentifier("slider")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(P.bg)
    }
}

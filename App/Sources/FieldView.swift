import SwiftUI

extension Cell.State {
    var color: Color {
        switch self {
        case .free: P.free
        case .progress(let h): P.lavender.opacity(h >= 2 ? 0.75 : 0.4)
        case .captured: P.green
        case .fading: P.yellow
        }
    }
    var ink: Color {
        switch self {
        case .free: P.muted
        case .progress: P.navy
        case .captured: .white
        case .fading: P.jungle
        }
    }
}

struct FieldView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var selected: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Underlined(text: "Field").padding(.top, 16)
                Text("Answer a square right on three different days and it is yours. Without practice it starts to fade")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(P.muted)

                HStack(spacing: 12) {
                    stat(String(localized: "Captured"), "\(store.capturedCount)/90", P.green)
                    stat(String(localized: "Fading"), "\(store.fading.count)", P.yellow)
                    stat(String(localized: "Best race"), store.data.bestRace.map(seconds) ?? "—", P.coral)
                }

                grid

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow { legend(.free, "Free"); legend(.progress(1), "Capturing") }
                    GridRow { legend(.captured, "Yours"); legend(.fading, "Fading") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !store.fading.isEmpty {
                    Button { router.open(.drill(store.dailyDeck())) } label: {
                        Text("Defend the field")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: P.coral, accent: P.yellow))
                    .tapFeedback()
                    .accessibilityIdentifier("defend")
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(P.bg)
        .sheet(item: Binding(get: { selected.map(Picked.init) }, set: { selected = $0?.n })) { p in
            CellSheet(n: p.n).presentationDetents([.height(380)])
        }
    }

    struct Picked: Identifiable { var n: Int; var id: Int { n } }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 10), spacing: 5) {
            ForEach(Array(Store.range), id: \.self) { n in
                        let s = store.state(n)
                        Button { Feel.tap(); selected = n } label: {
                            Text(verbatim: "\(n)").font(.system(size: 13, weight: .bold)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .foregroundStyle(s.ink)
                                .frame(maxWidth: .infinity, minHeight: 26).aspectRatio(1, contentMode: .fit)
                                .background(s.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(Text(verbatim: "\(n)²"))
                        .accessibilityIdentifier("cell-\(n)")
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(12)
        .background(P.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: value).font(.display(22)).foregroundStyle(P.ink).lineLimit(1).minimumScaleFactor(0.6)
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(P.muted).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(P.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func legend(_ s: Cell.State, _ t: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 4).fill(s.color).frame(width: 14, height: 14)
            Text(t).font(.system(size: 13, weight: .semibold)).foregroundStyle(P.muted).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

struct CellSheet: View {
    let n: Int
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let c = store.cell(n)
        let s = c.state(today: store.today)
        VStack(spacing: 16) {
            Text(verbatim: "\(n)² = \(sq(n))").font(.display(48)).foregroundStyle(P.ink).padding(.top, 30)
                .environment(\.layoutDirection, .leftToRight)
            HitDots(cell: c, today: store.today)
            Group {
                switch s {
                case .captured: Text("Days until it fades: \(c.dueDay - store.today)")
                case .fading: EmptyView()
                default: Text("Right answers on different days: \(c.hits) of 3")
                }
            }
            .font(.system(size: 16, weight: .medium)).foregroundStyle(P.muted)
            if let hint = hint {
                Text(verbatim: hint).font(.system(size: 17, weight: .semibold)).foregroundStyle(P.coral)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Spacer()
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.open(.drill([n])) }
            } label: { Text("Practice") }
            .buttonStyle(ChunkyButtonStyle())
            .accessibilityIdentifier("practice")
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .background(P.bg)
    }

    /// The matching trick's key step, when one applies.
    private var hint: String? {
        Lesson.all.first { $0.numbers.contains(n) }.flatMap { $0.steps(n).dropFirst().first?.expr }
    }
}

// MARK: - trophies

struct ProfileView: View {
    @Environment(Store.self) private var store
    @State private var history = false
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Underlined(text: "Trophies").padding(.top, 16)

                HStack(spacing: 12) {
                    Avatar(name: Avatars.name(store.data.avatar), size: 72)
                    VStack(alignment: .leading, spacing: 6) {
                        Label { Text("Days in a row: \(store.liveStreak)") } icon: { Image(systemName: "flame.fill").foregroundStyle(P.coral) }
                        Label { Text("Best streak: \(store.data.bestStreak)") } icon: { Image(systemName: "star.fill").foregroundStyle(P.yellow) }
                        Label { Text("Races: \(store.data.races)") } icon: { Image(systemName: "flag.checkered").foregroundStyle(P.lavender) }
                    }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(P.ink)
                }

                ForEach(Achievement.allCases) { a in
                    let (v, goal) = store.progress(a)
                    let got = store.data.unlocked[a.rawValue] != nil
                    HStack(spacing: 14) {
                        Image(systemName: a.symbol).font(.system(size: 22, weight: .bold))
                            .foregroundStyle(got ? .white : P.muted)
                            .frame(width: 52, height: 52)
                            .background(got ? color(a) : P.free, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(a.title).font(.system(size: 17, weight: .bold)).foregroundStyle(P.ink)
                            Text(a.detail).font(.system(size: 13, weight: .medium)).foregroundStyle(P.muted)
                            if !got && goal > 1 {
                                ProgressBar(value: Double(v) / Double(goal), color: color(a)).padding(.top, 2)
                            }
                        }
                        Spacer(minLength: 0)
                        if got { Image(systemName: "checkmark.seal.fill").font(.system(size: 22)).foregroundStyle(P.green) }
                    }
                    .card(padding: 12)
                    .opacity(got ? 1 : 0.85)
                }

                Button { history = true } label: {
                    HStack(spacing: 14) {
                        Image("old-home").resizable().scaledToFill().frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Story of the app").font(.system(size: 17, weight: .bold)).foregroundStyle(P.ink)
                            Text("How it started").font(.system(size: 13, weight: .medium)).foregroundStyle(P.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(P.muted)
                    }
                    .card(padding: 12)
                }
                .buttonStyle(PressStyle()).tapFeedback()
                .accessibilityIdentifier("history")

                settings
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(P.bg)
        .sheet(isPresented: $history) { HistoryView() }
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { store.reset(); Feel.wrong() }
        }
    }

    private func color(_ a: Achievement) -> Color {
        [P.coral, P.lavender, P.navy, P.green, P.yellow][Achievement.allCases.firstIndex(of: a)! % 5]
    }

    private var settings: some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            Toggle(isOn: Binding(get: { store.data.sound }, set: { store.data.sound = $0; Feel.sound = $0; Feel.tap() })) {
                Label("Sound", systemImage: "speaker.wave.2.fill")
            }
            .accessibilityIdentifier("toggle-sound")
            .padding(.vertical, 10)
            Divider()
            Toggle(isOn: Binding(get: { store.data.haptics }, set: { store.data.haptics = $0; Feel.haptics = $0; Feel.tap() })) {
                Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
            }
            .accessibilityIdentifier("toggle-haptics")
            .padding(.vertical, 10)
            Divider()
            Button(role: .destructive) { confirmReset = true } label: {
                Label("Reset progress", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .accessibilityIdentifier("reset")
        }
        .font(.system(size: 16, weight: .semibold))
        .tint(P.green)
        .foregroundStyle(P.ink)
        .card(padding: 14)
    }
}

struct HistoryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Underlined(text: "Story of the app").padding(.top, 28)
                Text("I made the first version in 9th grade, in 2019, when I was 15. No AI, just a lot of tutorials and stubbornness.")
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(P.ink)
                HStack(spacing: 12) {
                    shot("old-home")
                    shot("old-test")
                }
                Text("First version, 2019").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.muted)
                    .frame(maxWidth: .infinity)
                Text("Seven years later it is rebuilt from scratch: tricks, races, duels and a field to capture. The goal is the same: learn squares from 10 to 99 for good.")
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(P.ink)
                HStack(spacing: 14) {
                    Image(systemName: "heart.fill").font(.system(size: 22)).foregroundStyle(.white)
                        .frame(width: 52, height: 52).background(P.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("Thank you to everyone who bought the school project. This remake is for you.")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(P.ink)
                }
                .card()
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(P.bg)
        .presentationDragIndicator(.visible)
    }

    private func shot(_ name: String) -> some View {
        Image(name).resizable().scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(P.line, lineWidth: 1))
            .frame(maxWidth: .infinity)
    }
}

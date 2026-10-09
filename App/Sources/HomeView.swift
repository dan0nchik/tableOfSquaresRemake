import SwiftUI

struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var picking = false
    @State private var avatars = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 10) {
                    Spacer()
                    streak
                    Button { avatars = true } label: { Avatar(name: Avatars.name(store.data.avatar), size: 46) }
                        .buttonStyle(PressStyle()).tapFeedback()
                        .accessibilityLabel(Text("Choose avatar"))
                        .accessibilityIdentifier("avatar-button")
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Table of").font(.system(size: 40, weight: .regular))
                    Text("squares").font(.system(size: 40, weight: .heavy))
                }
                .foregroundStyle(P.ink)
                .accessibilityElement(children: .combine)

                daily

                Text("Play").font(.system(size: 26, weight: .heavy)).foregroundStyle(P.ink).padding(.top, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                    Tile(id: "tile-race", title: "Race", note: "Ghost and bots", symbol: "flag.checkered", color: P.coral, blob: P.yellow, corner: .topLeading) {
                        picking = true
                    }
                    Tile(id: "tile-duel", title: "Duel", note: "Two on one phone", symbol: "person.2.fill", color: P.lavender, blob: P.navy, corner: .topTrailing) {
                        router.open(.duel)
                    }
                    Tile(id: "tile-cards", title: "Cards", note: "Flip and check", symbol: "rectangle.on.rectangle.angled", color: P.navy, blob: P.lavender, corner: .topLeading) {
                        router.open(.cards(cardsDeck))
                    }
                    Tile(id: "tile-reverse", title: "Reverse", note: "Find the root", symbol: "x.squareroot", color: P.yellow, blob: P.coral, corner: .topLeading) {
                        router.open(.reverse)
                    }
                }

                trick
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(P.bg)
        .sheet(isPresented: $picking) { RivalPicker().presentationDetents([.large]) }
        .sheet(isPresented: $avatars) { AvatarPicker().presentationDetents([.medium, .large]) }
    }

    private var streak: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
            Text(verbatim: "\(store.liveStreak)").monospacedDigit()
        }
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(store.liveStreak > 0 ? .white : P.muted)
        .padding(.horizontal, 14).frame(height: 40)
        .background(store.liveStreak > 0 ? P.coral : P.card, in: Capsule())
        .accessibilityLabel(Text("Days in a row: \(store.liveStreak)"))
    }

    private var cardsDeck: [Int] {
        let open = Store.range.filter { !store.cell($0).captured }
        let pool = open.isEmpty ? Array(Store.range) : open
        return Array(pool.prefix(30).shuffled().prefix(15))
    }

    // MARK: daily card

    private var daily: some View {
        let deck = store.dailyDeck()
        let fading = store.fading.count
        let fresh = deck.filter { store.state($0) == .free }.count
        return Button {
            router.open(.drill(deck.isEmpty ? Array(Store.range.filter { store.cell($0).captured }.shuffled().prefix(12)) : deck))
        } label: {
            ZStack(alignment: .bottomLeading) {
                // a clear base fixes the size, so the filled picture can never widen the card
                HeroArt().frame(height: 210).frame(maxWidth: .infinity)
                    // mirrored in right-to-left languages, so the rabbit stays clear of the text
                    .overlay(LinearGradient(colors: [P.jungle, P.jungle.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                        .flipsForRightToLeftLayoutDirection(true))
                    .clipped()
                VStack(alignment: .leading, spacing: 10) {
                    Text(deck.isEmpty ? "Field defended" : "Defend the field")
                        .font(.system(size: 26, weight: .heavy))
                    if deck.isEmpty {
                        Text("Come back tomorrow, or practice a bit more")
                            .font(.system(size: 15, weight: .medium)).opacity(0.85)
                    } else {
                        // side by side when they fit, stacked in long languages
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                if fading > 0 { Pill(text: String(localized: "Fading: \(fading)"), color: P.coral) }
                                if fresh > 0 { Pill(text: String(localized: "New: \(fresh)"), color: P.lavender) }
                                if fading == 0 && fresh == 0 { Pill(text: String(localized: "Keep capturing"), color: P.coral) }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                if fading > 0 { Pill(text: String(localized: "Fading: \(fading)"), color: P.coral) }
                                if fresh > 0 { Pill(text: String(localized: "New: \(fresh)"), color: P.lavender) }
                                if fading == 0 && fresh == 0 { Pill(text: String(localized: "Keep capturing"), color: P.coral) }
                            }
                        }
                    }
                    HStack(spacing: 6) {
                        Text("Captured")
                        Text(verbatim: "\(store.capturedCount)/90").monospacedDigit()
                    }
                    .font(.system(size: 15, weight: .bold)).opacity(0.9)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 230, alignment: .leading)
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(PressStyle()).tapFeedback()
        .accessibilityIdentifier("daily")
    }

    // MARK: trick of the day

    private var trick: some View {
        let (lesson, n) = Lesson.ofTheDay(store.today)
        let steps = lesson.steps(n)
        return Button { router.open(.lesson(lesson.id)) } label: {
            HStack(spacing: 14) {
                LessonBadge(lesson: lesson, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trick of the day").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.coral)
                    Text(lesson.title).font(.system(size: 18, weight: .bold)).foregroundStyle(P.ink)
                    Text(verbatim: steps.dropFirst().first?.expr ?? "").font(.system(size: 15, weight: .medium)).foregroundStyle(P.muted)
                        .environment(\.layoutDirection, .leftToRight)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(P.muted)
            }
            .card()
        }
        .buttonStyle(PressStyle()).tapFeedback()
        .accessibilityIdentifier("trick")
    }
}

/// Colorful game tile with a decorative circle in one corner.
struct Tile: View {
    var id: String
    var title: LocalizedStringKey
    var note: LocalizedStringKey
    var symbol: String
    var color: Color
    var blob: Color
    var corner: Alignment
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Spacer()
                    Image(systemName: symbol).font(.system(size: 24, weight: .semibold))
                }
                Spacer(minLength: 18)
                Text(title).font(.system(size: 20, weight: .bold)).lineLimit(2).minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Text(note).font(.system(size: 13, weight: .medium)).opacity(0.85).lineLimit(2).minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .background { ZStack { color; CornerBlob(color: blob, corner: corner, size: 64) } }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressStyle()).tapFeedback()
        .accessibilityIdentifier(id)
    }
}

// MARK: - pickers

struct RivalPicker: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Underlined(text: "Choose a rival").padding(.top, 28)
                Text("A race of 20 squares. Whoever finishes first wins")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(P.muted)
                    .padding(.bottom, 6)
                row(art: "bot-ghost", title: "Ghost", note: store.data.bestRace.map { String(localized: "Your best run, \(seconds($0))") }
                    ?? String(localized: "Finish any race to meet your ghost"),
                    badge: store.data.ghostBeaten ? "checkmark.seal.fill" : nil, locked: store.data.bestRace == nil, id: "rival-ghost") {
                    go(.ghost)
                }
                ForEach(Bot.allCases) { b in
                    row(art: b.art, title: b.name, note: b.note, badge: store.data.botsBeaten.contains(b) ? "checkmark.seal.fill" : nil,
                        locked: !store.unlocked(b), id: "rival-\(b.rawValue)") { go(.bot(b)) }
                }
            }
            .padding(.horizontal, 20)
        }
        .background(P.bg)
    }

    private func go(_ o: Store.Opponent) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.open(.race(o)) }
    }

    private func row(art: String, title: LocalizedStringResource, note: String, badge: String?, locked: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Avatar(name: art, size: 64).saturation(locked ? 0 : 1).opacity(locked ? 0.5 : 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 19, weight: .bold)).foregroundStyle(P.ink)
                    Text(note).font(.system(size: 14, weight: .medium)).foregroundStyle(P.muted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(P.muted)
                } else if let badge {
                    Image(systemName: badge).font(.system(size: 22)).foregroundStyle(P.green)
                } else {
                    // play triangles look centered when nudged right a little
                    Image(systemName: "play.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .offset(x: 1.5)
                        .frame(width: 38, height: 38).background(P.coral, in: Circle())
                }
            }
            .card()
        }
        .buttonStyle(PressStyle()).tapFeedback()
        .disabled(locked)
        .accessibilityIdentifier(id)
    }
}

func seconds(_ t: Double) -> String {
    String(localized: "\(String(format: "%.1f", t)) s")
}

extension Bot {
    var name: LocalizedStringResource {
        switch self { case .rookie: "Turtle"; case .honor: "Owl"; case .calculator: "Robot" }
    }
    var note: String {
        switch self {
        case .rookie: String(localized: "Slow and sometimes wrong")
        case .honor: String(localized: "About two seconds per answer")
        case .calculator: String(localized: "Never makes mistakes. Beat Owl to unlock")
        }
    }
}

struct AvatarPicker: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Underlined(text: "Choose avatar").padding(.top, 28)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
                    ForEach(Avatars.names.indices, id: \.self) { i in
                        Button {
                            Feel.correct()
                            store.data.avatar = i
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { dismiss() }
                        } label: {
                            Avatar(name: Avatars.names[i], size: 96)
                                .overlay(alignment: .bottomTrailing) {
                                    if store.data.avatar == i {
                                        Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                                            .frame(width: 32, height: 32).background(P.green, in: Circle())
                                            .overlay(Circle().strokeBorder(P.bg, lineWidth: 3))
                                    }
                                }
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("avatar-\(i)")
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .background(P.bg)
    }
}

/// The banner picture, filled and pinned to the trailing edge, drawn within its bounds.
struct HeroArt: View {
    var body: some View {
        Canvas { ctx, s in
            guard let img = ctx.resolveSymbol(id: 0) else { return }
            let iw = img.size.width, ih = img.size.height
            let k = max(s.width / iw, s.height / ih)
            let w = iw * k, h = ih * k
            ctx.draw(img, in: CGRect(x: s.width - w, y: (s.height - h) / 2, width: w, height: h))
        } symbols: {
            Image("hero").resizable().frame(width: 1400, height: 781).tag(0)
        }
        .flipsForRightToLeftLayoutDirection(true)
        .accessibilityHidden(true)
    }
}

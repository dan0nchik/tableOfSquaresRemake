import SwiftUI

@main
struct TableOfSquaresApp: App {
    @State private var store = Store(url: Demo.on || Demo.fresh || Demo.done ? nil : Store.defaultURL)
    @State private var router = Router()

    init() {
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(P.coral)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .tint(P.coral)
                .onAppear { Demo.prepare(store) }
        }
    }
}

/// Full-screen flows opened from anywhere.
enum Route: Identifiable, Hashable {
    case drill([Int])
    case cards([Int])
    case race(Store.Opponent)
    case reverse
    case duel
    case lesson(Int)
    case visual

    var id: Self { self }
}

@Observable
final class Router {
    var route: Route?
    var tab = 0
    func open(_ r: Route) { route = r }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            LearnView()
                .tabItem { Label("Learn", systemImage: "lightbulb.fill") }.tag(1)
            FieldView()
                .tabItem { Label("Field", systemImage: "square.grid.3x3.fill") }.tag(2)
            ProfileView()
                .tabItem { Label("Trophies", systemImage: "trophy.fill") }.tag(3)
        }
        .onChange(of: router.tab) { _, _ in Feel.tick() }
        .fullScreenCover(item: $router.route) { r in
            Group {
                switch r {
                case .drill(let deck): DrillView(deck: deck)
                case .cards(let deck): CardsView(deck: deck)
                case .race(let o): RaceView(opponent: o)
                case .reverse: ReverseView()
                case .duel: DuelView()
                case .lesson(let id): LessonView(lesson: Lesson.all[id])
                case .visual: VisualSquareView()
                }
            }
            .environment(store)
            .environment(router)
            .tint(P.coral)
            .overlay(alignment: .top) { AchievementToast(active: true) }
        }
        .overlay(alignment: .top) { AchievementToast(active: router.route == nil) }
    }
}

/// Pops a banner when an achievement unlocks.
struct AchievementToast: View {
    @Environment(Store.self) private var store
    var active: Bool
    @State private var shown: Achievement?

    var body: some View {
        ZStack {
            if let a = shown {
                HStack(spacing: 12) {
                    Image(systemName: a.symbol).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).background(P.coral, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Achievement unlocked").font(.system(size: 13, weight: .semibold)).foregroundStyle(P.muted)
                        Text(a.title).font(.system(size: 17, weight: .bold)).foregroundStyle(P.ink)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(P.raised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: shown)
        .onChange(of: store.fresh) { _, list in
            guard active, shown == nil, let a = list.first else { return }
            store.fresh.removeFirst()
            shown = a
            Feel.win()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                shown = nil
                if !store.fresh.isEmpty { store.fresh = store.fresh }
            }
        }
    }
}

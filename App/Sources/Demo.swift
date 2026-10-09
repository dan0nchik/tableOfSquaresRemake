import Foundation

/// `-demo` launch argument: a believable progress state for screenshots, never saved to disk.
enum Demo {
    static let on = ProcessInfo.processInfo.arguments.contains("-demo")
    /// `-fresh`: an empty in-memory profile, for tests.
    static let fresh = ProcessInfo.processInfo.arguments.contains("-fresh")
    /// `-done`: the whole field captured and nothing due today.
    static let done = ProcessInfo.processInfo.arguments.contains("-done")

    static func prepare(_ store: Store) {
        if on { fill(store) }
        if done { fillDone(store) }
    }

    static func fillDone(_ store: Store) {
        var d = SaveData()
        for n in Store.range {
            var c = Cell(); c.captured = true; c.hits = 3; c.interval = 14; c.dueDay = store.today + 10
            d.cells[n] = c
        }
        d.unlocked = Dictionary(uniqueKeysWithValues: ["firstCell", "fullRow", "half", "field"].map { ($0, Date()) })
        store.data = d
    }

    static func fill(_ store: Store) {
        var d = SaveData()
        let t = store.today
        for n in Store.range {
            var c = Cell()
            switch n {
            case 10...38, 40, 41, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 99:
                c.captured = true; c.hits = 3; c.interval = 7; c.dueDay = t + 3
            case 67, 76, 87, 39:
                c.captured = true; c.hits = 3; c.interval = 3; c.dueDay = t - 1
            case 42, 43, 44, 51, 52, 61:
                c.hits = n % 2 + 1; c.lastHitDay = t - 1
            default: break
            }
            c.right = c.hits * 2
            d.cells[n] = c
        }
        d.streak = 12; d.bestStreak = 12; d.lastActiveDay = t - 1
        d.bestRace = 31.4
        d.bestSplits = (1...Store.raceLength).map { Double($0) * 1.57 }
        d.botsBeaten = [.rookie]
        d.races = 9; d.duels = 4
        d.lessonsDone = [0, 1]
        d.avatar = 8
        d.unlocked = ["firstCell": Date(), "fullRow": Date(), "streak7": Date(), "rookie": Date()]
        store.data = d
        store.fresh = []
    }
}

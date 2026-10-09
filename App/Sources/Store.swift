import Foundation
import Observation

/// One square on the field, 10² … 99².
struct Cell: Codable, Equatable {
    var hits = 0               // correct answers on distinct days while capturing
    var lastHitDay: Int?
    var captured = false
    var interval = 0           // days until it starts fading
    var dueDay = 0
    var right = 0
    var wrong = 0

    enum State: Equatable { case free, progress(Int), captured, fading }

    func state(today: Int) -> State {
        if captured { return today >= dueDay ? .fading : .captured }
        return hits == 0 ? .free : .progress(hits)
    }
}

enum Bot: String, CaseIterable, Codable, Identifiable {
    case rookie, honor, calculator
    var id: String { rawValue }

    /// Mean seconds per answer and chance to miss one.
    var pace: Double { switch self { case .rookie: 4.2; case .honor: 2.3; case .calculator: 1.25 } }
    var missRate: Double { switch self { case .rookie: 0.15; case .honor: 0.05; case .calculator: 0 } }
    var art: String { switch self { case .rookie: "bot-turtle"; case .honor: "bot-owl"; case .calculator: "bot-robot" } }
}

struct SaveData: Codable, Equatable {
    var cells: [Int: Cell] = [:]
    var streak = 0
    var bestStreak = 0
    var lastActiveDay: Int?
    var bestRace: Double?
    var bestSplits: [Double] = []
    var botsBeaten: Set<Bot> = []
    var ghostBeaten = false
    var races = 0
    var duels = 0
    var lessonsDone: Set<Int> = []
    var unlocked: [String: Date] = [:]
    var avatar = 0
    var sound = true
    var haptics = true
}

@Observable
final class Store {
    static let range = 10...99
    static let raceLength = 20
    /// Spaced repetition ladder, in days.
    static let ladder = [3, 7, 14, 30, 60, 120]

    var data: SaveData { didSet { if data != oldValue { save() } } }
    /// Achievements unlocked since the last time the UI showed them.
    var fresh: [Achievement] = []

    private let url: URL?
    private let clock: () -> Date

    init(url: URL? = Store.defaultURL, clock: @escaping () -> Date = Date.init) {
        self.url = url
        self.clock = clock
        if let url, let raw = try? Data(contentsOf: url), let d = try? JSONDecoder().decode(SaveData.self, from: raw) {
            data = d
        } else {
            data = SaveData()
        }
        Feel.sound = data.sound
        Feel.haptics = data.haptics
    }

    static var defaultURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress.json")
    }

    private func save() {
        guard let url, let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: url, options: .atomic)
    }

    // MARK: days

    var today: Int { Store.day(clock()) }

    static func day(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let start = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: .gmt, year: c.year, month: c.month, day: c.day)) ?? date
        return Int(start.timeIntervalSince1970 / 86_400)
    }

    // MARK: field

    func cell(_ n: Int) -> Cell { data.cells[n] ?? Cell() }
    func state(_ n: Int) -> Cell.State { cell(n).state(today: today) }

    var capturedCount: Int { Store.range.filter { cell($0).captured }.count }
    var fading: [Int] { Store.range.filter { state($0) == .fading }.sorted { cell($0).dueDay < cell($1).dueDay } }

    /// Records an answer. Returns true when this answer captured the cell.
    @discardableResult
    func record(_ n: Int, correct: Bool) -> Bool {
        guard Store.range.contains(n) else { return false }
        var c = cell(n)
        let t = today
        var captured = false
        if correct {
            c.right += 1
            if c.captured {
                if t >= c.dueDay {
                    let i = Store.ladder.firstIndex { $0 > c.interval } ?? Store.ladder.count - 1
                    c.interval = Store.ladder[i]
                    c.dueDay = t + c.interval
                }
            } else if c.lastHitDay != t {
                c.hits += 1
                c.lastHitDay = t
                if c.hits >= 3 {
                    c.captured = true
                    c.interval = Store.ladder[0]
                    c.dueDay = t + c.interval
                    captured = true
                }
            }
        } else {
            c.wrong += 1
            if c.captured {
                if t >= c.dueDay {
                    c = Cell(hits: 1, lastHitDay: t, right: c.right, wrong: c.wrong)
                } else {
                    c.interval = max(1, c.interval / 2)
                    c.dueDay = t + c.interval
                }
            } else {
                c.hits = max(0, c.hits - 1)
            }
        }
        data.cells[n] = c
        checkAchievements()
        return captured
    }

    /// Today's run: fading cells first, then cells being captured, then fresh ones in order.
    func dailyDeck(size: Int = 12) -> [Int] {
        let t = today
        var deck = Array(fading.prefix(size))
        let started = Store.range.filter { if case .progress = state($0) { return cell($0).lastHitDay != t }; return false }
        deck += started.prefix(size - deck.count)
        let fresh = Store.range.filter { state($0) == .free }
        deck += fresh.prefix(max(0, min(5, size - deck.count)))
        return deck
    }

    var dailyDone: Bool { dailyDeck().isEmpty }

    // MARK: sessions

    func finishSession() {
        let t = today
        if data.lastActiveDay != t {
            data.streak = data.lastActiveDay == t - 1 ? data.streak + 1 : 1
            data.lastActiveDay = t
            data.bestStreak = max(data.bestStreak, data.streak)
        }
        checkAchievements()
    }

    /// Streak shown in the UI: zero once a day has been skipped.
    var liveStreak: Int {
        guard let last = data.lastActiveDay, last >= today - 1 else { return 0 }
        return data.streak
    }

    enum Opponent: Hashable { case ghost, bot(Bot) }

    /// Saves a finished race, returns whether it is a new personal best.
    @discardableResult
    func finishRace(time: Double, splits: [Double], against: Opponent, won: Bool) -> Bool {
        data.races += 1
        if won {
            switch against {
            case .ghost: data.ghostBeaten = true
            case .bot(let b): data.botsBeaten.insert(b)
            }
        }
        let best = won && (data.bestRace.map { time < $0 } ?? true)
        if best {
            data.bestRace = time
            data.bestSplits = splits
        }
        finishSession()
        return best
    }

    func unlocked(_ bot: Bot) -> Bool {
        switch bot {
        case .rookie: true
        case .honor: data.botsBeaten.contains(.rookie) || data.bestRace != nil
        case .calculator: data.botsBeaten.contains(.honor)
        }
    }

    func finishDuel() {
        data.duels += 1
        finishSession()
    }

    func finishLesson(_ id: Int) {
        data.lessonsDone.insert(id)
        finishSession()
    }

    func reset() {
        let keep = (data.avatar, data.sound, data.haptics)
        data = SaveData()
        (data.avatar, data.sound, data.haptics) = keep
    }

    // MARK: achievements

    func progress(_ a: Achievement) -> (Int, Int) {
        let rows = stride(from: 10, to: 100, by: 10).map { d in (d..<d + 10).filter { cell($0).captured }.count }
        switch a {
        case .firstCell: return (min(1, capturedCount), 1)
        case .fullRow: return (rows.max() ?? 0, 10)
        case .half: return (min(45, capturedCount), 45)
        case .field: return (capturedCount, 90)
        case .streak7: return (min(7, data.bestStreak), 7)
        case .streak30: return (min(30, data.bestStreak), 30)
        case .ghost: return (data.ghostBeaten ? 1 : 0, 1)
        case .rookie: return (data.botsBeaten.contains(.rookie) ? 1 : 0, 1)
        case .honor: return (data.botsBeaten.contains(.honor) ? 1 : 0, 1)
        case .calculator: return (data.botsBeaten.contains(.calculator) ? 1 : 0, 1)
        case .sub30: return ((data.bestRace ?? 999) < 30 ? 1 : 0, 1)
        case .tricks: return (data.lessonsDone.count, Lesson.all.count)
        case .duels: return (min(10, data.duels), 10)
        }
    }

    private func checkAchievements() {
        for a in Achievement.allCases where data.unlocked[a.rawValue] == nil {
            let (v, goal) = progress(a)
            if v >= goal {
                data.unlocked[a.rawValue] = clock()
                fresh.append(a)
            }
        }
    }
}

enum Achievement: String, CaseIterable, Identifiable {
    case firstCell, fullRow, half, field, streak7, streak30, ghost, rookie, honor, calculator, sub30, tricks, duels
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .firstCell: "square.fill"
        case .fullRow: "rectangle.split.3x1.fill"
        case .half: "square.grid.3x3.fill"
        case .field: "crown.fill"
        case .streak7: "flame.fill"
        case .streak30: "flame.circle.fill"
        case .ghost: "figure.run"
        case .rookie: "tortoise.fill"
        case .honor: "graduationcap.fill"
        case .calculator: "cpu.fill"
        case .sub30: "bolt.fill"
        case .tricks: "lightbulb.fill"
        case .duels: "person.2.fill"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .firstCell: "First cell"
        case .fullRow: "Full row"
        case .half: "Half the field"
        case .field: "The whole field"
        case .streak7: "7 days in a row"
        case .streak30: "30 days in a row"
        case .ghost: "Beat your ghost"
        case .rookie: "Overtook Turtle"
        case .honor: "Overtook Owl"
        case .calculator: "Overtook Robot"
        case .sub30: "Race under 30 seconds"
        case .tricks: "All tricks learned"
        case .duels: "10 duels"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .firstCell: "Capture your first square"
        case .fullRow: "Capture a whole row of ten"
        case .half: "Capture 45 squares"
        case .field: "Capture all 90 squares"
        case .streak7: "Practice a week without a break"
        case .streak30: "Practice a month without a break"
        case .ghost: "Finish faster than your record"
        case .rookie: "Win a race against Turtle"
        case .honor: "Win a race against Owl"
        case .calculator: "Win a race against Robot"
        case .sub30: "20 answers in less than 30 seconds"
        case .tricks: "Finish every lesson"
        case .duels: "Play 10 duels with friends"
        }
    }
}

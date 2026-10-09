import XCTest
@testable import TableOfSquares

/// A clock the tests can move forward day by day.
final class Clock {
    var now = Date(timeIntervalSince1970: 1_790_000_000)
    func advance(days: Int) { now = Calendar.current.date(byAdding: .day, value: days, to: now)! }
}

final class StoreTests: XCTestCase {
    var clock: Clock!
    var store: Store!

    override func setUp() {
        clock = Clock()
        let c = clock!
        store = Store(url: nil, clock: { c.now })
    }

    private func capture(_ n: Int) {
        for _ in 0..<3 { store.record(n, correct: true); clock.advance(days: 1) }
    }

    // MARK: capturing

    func testCaptureNeedsThreeDifferentDays() {
        XCTAssertFalse(store.record(42, correct: true))
        XCTAssertFalse(store.record(42, correct: true), "same day counts once")
        XCTAssertEqual(store.state(42), .progress(1))
        clock.advance(days: 1)
        XCTAssertFalse(store.record(42, correct: true))
        XCTAssertEqual(store.state(42), .progress(2))
        clock.advance(days: 1)
        XCTAssertTrue(store.record(42, correct: true))
        XCTAssertEqual(store.state(42), .captured)
        XCTAssertEqual(store.capturedCount, 1)
        XCTAssertEqual(store.cell(42).right, 4)
    }

    func testWrongAnswerWhileCapturingLosesAHit() {
        store.record(30, correct: true)
        store.record(30, correct: false)
        XCTAssertEqual(store.state(30), .free)
        store.record(30, correct: false)
        XCTAssertEqual(store.cell(30).hits, 0, "never negative")
        XCTAssertEqual(store.cell(30).wrong, 2)
    }

    func testOutOfRangeIsIgnored() {
        XCTAssertFalse(store.record(9, correct: true))
        XCTAssertFalse(store.record(100, correct: true))
        XCTAssertTrue(store.data.cells.isEmpty)
    }

    func testCapturedCellFadesAndClimbsTheLadder() {
        capture(55)
        let c = store.cell(55)
        XCTAssertEqual(c.interval, Store.ladder[0])
        // before it is due, right answers do not change the schedule
        store.record(55, correct: true)
        XCTAssertEqual(store.cell(55).dueDay, c.dueDay)
        clock.advance(days: 3)
        XCTAssertEqual(store.state(55), .fading)
        XCTAssertEqual(store.fading, [55])
        store.record(55, correct: true)
        XCTAssertEqual(store.state(55), .captured)
        XCTAssertEqual(store.cell(55).interval, 7)
        // walk to the top of the ladder and stay there
        for _ in 0..<8 {
            clock.advance(days: store.cell(55).interval)
            store.record(55, correct: true)
        }
        XCTAssertEqual(store.cell(55).interval, Store.ladder.last)
    }

    func testWrongWhileCapturedHalvesInterval() {
        capture(61)
        clock.advance(days: 3)
        store.record(61, correct: true) // interval 7
        store.record(61, correct: false)
        XCTAssertEqual(store.cell(61).interval, 3)
        XCTAssertTrue(store.cell(61).captured)
    }

    func testWrongWhileFadingLosesTheCell() {
        capture(77)
        clock.advance(days: 5)
        XCTAssertEqual(store.state(77), .fading)
        store.record(77, correct: false)
        XCTAssertEqual(store.state(77), .progress(1))
        XCTAssertFalse(store.cell(77).captured)
    }

    // MARK: daily deck

    func testDailyDeckPrefersFadingThenStartedThenNew() {
        capture(20)
        store.record(33, correct: true)
        clock.advance(days: 3)
        let deck = store.dailyDeck()
        XCTAssertEqual(deck.first, 20)
        XCTAssertEqual(deck[1], 33)
        XCTAssertEqual(Array(deck.dropFirst(2)), [10, 11, 12, 13, 14])
        XCTAssertFalse(store.dailyDone)
    }

    func testDailyDeckEmptyWhenEverythingIsDone() {
        for n in Store.range {
            var c = Cell(); c.captured = true; c.hits = 3; c.interval = 7; c.dueDay = store.today + 7
            store.data.cells[n] = c
        }
        XCTAssertTrue(store.dailyDeck().isEmpty)
        XCTAssertTrue(store.dailyDone)
        XCTAssertEqual(store.capturedCount, 90)
    }

    func testStartedCellsAnsweredTodayAreSkipped() {
        store.record(15, correct: true)
        XCTAssertFalse(store.dailyDeck().contains(15))
    }

    // MARK: streak

    func testStreakCountsConsecutiveDays() {
        XCTAssertEqual(store.liveStreak, 0)
        store.finishSession()
        store.finishSession()
        XCTAssertEqual(store.data.streak, 1)
        clock.advance(days: 1)
        store.finishSession()
        XCTAssertEqual(store.liveStreak, 2)
        clock.advance(days: 1)
        XCTAssertEqual(store.liveStreak, 2, "still alive the day after")
        clock.advance(days: 1)
        XCTAssertEqual(store.liveStreak, 0, "a skipped day breaks it")
        store.finishSession()
        XCTAssertEqual(store.data.streak, 1)
        XCTAssertEqual(store.data.bestStreak, 2)
    }

    // MARK: races and unlocks

    func testRaceRecordsAndUnlocks() {
        XCTAssertTrue(store.unlocked(.rookie))
        XCTAssertFalse(store.unlocked(.honor))
        XCTAssertFalse(store.unlocked(.calculator))

        XCTAssertFalse(store.finishRace(time: 50, splits: [], against: .bot(.rookie), won: false))
        XCTAssertNil(store.data.bestRace, "a lost race is not a record")

        XCTAssertTrue(store.finishRace(time: 40, splits: [1, 2], against: .bot(.rookie), won: true))
        XCTAssertEqual(store.data.bestRace, 40)
        XCTAssertTrue(store.unlocked(.honor))
        XCTAssertFalse(store.finishRace(time: 45, splits: [], against: .bot(.honor), won: true))
        XCTAssertEqual(store.data.bestSplits, [1, 2])
        XCTAssertTrue(store.unlocked(.calculator))

        XCTAssertTrue(store.finishRace(time: 29, splits: [3], against: .ghost, won: true))
        XCTAssertTrue(store.data.ghostBeaten)
        XCTAssertEqual(store.data.races, 4)
        XCTAssertNotNil(store.data.unlocked[Achievement.sub30.rawValue])
        XCTAssertNotNil(store.data.unlocked[Achievement.ghost.rawValue])
    }

    func testBotsHaveDistinctPaces() {
        XCTAssertGreaterThan(Bot.rookie.pace, Bot.honor.pace)
        XCTAssertGreaterThan(Bot.honor.pace, Bot.calculator.pace)
        XCTAssertEqual(Bot.calculator.missRate, 0)
        XCTAssertEqual(Set(Bot.allCases.map(\.art)).count, 3)
        XCTAssertEqual(Set(Bot.allCases.map(\.id)).count, 3)
        for b in Bot.allCases {
            XCTAssertFalse(String(localized: b.name).isEmpty)
            XCTAssertFalse(b.note.isEmpty)
        }
    }

    // MARK: achievements

    func testAchievementsUnlockOnceAndQueueForTheToast() {
        capture(10)
        XCTAssertEqual(store.fresh, [.firstCell])
        XCTAssertNotNil(store.data.unlocked["firstCell"])
        capture(11)
        XCTAssertEqual(store.fresh, [.firstCell], "not unlocked twice")

        for _ in 0..<10 { store.finishDuel() }
        XCTAssertNotNil(store.data.unlocked["duels"])

        for l in Lesson.all { store.finishLesson(l.id) }
        XCTAssertNotNil(store.data.unlocked["tricks"])
    }

    func testEveryAchievementReportsProgress() {
        for a in Achievement.allCases {
            let (v, goal) = store.progress(a)
            XCTAssertEqual(v, 0, a.rawValue)
            XCTAssertGreaterThan(goal, 0)
            XCTAssertFalse(a.symbol.isEmpty)
            XCTAssertFalse(String(localized: a.title).isEmpty)
            XCTAssertFalse(String(localized: a.detail).isEmpty)
            XCTAssertEqual(a.id, a.rawValue)
        }
        Demo.fill(store)
        for a in Achievement.allCases {
            let (v, goal) = store.progress(a)
            XCTAssertLessThanOrEqual(v, max(goal, v))
        }
        XCTAssertEqual(store.progress(.fullRow).0, 10)
        XCTAssertEqual(store.progress(.rookie).0, 1)
        XCTAssertEqual(store.progress(.streak7).0, 7)
    }

    // MARK: persistence

    func testSavesAndLoads() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let a = Store(url: url, clock: { self.clock.now })
        a.record(44, correct: true)
        a.data.avatar = 5
        let b = Store(url: url, clock: { self.clock.now })
        XCTAssertEqual(b.cell(44).hits, 1)
        XCTAssertEqual(b.data.avatar, 5)
    }

    func testCorruptedFileFallsBackToEmpty() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        let s = Store(url: url)
        XCTAssertEqual(s.data, SaveData())
        XCTAssertNotNil(Store.defaultURL)
    }

    func testResetKeepsPreferences() {
        store.data.avatar = 3
        store.data.sound = false
        store.data.haptics = false
        capture(50)
        store.reset()
        XCTAssertEqual(store.capturedCount, 0)
        XCTAssertEqual(store.data.avatar, 3)
        XCTAssertFalse(store.data.sound)
        XCTAssertFalse(store.data.haptics)
    }

    func testDayIsStableWithinADay() {
        let d = Store.day(clock.now)
        XCTAssertEqual(Store.day(clock.now.addingTimeInterval(1)), d)
        clock.advance(days: 1)
        XCTAssertEqual(Store.day(clock.now), d + 1)
    }

    func testDemoFillsABelievableProfile() {
        Demo.fill(store)
        XCTAssertGreaterThan(store.capturedCount, 40)
        XCTAssertFalse(store.fading.isEmpty)
        XCTAssertEqual(store.data.bestSplits.count, Store.raceLength)
        XCTAssertTrue(store.fresh.isEmpty)
    }
}

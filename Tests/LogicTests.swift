import XCTest
@testable import TableOfSquares

final class LogicTests: XCTestCase {

    // MARK: typing

    func testTypingChecksWhenComplete() {
        var t = Typing()
        t.reset(2209)
        XCTAssertNil(t.type(0), "leading zero ignored")
        XCTAssertNil(t.type(2))
        XCTAssertNil(t.type(2))
        t.erase()
        XCTAssertEqual(t.text, "2")
        XCTAssertNil(t.type(2))
        XCTAssertNil(t.type(0))
        XCTAssertEqual(t.type(9), .right)
        XCTAssertTrue(t.locked)
        XCTAssertNil(t.type(1), "locked after a verdict")
        t.erase()
        XCTAssertEqual(t.text, "2209", "erase does nothing once locked")
    }

    func testTypingWrongAnswer() {
        var t = Typing()
        t.reset(144)
        _ = t.type(1); _ = t.type(4)
        XCTAssertEqual(t.type(5), .wrong)
        t.reset(100)
        XCTAssertEqual(t.text, "")
        XCTAssertEqual(t.verdict, .none)
        t.erase()
        XCTAssertEqual(t.text, "")
    }

    // MARK: choices

    func testSquareChoices() {
        for n in 11...99 {
            let c = Choices.squares(n)
            XCTAssertEqual(c.count, 4)
            XCTAssertEqual(Set(c).count, 4)
            XCTAssertTrue(c.contains(n * n))
            XCTAssertTrue(c.allSatisfy { $0 > 0 })
        }
    }

    func testRootChoices() {
        for n in 11...99 {
            let c = Choices.roots(n)
            XCTAssertEqual(c.count, 4, "\(n)")
            XCTAssertEqual(Set(c).count, 4)
            XCTAssertTrue(c.contains(n))
            XCTAssertTrue(c.allSatisfy { (11...99).contains($0) })
        }
    }

    func testTipMatchesLastDigit() {
        for n in 11...99 {
            let tip = Choices.tip(n * n)
            XCTAssertTrue(tip.contains("\(n % 10)") || tip.contains("\(10 - n % 10)"), tip)
        }
    }

    // MARK: lessons

    func testEveryLessonEndsWithTheRightSquare() {
        for l in Lesson.all {
            XCTAssertEqual(l.steps(l.sample).count, 4)
            for n in l.numbers {
                let steps = l.steps(n)
                XCTAssertEqual(steps.last?.expr, "\(n)² = \(n * n)", "\(l.id) \(n)")
            }
        }
    }

    func testTrickArithmetic() {
        // ending in 5: a(a+1) then 25
        for n in Lesson.all[0].numbers { let a = n / 10; XCTAssertEqual(a * (a + 1) * 100 + 25, n * n) }
        // close to 50: (25 + k) hundreds + k²
        for n in Lesson.all[1].numbers { let k = n - 50; XCTAssertEqual((25 + k) * 100 + k * k, n * n) }
        // close to 100: (n − k) hundreds + k²
        for n in Lesson.all[2].numbers { let k = 100 - n; XCTAssertEqual((n - k) * 100 + k * k, n * n) }
        // next door: (n−1)² + (n−1) + n
        for n in Lesson.all[3].numbers { XCTAssertEqual((n - 1) * (n - 1) + (n - 1) + n, n * n) }
    }

    func testCloseTo50ShowsSignAndPadding() {
        let steps = Lesson.all[1].steps(47)
        XCTAssertEqual(steps[0].expr, "47 = 50 − 3")
        XCTAssertEqual(steps[2].expr, "3² = 09")
        XCTAssertEqual(Lesson.all[1].steps(53)[0].expr, "53 = 50 + 3")
    }

    func testLessonOfTheDayIsAlwaysValid() {
        for day in [-400, -1, 0, 1, 7, 20_000, 123_456] {
            let (l, n) = Lesson.ofTheDay(day)
            XCTAssertTrue(l.numbers.contains(n))
        }
        XCTAssertEqual(Set((0..<4).map { Lesson.ofTheDay($0).0.id }).count, 4)
    }

    // MARK: daily square

    func testSquareOfTheDay() {
        var seen = Set<Int>()
        var date = Date(timeIntervalSince1970: 1_790_000_000)
        for _ in 0..<60 {
            let n = Daily.number(on: date)
            XCTAssertTrue((10...99).contains(n))
            seen.insert(n)
            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        }
        XCTAssertGreaterThan(seen.count, 30)
        XCTAssertEqual(Daily.number(on: date), Daily.number(on: date.addingTimeInterval(60)))
    }

    // MARK: formatting and feel

    func testFormatting() {
        XCTAssertEqual(sq(47), "2209")
        XCTAssertEqual(sq(99), "9801")
        XCTAssertTrue(seconds(31.44).contains("31.4"))
        XCTAssertEqual(Avatars.name(-1), Avatars.names.last)
        XCTAssertEqual(Avatars.name(Avatars.names.count), Avatars.names.first)
    }

    func testFeedbackRunsWithAndWithoutHaptics() {
        for (sound, haptics) in [(true, true), (false, false)] {
            Feel.sound = sound
            Feel.haptics = haptics
            Feel.tap(); Feel.key(); Feel.tick(); Feel.flip()
            Feel.correct(); Feel.correct(combo: 30); Feel.wrong()
            Feel.capture(); Feel.win(); Feel.lose(); Feel.pressure()
        }
        Feel.sound = true
        Feel.haptics = true
        for s in Synth.Sfx.allCases { Synth.shared.play(s) }
        let exp = expectation(description: "delayed haptics")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { exp.fulfill() }
        wait(for: [exp], timeout: 2)
    }

    func testCellStates() {
        var c = Cell()
        XCTAssertEqual(c.state(today: 5), .free)
        c.hits = 2
        XCTAssertEqual(c.state(today: 5), .progress(2))
        c.captured = true; c.dueDay = 6
        XCTAssertEqual(c.state(today: 5), .captured)
        XCTAssertEqual(c.state(today: 6), .fading)
        for s in [Cell.State.free, .progress(1), .progress(2), .captured, .fading] {
            _ = s.color; _ = s.ink
        }
    }
}

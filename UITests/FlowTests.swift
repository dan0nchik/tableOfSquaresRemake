import XCTest

/// End-to-end runs through every screen, answering like a real player.
final class FlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @discardableResult
    func launch(_ profile: String = "-demo", lang: String = "en") -> XCUIApplication {
        app = XCUIApplication()
        app.launchArguments = [profile, "-AppleLanguages", "(\(lang))", "-AppleLocale", lang]
        app.launch()
        return app
    }

    // MARK: helpers

    var question: Int? {
        let q = app.descendants(matching: .any).matching(identifier: "question").firstMatch
        guard q.waitForExistence(timeout: 5), let v = q.value as? String else { return nil }
        return Int(v)
    }

    func type(_ number: Int) {
        for ch in String(number) { app.buttons["key-\(ch)"].tap() }
    }

    /// Answers keypad questions until a result screen shows up.
    func answerUntilDone(wrongFirst: Bool = false, limit: Int = 60) {
        var wrong = wrongFirst
        for _ in 0..<limit {
            if app.buttons["done"].exists { return }
            guard let n = question else { continue }
            if wrong {
                app.buttons["key-1"].tap(); app.buttons["key-erase"].tap()
                type(n * n + 1)
                wrong = false
                Thread.sleep(forTimeInterval: 1.4)
            } else {
                type(n * n)
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        XCTAssertTrue(app.buttons["done"].waitForExistence(timeout: 5))
    }

    func tab(_ i: Int) { app.tabBars.buttons.element(boundBy: i).tap() }

    // MARK: flows

    func testDailyDrillCapturesSquares() {
        launch()
        app.buttons["daily"].tap()
        answerUntilDone(wrongFirst: true)
        XCTAssertTrue(app.staticTexts["Field grows"].exists || app.staticTexts["Nice work"].exists)
        app.buttons["done"].tap()
        XCTAssertTrue(app.buttons["daily"].waitForExistence(timeout: 3))
    }

    func testRaceAgainstTurtleIsWonAndShared() {
        launch("-fresh")
        app.buttons["tile-race"].tap()
        XCTAssertFalse(app.buttons["rival-ghost"].isEnabled, "no ghost before the first race")
        XCTAssertFalse(app.buttons["rival-calculator"].isEnabled)
        app.buttons["rival-rookie"].tap()
        XCTAssertTrue(app.buttons["key-1"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2.6) // countdown
        answerUntilDone(wrongFirst: true, limit: 40)
        XCTAssertTrue(app.staticTexts["New record!"].exists)
        XCTAssertTrue(app.staticTexts["Achievement unlocked"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["share"].exists)
        app.buttons["again"].tap()
        XCTAssertTrue(app.buttons["close"].waitForExistence(timeout: 3))
        app.buttons["close"].tap()
        app.buttons["tile-race"].tap()
        XCTAssertTrue(app.buttons["rival-ghost"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["rival-ghost"].isEnabled, "ghost appears after the first win")
    }

    func testGhostWinsIfYouStandStill() {
        launch()
        app.buttons["tile-race"].tap()
        app.buttons["rival-ghost"].tap()
        XCTAssertTrue(app.staticTexts["So close"].waitForExistence(timeout: 45))
        app.buttons["done"].tap()
    }

    func testCards() {
        launch()
        app.buttons["tile-cards"].tap()
        let card = app.descendants(matching: .any)["card"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.tap()
        card.tap()
        app.buttons["dont-know"].tap()
        card.swipeRight()
        card.swipeLeft()
        for _ in 0..<40 {
            if app.buttons["done"].exists { break }
            if app.buttons["know"].exists { app.buttons["know"].tap() }
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(app.staticTexts["Deck done"].waitForExistence(timeout: 3))
        app.buttons["done"].tap()
    }

    func testReverse() {
        launch()
        app.buttons["tile-reverse"].tap()
        var wrong = true
        for _ in 0..<12 {
            if app.buttons["done"].waitForExistence(timeout: 0.5) { break }
            let sq = app.staticTexts["reverse-square"]
            guard sq.waitForExistence(timeout: 3), let v = Int(sq.label) else { continue }
            let root = Int(Double(v).squareRoot().rounded())
            if wrong {
                let other = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'choice-' AND identifier != 'choice-\(root)'")).firstMatch
                other.tap()
                wrong = false
                Thread.sleep(forTimeInterval: 1.5)
            } else {
                app.buttons["choice-\(root)"].tap()
                Thread.sleep(forTimeInterval: 0.8)
            }
        }
        XCTAssertTrue(app.buttons["again"].exists)
        app.buttons["again"].tap()
        XCTAssertTrue(app.staticTexts["reverse-square"].waitForExistence(timeout: 3))
        app.buttons["close"].tap()
    }

    func testDuelToTen() {
        launch()
        app.buttons["tile-duel"].tap()
        var wrongDone = false
        for _ in 0..<30 {
            if app.buttons["again-0"].exists { break }
            guard let n = question else { continue }
            if !wrongDone, let bad = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'p1-choice-' AND identifier != 'p1-choice-\(n * n)'")).allElementsBoundByIndex.first {
                bad.tap()
                wrongDone = true
            }
            app.buttons["p0-choice-\(n * n)"].tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        XCTAssertTrue(app.staticTexts["You win!"].waitForExistence(timeout: 3))
        app.buttons["again-1"].tap()
        XCTAssertTrue(app.buttons["close"].waitForExistence(timeout: 3))
        app.buttons["close"].tap()
        app.buttons["tile-duel"].tap()
        for _ in 0..<30 {
            if app.buttons["exit-0"].exists { break }
            guard let n = question else { continue }
            app.buttons["p1-choice-\(n * n)"].tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        app.buttons["exit-0"].tap()
    }

    func testEveryLesson() {
        launch()
        tab(1)
        for id in 0..<4 {
            app.buttons["lesson-\(id)"].tap()
            for _ in 0..<4 { app.buttons["lesson-next"].tap() }
            if id == 0 {
                app.buttons["hint"].tap()
                app.buttons["hint"].tap()
                answerUntilDone(wrongFirst: true, limit: 10)
                XCTAssertTrue(app.staticTexts["Trick learned"].exists)
                app.buttons["done"].tap()
            } else {
                XCTAssertTrue(app.buttons["key-1"].waitForExistence(timeout: 3))
                app.buttons["close"].tap()
            }
        }
    }

    func testTrickOfTheDayAndVisualSquareAndTable() {
        launch()
        app.swipeUp()
        app.buttons["trick"].tap()
        XCTAssertTrue(app.buttons["lesson-next"].waitForExistence(timeout: 3))
        app.buttons["close"].tap()

        tab(1)
        app.swipeUp()
        app.buttons["tile-visual"].tap()
        let slider = app.sliders["slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 3))
        slider.adjust(toNormalizedSliderPosition: 1)
        slider.adjust(toNormalizedSliderPosition: 0)
        slider.adjust(toNormalizedSliderPosition: 0.3)
        app.buttons["close"].tap()

        app.buttons["tile-table"].tap()
        XCTAssertTrue(app.staticTexts["9801"].waitForExistence(timeout: 3))
        app.swipeDown(velocity: .fast)
    }

    func testFieldCellsAndDefend() {
        launch()
        tab(2)
        app.buttons["cell-10"].tap()
        XCTAssertTrue(app.buttons["practice"].waitForExistence(timeout: 3))
        app.swipeDown(velocity: .fast)
        app.buttons["cell-42"].tap()
        XCTAssertTrue(app.buttons["practice"].waitForExistence(timeout: 3))
        app.swipeDown(velocity: .fast)
        app.buttons["cell-39"].tap()
        app.buttons["practice"].tap()
        answerUntilDone()
        app.buttons["done"].tap()
        app.swipeUp()
        if app.buttons["defend"].waitForExistence(timeout: 2) {
            app.buttons["defend"].tap()
            XCTAssertTrue(app.buttons["close"].waitForExistence(timeout: 3))
            app.buttons["close"].tap()
        }
    }

    func testTrophiesSettingsHistoryAndReset() {
        launch()
        tab(3)
        app.swipeUp()
        app.buttons["history"].tap()
        XCTAssertTrue(app.images["old-home"].waitForExistence(timeout: 3) || app.staticTexts["Story of the app"].exists)
        app.swipeDown(velocity: .fast)
        app.swipeUp()
        for id in ["toggle-sound", "toggle-haptics"] {
            let sw = app.switches[id]
            XCTAssertTrue(sw.waitForExistence(timeout: 3))
            sw.switches.firstMatch.exists ? sw.switches.firstMatch.tap() : sw.tap()
            sw.switches.firstMatch.exists ? sw.switches.firstMatch.tap() : sw.tap()
        }
        app.buttons["reset"].tap()
        app.buttons["Reset"].firstMatch.tap()
        tab(0)
        XCTAssertTrue(app.staticTexts["Defend the field"].waitForExistence(timeout: 3))
    }

    func testAvatarPicker() {
        launch()
        app.buttons["avatar-button"].tap()
        XCTAssertTrue(app.buttons["avatar-3"].waitForExistence(timeout: 3))
        app.buttons["avatar-3"].tap()
        XCTAssertTrue(app.buttons["tile-race"].waitForExistence(timeout: 3))
    }

    func testFieldDefendedState() {
        launch("-done")
        XCTAssertTrue(app.staticTexts["Field defended"].waitForExistence(timeout: 3))
        app.buttons["daily"].tap()
        answerUntilDone(limit: 20)
        app.buttons["done"].tap()
    }
}

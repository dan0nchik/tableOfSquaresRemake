import XCTest

/// Walks the main screens in every language, checks nothing sticks out of the screen and saves screenshots.
/// Set TEST_RUNNER_SHOTS=/some/dir to also write the PNGs to disk for review.
final class LayoutTests: XCTestCase {
    var app: XCUIApplication!

    static let languages = ["en", "ru", "uk", "be", "kk", "uz", "az", "hy", "ka", "bg", "de", "fr", "es", "it", "pt-BR", "pt-PT",
                            "ca", "nl", "sv", "da", "nb", "fi", "pl", "cs", "sk", "hu", "ro", "hr", "sr", "sl", "lt", "lv", "et",
                            "el", "tr", "he", "ar", "fa", "hi", "bn", "ur", "ta", "te", "mr", "th", "vi", "ja", "ko", "zh-Hans",
                            "zh-Hant", "id", "ms", "fil", "sw"]

    override func setUp() { continueAfterFailure = true }

    private func launch(_ lang: String, _ profile: String = "-demo") {
        app = XCUIApplication()
        app.launchArguments = [profile, "-AppleLanguages", "(\(lang))", "-AppleLocale", lang]
        app.launch()
    }

    private func shot(_ lang: String, _ name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = "\(lang)-\(name)"
        a.lifetime = .keepAlways
        add(a)
        if let dir = ProcessInfo.processInfo.environment["SHOTS"] {
            let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device"
            let folder = URL(fileURLWithPath: dir).appendingPathComponent(device.replacingOccurrences(of: " ", with: "_"))
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? s.pngRepresentation.write(to: folder.appendingPathComponent("\(lang)-\(name).png"))
        }
        assertInside(lang, name)
    }

    /// Every visible label and button lies within the screen horizontally.
    private func assertInside(_ lang: String, _ name: String) {
        let win = app.windows.firstMatch.frame
        let elements = app.staticTexts.allElementsBoundByIndex + app.buttons.allElementsBoundByIndex
        for el in elements {
            let f = el.frame
            guard !f.isEmpty, f.maxY > win.minY + 1, f.minY < win.maxY - 1 else { continue }
            XCTAssert(f.minX >= win.minX - 1 && f.maxX <= win.maxX + 1,
                      "\(lang) \(name): '\(el.label)' sticks out of the screen \(f)")
        }
    }

    private func tab(_ i: Int) { app.tabBars.buttons.element(boundBy: i).tap() }

    private func close() {
        if app.buttons["close"].exists { app.buttons["close"].tap() } else { app.swipeDown(velocity: .fast) }
    }

    /// The text-heavy screens, for one language.
    private func walk(_ lang: String, full: Bool) {
        launch(lang)
        shot(lang, "01-home")
        app.swipeUp()
        shot(lang, "02-home-bottom")
        app.swipeDown()
        app.buttons["tile-race"].tap()
        XCTAssertTrue(app.buttons["rival-rookie"].waitForExistence(timeout: 3))
        shot(lang, "03-rivals")
        app.swipeDown(velocity: .fast)
        tab(1)
        shot(lang, "04-learn")
        app.buttons["lesson-1"].tap()
        app.buttons["lesson-next"].tap()
        shot(lang, "05-lesson")
        close()
        tab(2)
        shot(lang, "06-field")
        app.buttons["cell-39"].tap()
        shot(lang, "07-cell")
        app.swipeDown(velocity: .fast)
        tab(3)
        shot(lang, "08-trophies")
        app.swipeUp(); app.swipeUp()
        shot(lang, "09-settings")
        guard full else { return }
        app.buttons["history"].tap()
        shot(lang, "10-history")
        app.swipeDown(velocity: .fast)
        tab(1)
        app.swipeUp()
        app.buttons["tile-visual"].tap()
        shot(lang, "11-visual")
        close()
        app.buttons["tile-table"].tap()
        shot(lang, "12-table")
        app.swipeDown(velocity: .fast)
        tab(0)
        app.buttons["daily"].tap()
        shot(lang, "13-drill")
        close()
        app.buttons["tile-cards"].tap()
        shot(lang, "14-card")
        app.descendants(matching: .any)["card"].tap()
        shot(lang, "15-card-back")
        close()
        app.buttons["tile-reverse"].tap()
        shot(lang, "16-reverse")
        close()
        app.buttons["tile-duel"].tap()
        shot(lang, "17-duel")
        close()
        app.buttons["tile-race"].tap()
        app.buttons["rival-rookie"].tap()
        Thread.sleep(forTimeInterval: 3)
        shot(lang, "18-race")
        close()
        launch(lang, "-done")
        shot(lang, "19-defended")
        app.buttons["daily"].tap()
        for _ in 0..<12 {
            let q = app.descendants(matching: .any).matching(identifier: "question").firstMatch
            guard q.waitForExistence(timeout: 3), let v = q.value as? String, let n = Int(v) else { break }
            for ch in String(n * n) { app.buttons["key-\(ch)"].tap() }
            Thread.sleep(forTimeInterval: 0.5)
            if app.buttons["done"].exists { break }
        }
        if app.buttons["done"].waitForExistence(timeout: 3) { shot(lang, "20-result") }
    }

    func testFullWalkInKeyLanguages() {
        for lang in ["en", "ru", "de", "ar"] { walk(lang, full: true) }
    }

    func testMainScreensInEveryLanguage() {
        for lang in LayoutTests.languages where !["en", "ru", "de", "ar"].contains(lang) { walk(lang, full: false) }
    }
}

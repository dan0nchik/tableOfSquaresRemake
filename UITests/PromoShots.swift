import XCTest

/// App Store screenshots. Skipped unless PROMO_LANGS is set (TEST_RUNNER_PROMO_LANGS=en,ru and TEST_RUNNER_SHOTS=/dir).
final class PromoShots: XCTestCase {
    var app: XCUIApplication!

    private func save(_ dir: String, _ lang: String, _ i: Int) {
        Thread.sleep(forTimeInterval: 0.8)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let folder = URL(fileURLWithPath: dir).appendingPathComponent(lang)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? png.write(to: folder.appendingPathComponent("\(i).png"))
    }

    private var question: Int? {
        let q = app.descendants(matching: .any).matching(identifier: "question").firstMatch
        guard q.waitForExistence(timeout: 5), let v = q.value as? String else { return nil }
        return Int(v)
    }

    func testPromo() throws {
        let env = ProcessInfo.processInfo.environment
        guard let langs = env["PROMO_LANGS"], let dir = env["SHOTS"] else { throw XCTSkip("no PROMO_LANGS") }
        for lang in langs.split(separator: ",").map(String.init) {
            app = XCUIApplication()
            app.launchArguments = ["-demo", "-AppleLanguages", "(\(lang))", "-AppleLocale", lang]
            app.launch()
            save(dir, lang, 1)

            app.tabBars.buttons.element(boundBy: 2).tap()
            save(dir, lang, 2)

            app.tabBars.buttons.element(boundBy: 0).tap()
            app.buttons["tile-race"].tap()
            app.buttons["rival-ghost"].tap()
            Thread.sleep(forTimeInterval: 2.6)
            for _ in 0..<5 {
                guard let n = question else { break }
                for ch in String(n * n) { app.buttons["key-\(ch)"].tap() }
                Thread.sleep(forTimeInterval: 0.35)
            }
            if let n = question { for ch in String(n * n).prefix(2) { app.buttons["key-\(ch)"].tap() } }
            save(dir, lang, 3)
            app.buttons["close"].tap()

            app.tabBars.buttons.element(boundBy: 1).tap()
            app.buttons["lesson-0"].tap()
            app.buttons["lesson-next"].tap()
            app.buttons["lesson-next"].tap()
            save(dir, lang, 4)
            app.buttons["close"].tap()

            app.tabBars.buttons.element(boundBy: 0).tap()
            app.buttons["tile-duel"].tap()
            for k in 0..<5 {
                guard let n = question else { break }
                app.buttons["\(k % 2 == 0 ? "p0" : "p1")-choice-\(n * n)"].tap()
                Thread.sleep(forTimeInterval: 0.9)
            }
            save(dir, lang, 5)
            app.terminate()
        }
    }
}

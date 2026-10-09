import XCTest
@testable import TableOfSquares

/// Every shipped language is complete and free of emoji.
final class LocalizationTests: XCTestCase {
    private var bundle: Bundle { Bundle(for: Store.self) }

    private func table(_ lang: String) -> [String: String] {
        guard let path = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else { return [:] }
        return dict
    }

    private var languages: [String] { bundle.localizations.filter { $0 != "Base" && $0 != "en" } }

    func testManyLanguagesShip() {
        XCTAssertGreaterThanOrEqual(languages.count, 50, "\(languages)")
        XCTAssertTrue(languages.contains("ru"))
    }

    func testEveryLanguageHasEveryKey() {
        let reference = Set(table("ru").keys)
        XCTAssertGreaterThan(reference.count, 150)
        for l in languages {
            XCTAssertEqual(Set(table(l).keys), reference, l)
        }
    }

    func testNoEmojiOrMiddleDotAnywhere() {
        for l in languages + ["ru"] {
            for (k, v) in table(l) {
                for text in [k, v] {
                    XCTAssertFalse(text.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.value == 0xFE0F },
                                   "\(l): \(text)")
                    XCTAssertFalse(text.contains("\u{00B7}"), "\(l): \(text)")
                }
            }
        }
    }

    func testPlaceholdersSurviveTranslation() {
        let ph = try! NSRegularExpression(pattern: "%(\\d+\\$)?(lld|@|d)")
        func count(_ s: String) -> Int { ph.numberOfMatches(in: s, range: NSRange(s.startIndex..., in: s)) }
        for l in languages {
            for (k, v) in table(l) { XCTAssertEqual(count(k), count(v), "\(l): \(k) -> \(v)") }
        }
    }
}

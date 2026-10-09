import UIKit
import XCTest
@testable import TableOfSquares

/// Scans the project sources on disk: no emoji and no middle dots anywhere, in code or in any language.
final class SourceHygieneTests: XCTestCase {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent() }

    private func files() -> [URL] {
        let dirs = ["App", "Widget", "Shared", "Tests", "UITests"].map { root.appendingPathComponent($0) }
        var out: [URL] = []
        for d in dirs {
            let e = FileManager.default.enumerator(at: d, includingPropertiesForKeys: nil)
            while let f = e?.nextObject() as? URL {
                if ["swift", "xcstrings", "strings", "plist"].contains(f.pathExtension) { out.append(f) }
            }
        }
        return out
    }

    func testNoEmojiInSourcesOrTranslations() throws {
        let found = files()
        XCTAssertGreaterThan(found.count, 15)
        for f in found where f.lastPathComponent != "SourceHygieneTests.swift" {
            let text = try String(contentsOf: f, encoding: .utf8)
            for (i, line) in text.components(separatedBy: "\n").enumerated() {
                let bad = line.unicodeScalars.filter { $0.properties.isEmojiPresentation || $0.value == 0xFE0F || $0.value == 0x00B7 }
                XCTAssertTrue(bad.isEmpty, "\(f.lastPathComponent):\(i + 1): \(String(String.UnicodeScalarView(bad)))")
            }
        }
    }

    /// A typo in a symbol name shows an empty square, so every name used must exist.
    func testEverySymbolExists() throws {
        let re = try NSRegularExpression(pattern: #"systemName: "([^"]+)""#)
        var names = Set(Achievement.allCases.map(\.symbol))
        for f in files() where f.pathExtension == "swift" && f.lastPathComponent != "SourceHygieneTests.swift" {
            let text = try String(contentsOf: f, encoding: .utf8)
            for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                names.insert(String(text[Range(m.range(at: 1), in: text)!]))
            }
        }
        XCTAssertGreaterThan(names.count, 20)
        for n in names { XCTAssertNotNil(UIImage(systemName: n), "missing SF Symbol: \(n)") }
    }
}

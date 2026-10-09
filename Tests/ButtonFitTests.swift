import UIKit
import XCTest
@testable import TableOfSquares

/// Measures every button and tile caption in every language against the space it gets
/// on the narrowest iPhone (375 pt). A caption may shrink a little, never wrap or get cut.
final class ButtonFitTests: XCTestCase {
    private var bundle: Bundle { Bundle(for: Store.self) }

    struct Slot {
        var keys: [String]; var size: CGFloat; var weight: UIFont.Weight; var width: CGFloat; var minScale: CGFloat; var lines = 1
    }

    /// Widths come from the layout: 375 screen, 20 side padding, the button's own padding.
    private let slots: [Slot] = [
        // full-width chunky buttons: 335 minus 2 × 12 padding
        Slot(keys: ["Again", "Done", "Practice", "Next", "Defend the field"], size: 18, weight: .bold, width: 311, minScale: 0.85),
        // two chunky buttons side by side (cards): (335 − 12) / 2 − 24
        Slot(keys: ["Know", "Don't know"], size: 18, weight: .bold, width: 137, minScale: 0.75),
        // duel result buttons: ((375 − 48) − 10) / 2 − 24
        Slot(keys: ["Again", "Exit"], size: 18, weight: .bold, width: 134, minScale: 0.75),
        // home tiles: (335 − 14) / 2 − 32, two lines allowed
        Slot(keys: ["Race", "Duel", "Cards", "Reverse", "Why a square?", "Full table"], size: 20, weight: .bold, width: 128, minScale: 0.7, lines: 2),
        // home title lines
        Slot(keys: ["Table of"], size: 40, weight: .regular, width: 335, minScale: 1),
        Slot(keys: ["squares"], size: 40, weight: .heavy, width: 335, minScale: 1),
        // big underlined screen titles
        Slot(keys: ["Learn", "Field", "Trophies", "Choose a rival", "Choose avatar", "Story of the app", "Table of squares"],
             size: 30, weight: .heavy, width: 335, minScale: 0.7),
        // game header titles next to the close button
        Slot(keys: ["Defend the field", "Race", "Cards", "Reverse", "Ending in 5", "Close to 50", "Close to 100", "Next door", "Why a square?"],
             size: 20, weight: .bold, width: 250, minScale: 0.75),
        // pills on the banner
        Slot(keys: ["Fading: %lld", "New: %lld", "Keep capturing"], size: 14, weight: .bold, width: 206, minScale: 0.75),
        // field legend, two by two: (335 − 16) / 2 − 19
        Slot(keys: ["Free", "Capturing", "Yours", "Fading"], size: 13, weight: .semibold, width: 140, minScale: 0.7),
        // result stat captions, up to two side by side
        Slot(keys: ["Right", "Captured", "Time", "Mistakes", "Known", "Repeated"], size: 13, weight: .semibold, width: 150, minScale: 1),
        // duel player names next to the avatar and score
        Slot(keys: ["Player 1", "Player 2"], size: 17, weight: .bold, width: 220, minScale: 0.7),
        Slot(keys: ["You win!", "Next time!"], size: 30, weight: .heavy, width: 290, minScale: 0.7),
        // share pill
        Slot(keys: ["Share"], size: 17, weight: .bold, width: 200, minScale: 0.8),
    ]

    private func strings(_ lang: String) -> [String: String] {
        guard let p = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang),
              let d = NSDictionary(contentsOfFile: p) as? [String: String] else { return [:] }
        return d
    }

    func testButtonCaptionsFitInEveryLanguage() {
        let langs = bundle.localizations.filter { $0 != "Base" }
        XCTAssertGreaterThan(langs.count, 1)
        var problems: [String] = []
        for lang in langs {
            let table = strings(lang)
            for slot in slots {
                let font = UIFont.systemFont(ofSize: slot.size, weight: slot.weight)
                for key in slot.keys {
                    let text = (table[key] ?? key).replacingOccurrences(of: "%lld", with: "88")
                    let w = (text as NSString).size(withAttributes: [.font: font]).width
                    // with several lines, the longest word must still fit on one line
                    let word = text.split(separator: " ").map { (String($0) as NSString).size(withAttributes: [.font: font]).width }.max() ?? w
                    let fits = slot.lines == 1 ? w * slot.minScale <= slot.width
                        : word * slot.minScale <= slot.width && w * slot.minScale <= slot.width * CGFloat(slot.lines) * 0.9
                    if !fits {
                        problems.append("\(lang): '\(text)' needs \(Int(w)) pt, has \(Int(slot.width)) (min scale \(slot.minScale))")
                    }
                }
            }
        }
        XCTAssertTrue(problems.isEmpty, "\n" + problems.joined(separator: "\n"))
    }
}

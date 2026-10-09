import SwiftUI

/// A mental math trick, shown step by step on a sample number and then practiced.
struct Lesson: Identifiable {
    struct Step { var expr: String; var text: LocalizedStringKey }

    let id: Int
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let badge: String
    let color: Color
    let numbers: [Int]
    let steps: (Int) -> [Step]

    static let all: [Lesson] = [
        Lesson(id: 0, title: "Ending in 5", subtitle: "35² in two seconds", badge: "5", color: P.coral,
               numbers: Array(stride(from: 15, through: 95, by: 10))) { n in
            let a = n / 10
            return [
                Step(expr: "\(n)²", text: "Take a number that ends in 5"),
                Step(expr: "\(a) × \(a + 1) = \(a * (a + 1))", text: "Multiply its tens digit by the next number"),
                Step(expr: "\(a * (a + 1)) | 25", text: "Write 25 on the right"),
                Step(expr: "\(n)² = \(sq(n))", text: "Done. Works for every number ending in 5"),
            ]
        },
        Lesson(id: 1, title: "Close to 50", subtitle: "From 41 to 59", badge: "50", color: P.lavender,
               numbers: Array(41...49) + Array(51...59)) { n in
            let k = n - 50
            let sign = k < 0 ? "−" : "+"
            return [
                Step(expr: "\(n) = 50 \(sign) \(abs(k))", text: "Find how far the number is from 50"),
                Step(expr: "25 \(sign) \(abs(k)) = \(25 + k)", text: "Add that difference to 25. These are the hundreds"),
                Step(expr: "\(abs(k))² = \(String(format: "%02d", k * k))", text: "Square the difference. These are the last two digits"),
                Step(expr: "\(n)² = \(sq(n))", text: "Put them together"),
            ]
        },
        Lesson(id: 2, title: "Close to 100", subtitle: "From 91 to 99", badge: "100", color: P.green,
               numbers: Array(91...99)) { n in
            let k = 100 - n
            return [
                Step(expr: "\(n) = 100 − \(k)", text: "Find how far the number is from 100"),
                Step(expr: "\(n) − \(k) = \(n - k)", text: "Subtract that difference from the number. These are the first digits"),
                Step(expr: "\(k)² = \(String(format: "%02d", k * k))", text: "Square the difference. These are the last two digits"),
                Step(expr: "\(n)² = \(sq(n))", text: "Put them together"),
            ]
        },
        Lesson(id: 3, title: "Next door", subtitle: "Numbers ending in 1", badge: "+1", color: P.navy,
               numbers: Array(stride(from: 21, through: 91, by: 10))) { n in
            let m = n - 1
            return [
                Step(expr: "\(m)² = \(sq(m))", text: "You already know the square of the round number next door"),
                Step(expr: "\(m) + \(n) = \(m + n)", text: "Add the two neighbours together"),
                Step(expr: "\(sq(m)) + \(m + n)", text: "Add that to the round square"),
                Step(expr: "\(n)² = \(sq(n))", text: "Every next square is the previous one plus both numbers"),
            ]
        },
    ]

    /// The sample used in the walkthrough.
    var sample: Int { numbers[numbers.count / 2] }

    /// A lesson and sample number that change every day, for the home screen.
    static func ofTheDay(_ day: Int) -> (Lesson, Int) {
        let l = all[((day % all.count) + all.count) % all.count]
        return (l, l.numbers[((day / all.count) % l.numbers.count + l.numbers.count) % l.numbers.count])
    }
}

/// Rounded square with the lesson's number, centered.
struct LessonBadge: View {
    var lesson: Lesson
    var size: CGFloat
    var body: some View {
        Text(verbatim: lesson.badge)
            .font(.system(size: size * (lesson.badge.count > 2 ? 0.34 : 0.42), weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(lesson.color, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityHidden(true)
    }
}

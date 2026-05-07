import Foundation

struct CalculatorResult: Identifiable, Hashable {
    let expression: String
    let answer: Double
    let answerString: String

    var id: String {
        "\(expression)=\(answerString)"
    }

    init?(query: String) {
        let expression = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let answer = CalculatorExpressionEvaluator.evaluate(expression) else {
            return nil
        }

        self.expression = expression
        self.answer = answer
        answerString = Self.format(answer)
    }

    private static func format(_ value: Double) -> String {
        if value == 0 {
            return "0"
        }

        if value.rounded() == value,
           value <= Double(Int64.max),
           value >= Double(Int64.min) {
            return String(Int64(value))
        }

        let formatted = String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), value)

        guard formatted.contains(".") else {
            return formatted
        }

        return formatted
            .replacingOccurrences(
                of: #"(\.\d*?)0+($|e)"#,
                with: "$1$2",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\.($|e)"#,
                with: "$1",
                options: .regularExpression
            )
    }
}

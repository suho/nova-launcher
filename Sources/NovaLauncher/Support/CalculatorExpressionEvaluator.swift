import Foundation

enum CalculatorExpressionEvaluator {
    static func evaluate(_ expression: String) -> Double? {
        let normalizedExpression = expression
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")

        guard hasCalculationSignal(normalizedExpression),
              normalizedExpression.allSatisfy(isAllowedCharacter) else {
            return nil
        }

        var parser = Parser(expression: normalizedExpression)

        guard let value = parser.parse(), value.isFinite else {
            return nil
        }

        return value
    }

    private static func hasCalculationSignal(_ expression: String) -> Bool {
        var previousSignificantCharacter: Character?

        for character in expression {
            guard !character.isWhitespace else {
                continue
            }

            if "+*/%^".contains(character) {
                return true
            }

            if character == "-",
               let previousSignificantCharacter,
               !"(-+*/%^".contains(previousSignificantCharacter) {
                return true
            }

            previousSignificantCharacter = character
        }

        return false
    }

    private static func isAllowedCharacter(_ character: Character) -> Bool {
        character.isNumber || character.isWhitespace || ".+-*/%^()".contains(character)
    }
}

private struct Parser {
    private let characters: [Character]
    private var index = 0

    init(expression: String) {
        characters = Array(expression)
    }

    mutating func parse() -> Double? {
        guard let value = parseExpression() else {
            return nil
        }

        skipSpaces()
        return isAtEnd ? value : nil
    }

    private mutating func parseExpression() -> Double? {
        guard var value = parseTerm() else {
            return nil
        }

        while true {
            skipSpaces()

            if consume("+") {
                guard let rhs = parseTerm() else {
                    return nil
                }

                value += rhs
            } else if consume("-") {
                guard let rhs = parseTerm() else {
                    return nil
                }

                value -= rhs
            } else {
                return value
            }
        }
    }

    private mutating func parseTerm() -> Double? {
        guard var value = parseUnary() else {
            return nil
        }

        while true {
            skipSpaces()

            if consume("*") {
                guard let rhs = parseUnary() else {
                    return nil
                }

                value *= rhs
            } else if consume("/") {
                guard let rhs = parseUnary(), rhs != 0 else {
                    return nil
                }

                value /= rhs
            } else if consume("%") {
                guard let rhs = parseUnary(), rhs != 0 else {
                    return nil
                }

                value.formTruncatingRemainder(dividingBy: rhs)
            } else {
                return value
            }
        }
    }

    private mutating func parsePower() -> Double? {
        guard let base = parsePrimary() else {
            return nil
        }

        skipSpaces()

        guard consume("^") else {
            return base
        }

        guard let exponent = parseUnary() else {
            return nil
        }

        return pow(base, exponent)
    }

    private mutating func parseUnary() -> Double? {
        skipSpaces()

        if consume("+") {
            return parseUnary()
        }

        if consume("-") {
            guard let value = parseUnary() else {
                return nil
            }

            return -value
        }

        return parsePower()
    }

    private mutating func parsePrimary() -> Double? {
        skipSpaces()

        if consume("(") {
            guard let value = parseExpression() else {
                return nil
            }

            skipSpaces()

            guard consume(")") else {
                return nil
            }

            return value
        }

        return parseNumber()
    }

    private mutating func parseNumber() -> Double? {
        skipSpaces()
        let startIndex = index
        var hasDigit = false
        var hasDecimalPoint = false

        while !isAtEnd {
            let character = characters[index]

            if character.isNumber {
                hasDigit = true
                index += 1
            } else if character == ".", !hasDecimalPoint {
                hasDecimalPoint = true
                index += 1
            } else {
                break
            }
        }

        guard hasDigit else {
            index = startIndex
            return nil
        }

        return Double(String(characters[startIndex..<index]))
    }

    private mutating func skipSpaces() {
        while !isAtEnd, characters[index].isWhitespace {
            index += 1
        }
    }

    private mutating func consume(_ expected: Character) -> Bool {
        skipSpaces()

        guard !isAtEnd, characters[index] == expected else {
            return false
        }

        index += 1
        return true
    }

    private var isAtEnd: Bool {
        index >= characters.count
    }
}

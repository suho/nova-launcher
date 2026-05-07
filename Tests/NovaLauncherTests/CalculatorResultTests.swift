import Testing
@testable import NovaLauncher

struct CalculatorResultTests {
    @Test func evaluatesBasicArithmeticWithPrecedence() throws {
        let result = try #require(CalculatorResult(query: "2 + 3 * 4"))

        #expect(result.expression == "2 + 3 * 4")
        #expect(result.answerString == "14")
    }

    @Test func evaluatesParenthesesAndUnarySigns() throws {
        let result = try #require(CalculatorResult(query: "-(2 + 3) * 4"))

        #expect(result.answerString == "-20")
    }

    @Test func formatsFractionalResultsWithoutFloatingPointNoise() throws {
        let result = try #require(CalculatorResult(query: "0.1 + 0.2"))

        #expect(result.answerString == "0.3")
    }

    @Test func supportsExponentAndRemainderOperators() throws {
        let exponent = try #require(CalculatorResult(query: "2^3"))
        let negativeExponentBase = try #require(CalculatorResult(query: "-2^2"))
        let groupedNegativeExponentBase = try #require(CalculatorResult(query: "(-2)^2"))
        let remainder = try #require(CalculatorResult(query: "7 % 4"))

        #expect(exponent.answerString == "8")
        #expect(negativeExponentBase.answerString == "-4")
        #expect(groupedNegativeExponentBase.answerString == "4")
        #expect(remainder.answerString == "3")
    }

    @Test func rejectsNonExpressionsAndInvalidMath() {
        #expect(CalculatorResult(query: "42") == nil)
        #expect(CalculatorResult(query: "Safari") == nil)
        #expect(CalculatorResult(query: "2 / 0") == nil)
        #expect(CalculatorResult(query: "2 +") == nil)
    }
}

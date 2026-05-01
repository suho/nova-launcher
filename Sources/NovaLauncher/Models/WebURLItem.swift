import Foundation

struct WebURLItem: Identifiable, Hashable {
    let input: String
    let url: URL
    let displayString: String

    var id: String {
        url.absoluteString
    }

    init?(query: String) {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !input.isEmpty,
              input.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return nil
        }

        let urlString = Self.normalizedURLString(from: input)

        guard let components = URLComponents(string: urlString),
              let scheme = components.scheme?.lowercased(),
              Self.webSchemes.contains(scheme),
              let host = components.host,
              Self.isValidHost(host),
              let url = components.url else {
            return nil
        }

        self.input = input
        self.url = url
        self.displayString = urlString
    }

    private static let webSchemes: Set<String> = ["http", "https"]

    private static func normalizedURLString(from input: String) -> String {
        if input.contains("://") {
            return input
        }

        return "https://\(input)"
    }

    private static func isValidHost(_ host: String) -> Bool {
        let normalizedHost = host.lowercased()

        if normalizedHost == "localhost" || isIPv4Address(normalizedHost) {
            return true
        }

        return isValidDomain(normalizedHost)
    }

    private static func isIPv4Address(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count == 4 else {
            return false
        }

        return parts.allSatisfy { part in
            guard let value = Int(part), value >= 0, value <= 255 else {
                return false
            }

            return String(value) == part || part == "0"
        }
    }

    private static func isValidDomain(_ host: String) -> Bool {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)

        guard labels.count >= 2 else {
            return false
        }

        return labels.allSatisfy(isValidDomainLabel)
    }

    private static func isValidDomainLabel(_ label: Substring) -> Bool {
        guard !label.isEmpty,
              label.count <= 63,
              label.first.map(isLetterOrNumber) == true,
              label.last.map(isLetterOrNumber) == true else {
            return false
        }

        return label.allSatisfy { character in
            character.isLetter || character.isNumber || character == "-"
        }
    }

    private static func isLetterOrNumber(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}

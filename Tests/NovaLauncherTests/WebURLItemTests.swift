import Testing
@testable import NovaLauncher

struct WebURLItemTests {
    @Test func addsHTTPSForDomainWithoutScheme() throws {
        let item = try #require(WebURLItem(query: "example.com/path?query=1"))

        #expect(item.url.absoluteString == "https://example.com/path?query=1")
        #expect(item.displayString == "https://example.com/path?query=1")
    }

    @Test func preservesExplicitHTTPSURL() throws {
        let item = try #require(WebURLItem(query: "https://example.com"))

        #expect(item.url.absoluteString == "https://example.com")
        #expect(item.displayString == "https://example.com")
    }

    @Test func preservesExplicitHTTPURL() throws {
        let item = try #require(WebURLItem(query: "http://example.com"))

        #expect(item.url.absoluteString == "http://example.com")
        #expect(item.displayString == "http://example.com")
    }

    @Test func rejectsPlainSearchText() {
        #expect(WebURLItem(query: "calendar") == nil)
        #expect(WebURLItem(query: "open settings") == nil)
    }

    @Test func rejectsNonWebSchemes() {
        #expect(WebURLItem(query: "file:///Applications/Safari.app") == nil)
        #expect(WebURLItem(query: "ftp://example.com") == nil)
    }

    @Test func acceptsLocalDevelopmentURLs() throws {
        let localhost = try #require(WebURLItem(query: "localhost:3000"))
        let loopback = try #require(WebURLItem(query: "127.0.0.1:8080"))

        #expect(localhost.url.absoluteString == "https://localhost:3000")
        #expect(loopback.url.absoluteString == "https://127.0.0.1:8080")
    }
}

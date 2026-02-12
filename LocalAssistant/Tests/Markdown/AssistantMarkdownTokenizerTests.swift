#if canImport(XCTest)
import XCTest

final class AssistantMarkdownTokenizerTests: XCTestCase {
    func testProseOnlyReturnsSingleMarkdownSegment() {
        let input = "Hello markdown.\nStill markdown."

        let segments = AssistantMarkdownTokenizer.tokenize(input)

        XCTAssertEqual(segments, [.markdown(input)])
    }

    func testSingleFencedCodeBlockWithLanguage() {
        let input = "Intro\n```swift\nprint(\"hi\")\n```\nTail"

        let segments = AssistantMarkdownTokenizer.tokenize(input)

        XCTAssertEqual(
            segments,
            [
                .markdown("Intro\n"),
                .code(language: "swift", code: "print(\"hi\")\n", isClosed: true),
                .markdown("Tail"),
            ]
        )
    }

    func testBackticksMidLineInProseDoNotOpenFence() {
        let input = "Use ```inline``` markers in prose.\nNext line."

        let segments = AssistantMarkdownTokenizer.tokenize(input)

        XCTAssertEqual(segments, [.markdown(input)])
    }

    func testBackticksMidLineInCodeDoNotCloseFence() {
        let input = "```txt\ninside ``` mid-line\nstill code\n```\n"

        let segments = AssistantMarkdownTokenizer.tokenize(input)

        XCTAssertEqual(
            segments,
            [
                .code(language: "txt", code: "inside ``` mid-line\nstill code\n", isClosed: true),
            ]
        )
    }

    func testMultipleCodeBlocks() {
        let input = "A\n```js\n1\n```\nB\n```py\n2\n```\nC"

        let segments = AssistantMarkdownTokenizer.tokenize(input)

        XCTAssertEqual(
            segments,
            [
                .markdown("A\n"),
                .code(language: "js", code: "1\n", isClosed: true),
                .markdown("B\n"),
                .code(language: "py", code: "2\n", isClosed: true),
                .markdown("C"),
            ]
        )
    }

    func testUnclosedFenceMarksCodeAsOpen() {
        let input = "Before\n```swift\nlet x = 1\n"

        let segments = AssistantMarkdownTokenizer.tokenize(input)

        XCTAssertEqual(
            segments,
            [
                .markdown("Before\n"),
                .code(language: "swift", code: "let x = 1\n", isClosed: false),
            ]
        )
    }

    func testLeadingSpacesBeforeFenceAreAllowed() {
        let input = "Lead\n   ```ruby\nputs 'x'\n   ```\nTail\n"

        let segments = AssistantMarkdownTokenizer.tokenize(input)

        XCTAssertEqual(
            segments,
            [
                .markdown("Lead\n"),
                .code(language: "ruby", code: "puts 'x'\n", isClosed: true),
                .markdown("Tail\n"),
            ]
        )
    }

    func testBoldWrappedHeadingLineIsNormalized() {
        let input = "**# AI Assistant Styles**\n\n## Overview\nBody."

        let segments = AssistantMarkdownTokenizer.tokenize(input)

        XCTAssertEqual(
            segments,
            [
                .markdown("# AI Assistant Styles\n\n## Overview\nBody."),
            ]
        )
    }
}
#endif

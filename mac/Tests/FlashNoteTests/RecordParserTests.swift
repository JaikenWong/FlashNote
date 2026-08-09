import XCTest
@testable import FlashNote

final class RecordParserTests: XCTestCase {

    func testParseExpenseWithAmountAndTags() {
        let r = RecordParser.parse("午饭 拉面 28 #餐 #工作日", deviceId: "test")!
        XCTAssertEqual(r.type, .expense)
        XCTAssertEqual(r.amount, 28.0)
        XCTAssertEqual(r.tags, ["餐", "工作日"])
        XCTAssertEqual(r.content, "午饭 拉面")
    }

    func testParseExpenseWithYuanSymbol() {
        let r = RecordParser.parse("晚饭 38.5元", deviceId: "test")!
        XCTAssertEqual(r.type, .expense)
        XCTAssertEqual(r.amount, 38.5)
        XCTAssertEqual(r.content, "晚饭")
    }

    func testParseExpenseWithYenSign() {
        let r = RecordParser.parse("买书 ¥45", deviceId: "test")!
        XCTAssertEqual(r.type, .expense)
        XCTAssertEqual(r.amount, 45.0)
        XCTAssertEqual(r.content, "买书")
    }

    func testParseNote() {
        let r = RecordParser.parse("今天听了场播客 关于 local-first #想法", deviceId: "test")!
        XCTAssertEqual(r.type, .note)
        XCTAssertNil(r.amount)
        XCTAssertEqual(r.tags, ["想法"])
        XCTAssertTrue(r.content.hasPrefix("今天听了场播客"))
    }

    func testParseNoteNoTags() {
        let r = RecordParser.parse("把家里的旧 Kindle 出掉了", deviceId: "test")!
        XCTAssertEqual(r.type, .note)
        XCTAssertTrue(r.tags.isEmpty)
        XCTAssertEqual(r.content, "把家里的旧 Kindle 出掉了")
    }

    func testEmptyInputReturnsNil() {
        XCTAssertNil(RecordParser.parse("", deviceId: "test"))
        XCTAssertNil(RecordParser.parse("   ", deviceId: "test"))
    }

    func testDuplicateTagsDeduplicated() {
        let r = RecordParser.parse("午饭 28 #餐 #餐", deviceId: "test")!
        XCTAssertEqual(r.tags, ["餐"])
    }

    func testContentCollapseWhitespace() {
        let r = RecordParser.parse("午饭   拉面    28 #餐", deviceId: "test")!
        XCTAssertEqual(r.content, "午饭 拉面")
    }
}

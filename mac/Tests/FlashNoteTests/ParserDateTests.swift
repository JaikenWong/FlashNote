import XCTest
@testable import FlashNote

final class ParserDateTests: XCTestCase {

    private let deviceId = "test"

    private func ymd(_ d: Date) -> (Int, Int, Int) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return (c.year!, c.month!, c.day!)
    }

    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        let aDay = cal.startOfDay(for: a)
        let bDay = cal.startOfDay(for: b)
        return cal.dateComponents([.day], from: aDay, to: bDay).day ?? 0
    }

    // MARK: - 关键字：今/昨/前天

    func testToday() {
        let r = RecordParser.parse("早饭 12 #餐", deviceId: deviceId)!
        XCTAssertEqual(ymd(r.createdAt), ymd(Date()))
    }

    func testYesterday() {
        let r = RecordParser.parse("昨天晚饭 65 #餐", deviceId: deviceId)!
        XCTAssertEqual(daysBetween(r.createdAt, Date()), -1)
    }

    func testDayBefore() {
        let r = RecordParser.parse("前天打车 30", deviceId: deviceId)!
        XCTAssertEqual(daysBetween(r.createdAt, Date()), -2)
    }

    func testNDaysAgo() {
        let r = RecordParser.parse("5天前打车 30", deviceId: deviceId)!
        XCTAssertEqual(daysBetween(r.createdAt, Date()), -5)
    }

    // MARK: - 周X

    func testLastWeekday() {
        // 上周三 → 距今 7-? 天前的那一周
        let r = RecordParser.parse("上周三午饭 30", deviceId: deviceId)!
        let wd = Calendar.current.component(.weekday, from: r.createdAt)
        // 周三 = 4 (Sun=1)
        XCTAssertEqual(wd, 4)
        let diff = daysBetween(r.createdAt, Date())
        XCTAssertTrue(diff < 0 && diff >= -7, "上周X 应在 1-7 天前，得到 \(diff)")
    }

    func testBareWeekdayPast() {
        // 单独的"周X"如果是未来则取上周
        let r = RecordParser.parse("周一买书 50", deviceId: deviceId)!
        let wd = Calendar.current.component(.weekday, from: r.createdAt)
        XCTAssertEqual(wd, 2) // 周一
        XCTAssertTrue(r.createdAt <= Date(), "应不晚于今天")
    }

    // MARK: - M月D日 / M-D / M/D

    func testM月D日() {
        // 取去年因为今年可能已过
        let r = RecordParser.parse("3月5日咖啡 28 #餐", deviceId: deviceId)!
        let (_, M, D) = ymd(r.createdAt)
        XCTAssertEqual(M, 3)
        XCTAssertEqual(D, 5)
    }

    func testMDash() {
        let r = RecordParser.parse("3-5咖啡 28", deviceId: deviceId)!
        let (_, M, D) = ymd(r.createdAt)
        XCTAssertEqual(M, 3)
        XCTAssertEqual(D, 5)
    }

    func testMSlash() {
        let r = RecordParser.parse("3/5咖啡 28", deviceId: deviceId)!
        let (_, M, D) = ymd(r.createdAt)
        XCTAssertEqual(M, 3)
        XCTAssertEqual(D, 5)
    }

    // MARK: - YYYY-MM-DD

    func testYYYYMMDD() {
        let r = RecordParser.parse("2025-12-1午饭 30", deviceId: deviceId)!
        let (Y, M, D) = ymd(r.createdAt)
        XCTAssertEqual(Y, 2025)
        XCTAssertEqual(M, 12)
        XCTAssertEqual(D, 1)
    }

    func testYYYYMMDDNotGreedy() {
        // 关键：2026-08-01 中的 2026 不能被当作 amount
        let r = RecordParser.parse("2026-08-01午饭", deviceId: deviceId)!
        XCTAssertNil(r.amount, "年份不应被当 amount")
        let (Y, M, D) = ymd(r.createdAt)
        XCTAssertEqual(Y, 2026)
        XCTAssertEqual(M, 8)
        XCTAssertEqual(D, 1)
    }

    // MARK: - 顺序：日期先于金额

    func testDateExtractedBeforeAmount() {
        // 关键 case：日期里的 3/8 数字不能被当 amount
        let r = RecordParser.parse("3-5咖啡", deviceId: deviceId)!
        XCTAssertNil(r.amount, "日期里的数字不应被当 amount")
    }

    // MARK: - 真实用户案例

    func testReallifeCase1() {
        // "昨天晚上打车 28" → 昨天，amount=28
        let r = RecordParser.parse("昨天晚上打车 28", deviceId: deviceId)!
        XCTAssertEqual(r.amount, 28.0)
        XCTAssertEqual(daysBetween(r.createdAt, Date()), -1)
        XCTAssertTrue(r.content.contains("打车"))
    }

    func testReallifeCase2() {
        // "今天午饭 35 #餐" → 今天，amount=35
        let r = RecordParser.parse("今天午饭 35 #餐", deviceId: deviceId)!
        XCTAssertEqual(r.amount, 35.0)
        XCTAssertEqual(r.tags, ["餐"])
        XCTAssertEqual(ymd(r.createdAt), ymd(Date()))
    }

    func testReallifeCase3() {
        // "今早咖啡 18" → 今天
        let r = RecordParser.parse("今早咖啡 18", deviceId: deviceId)!
        XCTAssertEqual(r.amount, 18.0)
        XCTAssertEqual(ymd(r.createdAt), ymd(Date()))
    }
}

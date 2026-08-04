import XCTest

final class RecapRetentionKeyTests: XCTestCase {
    func testRetentionKeyIsScopedPerServer() {
        XCTAssertNotEqual(
            RecapPeriod.PeriodType.week.retentionKey(serverId: "account-a"),
            RecapPeriod.PeriodType.week.retentionKey(serverId: "account-b")
        )
    }

    func testRetentionKeyIsScopedPerPeriodType() {
        let types: [RecapPeriod.PeriodType] = [.week, .month, .year]
        let keys = Set(types.map { $0.retentionKey(serverId: "account-a") })
        XCTAssertEqual(keys.count, types.count)
    }

    func testRetentionKeyIsStableForSameInputs() {
        XCTAssertEqual(
            RecapPeriod.PeriodType.year.retentionKey(serverId: "account-a"),
            RecapPeriod.PeriodType.year.retentionKey(serverId: "account-a")
        )
    }
}

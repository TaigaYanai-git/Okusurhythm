import SwiftData
import XCTest
@testable import Okusurhythm

@MainActor
final class HospitalVisitTests: XCTestCase {
    private var context: ModelContext!
    private let calendar = Calendar.japanese

    override func setUp() async throws {
        let schema = Schema([Medication.self, DoseLog.self, HealthNote.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        context = ModelContext(container)
    }

    /// 毎朝1錠・残り n 錠（今日から飲み始める）
    private func med(remaining: Double) -> Medication {
        let med = Medication(name: "テスト")
        med.slots = [.morning]
        med.startDate = calendar.startOfDay(for: Date())
        med.startSlot = .morning
        med.remainingCount = remaining
        context.insert(med)
        return med
    }

    private func days(from: Date = Date(), to: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: to).day!
    }

    func testRunOutFromRemaining() throws {
        let m = med(remaining: 20)
        let item = try XCTUnwrap(HospitalVisit.runOut(of: m, context: context))
        XCTAssertEqual(days(to: item.day), 19) // 今日を含めて20回
    }

    func testPrescriptionEndIsUsedWhenEarlier() throws {
        let m = med(remaining: 100)
        m.endDate = calendar.date(byAdding: .day, value: 5, to: calendar.startOfDay(for: Date()))
        let item = try XCTUnwrap(HospitalVisit.runOut(of: m, context: context))
        XCTAssertEqual(days(to: item.day), 5)
    }

    func testDueOnlyWithinTenDays() {
        let far = med(remaining: 30)
        let near = med(remaining: 8)
        let due = HospitalVisit.due(medications: [far, near], context: context)
        XCTAssertEqual(due.map(\.medication.id), [near.id])
    }

    func testAckStopsReminderUntilRefill() {
        let m = med(remaining: 8)
        XCTAssertEqual(HospitalVisit.due(medications: [m], context: context).count, 1)
        HospitalVisit.mark(.booked, medications: [m], context: context)
        XCTAssertTrue(HospitalVisit.due(medications: [m], context: context).isEmpty)
        // 飲み忘れで数日延びても、同じ処方のあいだは知らせない
        m.remainingCount = 11
        XCTAssertTrue(HospitalVisit.due(medications: [m], context: context).isEmpty)
        // 補充して大きく先に延びたら、その処方の終わりに向けてまた知らせる
        m.remainingCount = 30
        let later = calendar.date(byAdding: .day, value: 25, to: Date())!
        XCTAssertEqual(HospitalVisit.due(medications: [m], context: context, on: later).count, 1)
    }

    func testNotNeededAlsoStops() {
        let m = med(remaining: 3)
        HospitalVisit.mark(.notNeeded, medications: [m], context: context)
        XCTAssertEqual(HospitalVisit.ack(for: m, runOut: HospitalVisit.runOut(of: m, context: context)!.day), .notNeeded)
        XCTAssertTrue(HospitalVisit.due(medications: [m], context: context).isEmpty)
    }

    func testNoDateWithoutRemainingOrEnd() {
        let m = Medication(name: "期限なし")
        context.insert(m)
        XCTAssertNil(HospitalVisit.runOut(of: m, context: context))
    }
}

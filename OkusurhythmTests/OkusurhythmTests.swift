import XCTest
@testable import Okusurhythm

final class DrugDataTests: XCTestCase {
    private let db = DrugDatabase(bundle: Bundle(for: Medication.self))

    func testBundledDataLoads() {
        XCTAssertGreaterThanOrEqual(db.drugs.count, 40)
        for drug in db.drugs {
            XCTAssertTrue(drug.source.url.hasPrefix("https://www.pmda.go.jp/"), drug.id)
        }
    }

    func testContraindicatedPair() throws {
        let simvastatin = try XCTUnwrap(db.drug(id: "simvastatin"))
        let itraconazole = try XCTUnwrap(db.drug(id: "itraconazole"))
        XCTAssertEqual(InteractionChecker.check(simvastatin, itraconazole).level, .contraindicated)
    }

    func testClassBasedMatch() throws {
        let levofloxacin = try XCTUnwrap(db.drug(id: "levofloxacin"))
        let magnesium = try XCTUnwrap(db.drug(id: "magnesium_oxide"))
        XCTAssertEqual(InteractionChecker.check(levofloxacin, magnesium).level, .caution)
    }

    func testUnrelatedPairHasNoFinding() throws {
        let rebamipide = try XCTUnwrap(db.drug(id: "rebamipide"))
        let fexofenadine = try XCTUnwrap(db.drug(id: "fexofenadine"))
        XCTAssertNil(InteractionChecker.check(rebamipide, fexofenadine).level)
    }

    func testNameMatching() {
        XCTAssertEqual(db.bestMatch(for: "ノルバスク錠5mg")?.id, "amlodipine")
        XCTAssertEqual(db.bestMatch(for: "まぐみっと")?.id, "magnesium_oxide")
        XCTAssertNil(db.bestMatch(for: "ビタミン剤"))
    }
}

final class ScheduleTests: XCTestCase {
    private let calendar = Calendar.japanese

    func testEveryNDays() {
        let med = Medication(name: "test")
        med.startDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        med.frequency = .everyNDays
        med.intervalDays = 3
        let day = { (d: Int) in self.calendar.date(from: DateComponents(year: 2026, month: 10, day: d))! }
        XCTAssertTrue(med.isScheduled(on: day(1)))
        XCTAssertFalse(med.isScheduled(on: day(2)))
        XCTAssertTrue(med.isScheduled(on: day(4)))
        XCTAssertFalse(med.isScheduled(on: calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))!))
    }

    func testEndDate() {
        let med = Medication(name: "test")
        med.startDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        med.endDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7))!
        XCTAssertTrue(med.isScheduled(on: med.endDate!))
        XCTAssertFalse(med.isScheduled(on: calendar.date(byAdding: .day, value: 1, to: med.endDate!)!))
    }

    func testDosageSummary() {
        let med = Medication(name: "test")
        med.slots = [.evening, .morning]
        med.amountPerDose = 0.5
        XCTAssertEqual(med.dosageSummary, "1日2回 0.5錠")
        XCTAssertEqual(med.slots, [.morning, .evening])
    }

    func testAllergyMatch() {
        let note = HealthNote(kind: .allergy, title: "ペニシリン系、卵")
        let drug = DrugDatabase(bundle: Bundle(for: Medication.self)).drug(id: "amoxicillin")
        XCTAssertEqual(AllergyMatcher.matches(name: "サワシリン", drug: drug, notes: [note]).count,
                       drug?.category.contains("ペニシリン") == true ? 1 : 0)
        XCTAssertTrue(AllergyMatcher.matches(name: "ノルバスク", drug: nil, notes: [note]).isEmpty)
    }
}

final class StartSlotTests: XCTestCase {
    private let calendar = Calendar.japanese
    private func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: d))! }

    func testStartFromNoon() {
        let med = Medication(name: "test")
        med.slots = [.morning, .noon, .evening]
        med.startDate = day(1)
        med.startSlot = .noon
        XCTAssertEqual(med.slots(on: day(1)), [.noon, .evening])
        XCTAssertEqual(med.slots(on: day(2)), [.morning, .noon, .evening])
    }

    func testMidDayStartWithPeriodEndsNextMorning() {
        // 3日分を昼から → 1日目 昼夜、2・3日目 朝昼夜、4日目 朝 = 9回
        let med = Medication(name: "test")
        med.slots = [.morning, .noon, .evening]
        med.startDate = day(1)
        med.startSlot = .noon
        med.endDate = day(4)
        XCTAssertEqual(med.slots(on: day(4)), [.morning])
        XCTAssertEqual((1...5).map { med.slots(on: day($0)).count }.reduce(0, +), 9)
    }

    func testStartSlotNotSelectedIsIgnored() {
        let med = Medication(name: "test")
        med.slots = [.evening]
        med.startDate = day(1)
        med.startSlot = .morning
        XCTAssertEqual(med.slots(on: day(1)), [.evening])
    }
}

final class RunOutTests: XCTestCase {
    private let calendar = Calendar.japanese
    private func day(_ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: d, hour: h))!
    }

    func testRemainingDecidesLastDose() {
        // 1日3回1錠、残り7錠を1日の朝から → 1日朝昼夜、2日朝昼夜、3日朝で終わり
        let med = Medication(name: "test")
        med.slots = [.morning, .noon, .evening]
        med.startDate = day(1)
        let end = RunOutPlanner.lastDose(of: med, remaining: 7, from: day(1))
        XCTAssertEqual(end, RunOutPlanner.End(day: calendar.startOfDay(for: day(3)), slot: .morning))
    }

    func testAlreadyLoggedDosesAreSkipped() {
        // 今日の朝は記録済み（残りから引かれている）→ 残り2錠は昼・夜
        let med = Medication(name: "test")
        med.slots = [.morning, .noon, .evening]
        med.startDate = day(1)
        let end = RunOutPlanner.lastDose(of: med, remaining: 2, from: day(5, 9), logged: ["2026-10-05-morning"])
        XCTAssertEqual(end, RunOutPlanner.End(day: calendar.startOfDay(for: day(5)), slot: .evening))
    }

    func testEndSlotLimitsLastDay() {
        let med = Medication(name: "test")
        med.slots = [.morning, .noon, .evening]
        med.startDate = day(1)
        med.endDate = day(3)
        med.endSlotRaw = DoseSlot.noon.rawValue
        XCTAssertEqual(med.slots(on: day(3)), [.morning, .noon])
        XCTAssertEqual(med.slots(on: day(4)), [])
    }

    func testHalfTablets() {
        // 1回0.5錠・1日1回、残り2錠 → 4日分
        let med = Medication(name: "test")
        med.slots = [.evening]
        med.amountPerDose = 0.5
        med.startDate = day(1)
        XCTAssertEqual(RunOutPlanner.lastDose(of: med, remaining: 2, from: day(1))?.day, calendar.startOfDay(for: day(4)))
    }
}

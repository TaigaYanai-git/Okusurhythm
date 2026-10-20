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

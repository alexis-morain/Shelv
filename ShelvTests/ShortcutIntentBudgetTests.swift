import XCTest

/// These bounds are the reason Siri used to announce a failure while music was
/// already starting: the app waited longer for confirmed playback than the
/// system was willing to wait for an answer.
final class ShortcutIntentBudgetTests: XCTestCase {
    /// Classic SiriKit allows roughly ten seconds per resolve/confirm/handle
    /// phase, so the answer has to be well inside that.
    func testSiriKitBudgetStaysInsideTheTenSecondPhaseLimit() {
        XCTAssertLessThan(
            ShortcutIntentBudget.siriKit.responseDeadline,
            .seconds(10)
        )
    }

    /// App Intents allow roughly thirty seconds per `perform()`.
    func testAppIntentBudgetStaysInsideTheThirtySecondPerformLimit() {
        XCTAssertLessThan(
            ShortcutIntentBudget.appIntent.responseDeadline,
            .seconds(30)
        )
    }

    /// SiriKit is the stricter of the two, so it must never inherit the roomier
    /// App Intents deadline by accident.
    func testSiriKitAnswersSoonerThanAppIntents() {
        XCTAssertLessThan(
            ShortcutIntentBudget.siriKit.responseDeadline,
            ShortcutIntentBudget.appIntent.responseDeadline
        )
    }

    func testBudgetsAreDistinguishableInDiagnostics() {
        XCTAssertNotEqual(
            ShortcutIntentBudget.siriKit.diagnosticName,
            ShortcutIntentBudget.appIntent.diagnosticName
        )
    }
}

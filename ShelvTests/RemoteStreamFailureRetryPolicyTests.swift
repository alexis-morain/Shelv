import XCTest

final class RemoteStreamFailureRetryPolicyTests: XCTestCase {

    // MARK: - RemoteStreamFailureErrorClassifier

    func testClassifiesKnownTransientNetworkErrorCodes() {
        let transientCodes: [URLError.Code] = [
            .networkConnectionLost,
            .timedOut,
            .notConnectedToInternet,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed,
        ]
        for code in transientCodes {
            XCTAssertTrue(
                RemoteStreamFailureErrorClassifier.isTransientNetworkError(URLError(code)),
                "Expected \(code) to be classified as transient"
            )
        }
    }

    func testDoesNotClassifyPermanentURLErrorsAsTransient() {
        let permanentCodes: [URLError.Code] = [
            .userAuthenticationRequired,
            .badServerResponse,
            .cannotDecodeContentData,
            .unsupportedURL,
            .cancelled,
        ]
        for code in permanentCodes {
            XCTAssertFalse(
                RemoteStreamFailureErrorClassifier.isTransientNetworkError(URLError(code)),
                "Expected \(code) to NOT be classified as transient"
            )
        }
    }

    func testNonURLErrorIsNotTransient() {
        struct SomeOtherError: Error {}
        XCTAssertFalse(RemoteStreamFailureErrorClassifier.isTransientNetworkError(SomeOtherError()))
    }

    func testNilErrorIsNotTransient() {
        XCTAssertFalse(RemoteStreamFailureErrorClassifier.isTransientNetworkError(nil))
    }

    // MARK: - RemoteStreamFailureRetryPolicy

    func testRetriesUpToMaxAttemptsForTransientErrors() {
        var policy = RemoteStreamFailureRetryPolicy()
        let error = URLError(.networkConnectionLost)

        for attempt in 1...RemoteStreamFailureRetryPolicy.maxAttempts {
            XCTAssertTrue(policy.shouldRetry(for: error), "Attempt \(attempt) should be allowed")
        }
        XCTAssertFalse(
            policy.shouldRetry(for: error),
            "Should stop retrying once maxAttempts is exceeded"
        )
    }

    func testPermanentErrorNeverRetriesAndDoesNotConsumeBudget() {
        var policy = RemoteStreamFailureRetryPolicy()

        XCTAssertFalse(policy.shouldRetry(for: URLError(.userAuthenticationRequired)))
        // A permanent error resets the budget rather than consuming it, so a
        // transient error right after still gets the full attempt count.
        for attempt in 1...RemoteStreamFailureRetryPolicy.maxAttempts {
            XCTAssertTrue(
                policy.shouldRetry(for: URLError(.timedOut)),
                "Attempt \(attempt) should be allowed after a permanent error reset the budget"
            )
        }
        XCTAssertFalse(policy.shouldRetry(for: URLError(.timedOut)))
    }

    func testResetRestoresFullRetryBudget() {
        var policy = RemoteStreamFailureRetryPolicy()
        let error = URLError(.timedOut)

        for _ in 1...RemoteStreamFailureRetryPolicy.maxAttempts {
            XCTAssertTrue(policy.shouldRetry(for: error))
        }
        XCTAssertFalse(policy.shouldRetry(for: error))

        policy.reset()

        for attempt in 1...RemoteStreamFailureRetryPolicy.maxAttempts {
            XCTAssertTrue(policy.shouldRetry(for: error), "Attempt \(attempt) should be allowed after reset")
        }
    }

    func testNilErrorNeverRetries() {
        var policy = RemoteStreamFailureRetryPolicy()
        XCTAssertFalse(policy.shouldRetry(for: nil))
    }
}

import Foundation

/// Injected entry point for the iOS App Intents. Resolving it through
/// `@Dependency` instead of reaching for the singleton keeps the intents
/// testable, while every platform and the iOS/macOS audio schema still share
/// one executor so cancellation, offline fallbacks, queue handling and
/// diagnostics agree.
@MainActor
final class ShortcutPlaybackCoordinator: @unchecked Sendable {
    static let shared = ShortcutPlaybackCoordinator()

    private init() {}

    func execute(
        _ command: ShortcutPlaybackCommand,
        budget: ShortcutIntentBudget = .appIntent
    ) async throws {
        try await ShelvSystemIntentPlaybackService.shared.execute(command, budget: budget)
    }
}

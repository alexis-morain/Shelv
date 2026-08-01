import Foundation

/// Reine Entscheidungslogik dafür, welche Songs ein Recap-Zeitraum erwarten sollte, wenn einer
/// der Top-Songs tot ist (z.B. weil sich seine ID server-seitig geändert hat). Tote Kandidaten
/// werden nur im Rückgabewert übersprungen — hier wird nichts aus der Datenbank gelöscht, das
/// bleibt allein Aufgabe des Database-Cleanup-Tasks. Netzwerk ist über eine injizierte Closure
/// entkoppelt, damit sich das Backfill-Verhalten ohne echten Server testen lässt.
nonisolated enum RecapExpectedSongsLogic {
    struct Resolution<Item> {
        /// Finale erwartete IDs, in Reihenfolge — tote Kandidaten sind bereits durch den
        /// nächsten noch lebenden Kandidaten aus `backups` ersetzt (oder ausgelassen, falls
        /// keiner mehr übrig war).
        let finalIds: [String]
        /// Frisch aufgelöste Items für IDs, die noch nicht als lebend bekannt waren (weder
        /// Kandidat noch Backup-Ersatz war vorher schon über `alreadyKnownAlive` bestätigt).
        let resolvedItems: [String: Item]
    }

    /// - Parameters:
    ///   - initial: die ursprünglich erwarteten IDs (z.B. Top-N nach Play-Count).
    ///   - backups: zusätzliche Kandidaten hinter `initial`, aus denen ein toter Eintrag
    ///     ersetzt werden kann.
    ///   - alreadyKnownAlive: liefert `true`, wenn für diese ID bereits anderweitig feststeht,
    ///     dass sie noch lebt (z.B. weil sie schon in der aktuellen Server-Playlist steht) —
    ///     für solche IDs wird `resolve` gar nicht erst aufgerufen.
    ///   - resolve: liefert das Item, wenn die ID noch auflöst, sonst `nil` (tot).
    static func resolveExpectedIds<Item>(
        initial: [String],
        backups: [String],
        alreadyKnownAlive: (String) -> Bool,
        resolve: (String) async throws -> Item?
    ) async rethrows -> Resolution<Item> {
        var usedIds = Set(initial)
        var backupIterator = backups.makeIterator()
        func takeNextBackup() -> String? {
            while let candidate = backupIterator.next() {
                if !usedIds.contains(candidate) {
                    usedIds.insert(candidate)
                    return candidate
                }
            }
            return nil
        }

        var finalIds: [String] = []
        var resolvedItems: [String: Item] = [:]

        for id in initial {
            if alreadyKnownAlive(id) {
                finalIds.append(id)
                continue
            }
            if let item = try await resolve(id) {
                finalIds.append(id)
                resolvedItems[id] = item
                continue
            }
            while let backupId = takeNextBackup() {
                if alreadyKnownAlive(backupId) {
                    finalIds.append(backupId)
                    break
                }
                if let backupItem = try await resolve(backupId) {
                    finalIds.append(backupId)
                    resolvedItems[backupId] = backupItem
                    break
                }
            }
        }

        return Resolution(finalIds: finalIds, resolvedItems: resolvedItems)
    }
}

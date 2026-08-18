import Foundation

/// Stellt den Nachschub des Endlos-Modus zusammen. Reine Logik ohne Netz und ohne Player-Zustand,
/// damit die Mischung testbar bleibt.
nonisolated enum InfinityMixPoolBuilder {
    /// Titel pro Nachfüll-Durchlauf.
    static let poolSize = 25
    /// Jeder n-te Titel kommt aus dem Zufallstopf: ohne diesen Anteil bliebe der Mix bei einem
    /// einzigen Künstler hängen, sobald der Server nur enge Treffer liefert.
    static let discoveryStride = 4
    /// So viele zuletzt eingereihte Titel merkt sich der Endlos-Modus, um Wiederholungen zu meiden.
    static let historyLimit = 200

    /// Mischt zum laufenden Song passende Titel mit einem Anteil Zufallstiteln.
    /// - Parameters:
    ///   - similar: Treffer zum Seed, in Server-Reihenfolge (Relevanz zuerst).
    ///   - discovery: Zufallstitel aus der Bibliothek.
    ///   - excluding: IDs, die nicht erneut vorkommen dürfen (laufender Song, Queue, Verlauf).
    ///   - limit: Maximale Poolgröße.
    static func pool(
        similar: [Song],
        discovery: [Song],
        excluding excluded: Set<String> = [],
        limit: Int = poolSize
    ) -> [Song] {
        guard limit > 0 else { return [] }
        var seen = excluded
        var similarQueue = similar
        var discoveryQueue = discovery
        var result: [Song] = []

        func take(from queue: inout [Song]) -> Song? {
            while !queue.isEmpty {
                let song = queue.removeFirst()
                guard seen.insert(song.id).inserted else { continue }
                return song
            }
            return nil
        }

        while result.count < limit {
            let position = result.count + 1
            let wantsDiscovery = discoveryStride > 0 && position % discoveryStride == 0
            let picked = wantsDiscovery
                ? take(from: &discoveryQueue) ?? take(from: &similarQueue)
                : take(from: &similarQueue) ?? take(from: &discoveryQueue)
            guard let song = picked else { break }
            result.append(song)
        }
        return result
    }

    /// Hängt neue IDs an den Verlauf und kappt ihn vorne, damit er nicht unbegrenzt wächst.
    static func appendingHistory(_ history: [String], adding ids: [String], limit: Int = historyLimit) -> [String] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        var merged: [String] = []
        for id in (history + ids).reversed() where seen.insert(id).inserted {
            merged.append(id)
            if merged.count == limit { break }
        }
        return merged.reversed()
    }
}

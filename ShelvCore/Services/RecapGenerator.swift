import Foundation

// MARK: - Period Calculation

extension RecapPeriod {
    /// Letzte abgeschlossene Woche (Mo–So) relativ zu `now`
    static func lastWeek(relativeTo now: Date = Date()) -> RecapPeriod? {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        guard
            let startOfThisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start,
            let start = cal.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek),
            let end   = cal.date(byAdding: .second, value: -1, to: startOfThisWeek)
        else { return nil }
        return RecapPeriod(type: .week, start: start, end: end)
    }

    /// Letzter abgeschlossener Monat relativ zu `now`
    static func lastMonth(relativeTo now: Date = Date()) -> RecapPeriod? {
        let cal = Calendar.current
        guard
            let startOfThisMonth = cal.dateInterval(of: .month, for: now)?.start,
            let start = cal.date(byAdding: .month, value: -1, to: startOfThisMonth),
            let end   = cal.date(byAdding: .second, value: -1, to: startOfThisMonth)
        else { return nil }
        return RecapPeriod(type: .month, start: start, end: end)
    }

    /// Letztes abgeschlossenes Jahr relativ zu `now`
    static func lastYear(relativeTo now: Date = Date()) -> RecapPeriod? {
        let cal = Calendar.current
        guard
            let startOfThisYear = cal.dateInterval(of: .year, for: now)?.start,
            let start = cal.date(byAdding: .year, value: -1, to: startOfThisYear),
            let end   = cal.date(byAdding: .second, value: -1, to: startOfThisYear)
        else { return nil }
        return RecapPeriod(type: .year, start: start, end: end)
    }
}

// MARK: - Period Key (für CloudKit recordName)

extension RecapPeriod {
    /// Eindeutiger String für diese Periode — wird Teil des CloudKit-recordName.
    var periodKey: String {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2          // Montag
        cal.minimumDaysInFirstWeek = 4 // ISO-8601-Wochennummerierung
        switch type {
        case .week:
            let week = cal.component(.weekOfYear, from: start)
            let year = cal.component(.yearForWeekOfYear, from: start)
            return String(format: "%04d-W%02d", year, week)
        case .month:
            let comps = cal.dateComponents([.year, .month], from: start)
            let year = comps.year ?? cal.component(.year, from: start)
            let month = comps.month ?? cal.component(.month, from: start)
            return String(format: "%04d-%02d", year, month)
        case .year:
            let year = cal.component(.year, from: start)
            return String(format: "%04d", year)
        }
    }
}

// MARK: - GenerateOutcome

enum GenerateOutcome {
    case created
    case adopted
    case skippedExistingEntry
    case skippedNoPlays
}

// MARK: - RecapGenerator

actor RecapGenerator {
    static let shared = RecapGenerator()
    private init() {}

    @discardableResult
    func generate(period: RecapPeriod, serverId: String, trigger: String = "auto", isTest: Bool = false) async throws -> GenerateOutcome {
        let periodKey = await MainActor.run { period.periodKey }
        let playlistName = await MainActor.run { period.playlistName }
        let basePart = "\(serverId.lowercased()).\(periodKey)"
        let recordName = isTest ? "test.\(basePart)" : basePart

        CloudKitSyncService.recapLog("[RecapGen] ── Trigger: \(trigger)\(isTest ? " [TEST]" : "") ──")
        CloudKitSyncService.recapLog("[RecapGen] Period: \(period.type.rawValue) \(playlistName)")
        CloudKitSyncService.recapLog("[RecapGen] periodKey: \(periodKey)")
        CloudKitSyncService.recapLog("[RecapGen] recordName: \(recordName)")

        // Retention muss auf jedem nicht-werfenden Ausgang laufen, nicht nur wenn tatsächlich neu
        // erstellt wurde — sonst bleibt eine Woche, die per lokalem Registry-Treffer oder iCloud-
        // Adoption früh zurückkehrt (der Normalfall nach der ersten Erstellung), für immer
        // ungeprüft, und ein einmal übers Limit gewachsener Bestand wird nie mehr eingefangen.
        func run() async throws -> GenerateOutcome {
            CloudKitSyncService.recapLog("[RecapGen] Step 1: flushAndWait")
            do {
                try await CloudKitSyncService.shared.flushAndWait()
                CloudKitSyncService.recapLog("[RecapGen] Step 1: flushAndWait — done")
            } catch {
                CloudKitSyncService.recapLog("[RecapGen] Step 1: flushAndWait — failed: \(error.localizedDescription)")
                throw error
            }

            CloudKitSyncService.recapLog("[RecapGen] Step 2: local registry check (ckRecordName)")
            if await PlayLogService.shared.registryEntry(byCKRecordName: recordName) != nil {
                CloudKitSyncService.recapLog("[RecapGen] Step 2: FOUND — existing entry matched by ckRecordName")
                CloudKitSyncService.recapLog("[RecapGen] Result: SKIPPED — playlist already exists for this period")
                return .skippedExistingEntry
            }
            CloudKitSyncService.recapLog("[RecapGen] Step 2: not found")

            CloudKitSyncService.recapLog("[RecapGen] Step 3: local registry check (periodStart, isTest=\(isTest))")
            if await PlayLogService.shared.registryEntry(
                serverId: serverId,
                periodType: period.type.rawValue,
                periodStart: period.start.timeIntervalSince1970,
                isTest: isTest
            ) != nil {
                CloudKitSyncService.recapLog("[RecapGen] Step 3: FOUND — existing entry matched by periodStart")
                CloudKitSyncService.recapLog("[RecapGen] Result: SKIPPED — playlist already exists for this period")
                return .skippedExistingEntry
            }
            CloudKitSyncService.recapLog("[RecapGen] Step 3: not found")

            CloudKitSyncService.recapLog("[RecapGen] Step 4: iCloud marker fetch (isTest=\(isTest))")
            if let existing = await CloudKitSyncService.shared.fetchRecapMarker(
                serverId: serverId, periodKey: periodKey, isTest: isTest
            ) {
                CloudKitSyncService.recapLog("[RecapGen] Step 4: FOUND — adopting iCloud marker, playlistId=\(existing.playlistId)")
                await PlayLogService.shared.registerPlaylist(existing)
                CloudKitSyncService.recapLog("[RecapGen] Result: ADOPTED — registered remote playlist (\(existing.playlistId))")
                return .adopted
            }
            CloudKitSyncService.recapLog("[RecapGen] Step 4: not found")

            CloudKitSyncService.recapLog("[RecapGen] Step 5: top songs query (limit=\(period.type.songLimit))")
            let topSongs = await PlayLogService.shared.topSongs(
                serverId: serverId,
                from: period.start,
                to: period.end,
                limit: period.type.songLimit
            )
            CloudKitSyncService.recapLog("[RecapGen] Step 5: \(topSongs.count) plays found")
            guard !topSongs.isEmpty else {
                CloudKitSyncService.recapLog("[RecapGen] Result: ABORTED — no plays in period")
                return .skippedNoPlays
            }

            CloudKitSyncService.recapLog("[RecapGen] Step 6: Navidrome createPlaylist")
            let songIds = topSongs.map { $0.songId }
            let playlist: Playlist
            do {
                playlist = try await SubsonicAPIService.shared.createPlaylist(
                    name: playlistName,
                    songIds: songIds,
                    comment: "Shelv Recap"
                )
                CloudKitSyncService.recapLog("[RecapGen] Step 6: created playlistId=\(playlist.id)")
            } catch {
                CloudKitSyncService.recapLog("[RecapGen] Step 6: FAILED — \(error.localizedDescription)")
                CloudKitSyncService.recapLog("[RecapGen] Result: FAILED — Navidrome createPlaylist failed")
                throw error
            }

            var entry = RecapRegistryRecord(
                playlistId: playlist.id,
                serverId: serverId,
                periodType: period.type.rawValue,
                periodStart: period.start.timeIntervalSince1970,
                periodEnd: period.end.timeIntervalSince1970,
                ckRecordName: nil,
                isTest: isTest
            )

            CloudKitSyncService.recapLog("[RecapGen] Step 7: saveRecapMarker")
            var resultTag = "CREATED"
            var outcome: GenerateOutcome = .created
            if let markerResult = try? await CloudKitSyncService.shared.saveRecapMarker(entry, periodKey: periodKey) {
                switch markerResult {
                case .created:
                    CloudKitSyncService.recapLog("[RecapGen] Step 7: created new iCloud marker")
                    entry.ckRecordName = recordName
                case .conflict(let existingPlaylistId):
                    CloudKitSyncService.recapLog("[RecapGen] Step 7: CONFLICT — iCloud already has playlistId=\(existingPlaylistId)")
                    let remoteExists = (try? await SubsonicAPIService.shared.getPlaylist(id: existingPlaylistId)) != nil
                    if remoteExists {
                        CloudKitSyncService.recapLog("[RecapGen] Step 7a: iCloud playlistId exists on Navidrome — deleting own \(playlist.id), adopting \(existingPlaylistId)")
                        try? await SubsonicAPIService.shared.deletePlaylist(id: playlist.id)
                        entry = RecapRegistryRecord(
                            playlistId: existingPlaylistId,
                            serverId: serverId,
                            periodType: period.type.rawValue,
                            periodStart: period.start.timeIntervalSince1970,
                            periodEnd: period.end.timeIntervalSince1970,
                            ckRecordName: recordName,
                            isTest: isTest
                        )
                        resultTag = "CONFLICT_RESOLVED"
                        outcome = .adopted
                    } else {
                        CloudKitSyncService.recapLog("[RecapGen] Step 7a: iCloud playlistId=\(existingPlaylistId) MISSING on Navidrome — overwriting stale marker with own \(playlist.id)")
                        await CloudKitSyncService.shared.deleteRecapMarker(ckRecordName: recordName)
                        if case .created = try? await CloudKitSyncService.shared.saveRecapMarker(entry, periodKey: periodKey) {
                            entry.ckRecordName = recordName
                        }
                        resultTag = "STALE_OVERWRITTEN"
                    }
                }
            } else {
                CloudKitSyncService.recapLog("[RecapGen] Step 7: saveRecapMarker returned nil (iCloud disabled or error)")
            }

            CloudKitSyncService.recapLog("[RecapGen] Step 8: registerPlaylist (local DB)")
            await PlayLogService.shared.registerPlaylist(entry)
            CloudKitSyncService.recapLog("[RecapGen] Step 8: local DB written")

            CloudKitSyncService.recapLog("[RecapGen] Result: \(resultTag) — playlistId=\(entry.playlistId)")
            return outcome
        }

        let outcome = try await run()
        if !isTest {
            await enforceRetention(periodType: period.type, serverId: serverId)
        }
        return outcome
    }

    private func enforceRetention(periodType: RecapPeriod.PeriodType, serverId: String) async {
        let limit = await MainActor.run {
            let raw = UserDefaults.standard.integer(forKey: periodType.retentionKey(serverId: serverId))
            return raw > 0 ? raw : periodType.defaultRetention
        }

        let entries = await PlayLogService.shared.allRegistryEntries(serverId: serverId)
            .filter { $0.periodType == periodType.rawValue && !$0.isTest }

        guard entries.count > limit else { return }

        // allRegistryEntries ist DESC nach periodStart — älteste sind am Ende
        let toDelete = entries.suffix(entries.count - limit)
        for entry in toDelete {
            CloudKitSyncService.debugLog("[Retention] deleting playlistId=\(entry.playlistId) marker=\(entry.ckRecordName ?? "nil") period=\(entry.periodType)/\(Date(timeIntervalSince1970: entry.periodStart))")
            do {
                try await SubsonicAPIService.shared.deletePlaylist(id: entry.playlistId)
            } catch where Self.isDefinitiveNotFound(error) {
                CloudKitSyncService.debugLog("[Retention] playlist already gone on server, forgetting locally")
            } catch {
                // Nicht lokal vergessen, wenn der Server-Delete fehlschlägt (z. B. durch einen
                // Server-Wechsel mitten im Request) — sonst bleibt die Playlist als Waise auf dem
                // Server liegen und wird nie wieder gezählt oder erneut versucht. Der nächste
                // enforceRetention-Lauf sieht denselben Eintrag wieder und holt den Delete nach.
                CloudKitSyncService.debugLog("[Retention] delete FAILED, keeping local entry for retry: \(error.localizedDescription)")
                continue
            }
            if let ckName = entry.ckRecordName {
                await CloudKitSyncService.shared.queueRecapMarkerDeletion(ckRecordName: ckName)
            }
            await PlayLogService.shared.deleteRegistryEntry(playlistId: entry.playlistId)
        }
    }

    private nonisolated static func isDefinitiveNotFound(_ error: Error) -> Bool {
        guard let apiError = error as? SubsonicAPIError,
              case .apiError(let code, let message) = apiError
        else { return false }
        return RecapSyncLogic.isDefinitiveNotFound(code: code, message: message)
    }
}

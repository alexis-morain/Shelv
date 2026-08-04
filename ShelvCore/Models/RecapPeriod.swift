import Foundation

// MARK: - RecapPeriod

nonisolated struct RecapPeriod: Sendable {
    enum PeriodType: String, Sendable {
        case week, month, year

        nonisolated var songLimit: Int {
            switch self {
            case .week:         return 25
            case .month, .year: return 50
            }
        }

        // Mindestwartezeit nach Periodenende – gibt Offline-Geräten Zeit zum Hochladen.
        static let weekGraceHours  = 6
        static let monthGraceHours = 6
        static let yearGraceHours  = 6

        var gracePeriodHours: Int {
            switch self {
            case .week:  return Self.weekGraceHours
            case .month: return Self.monthGraceHours
            case .year:  return Self.yearGraceHours
            }
        }

        private var retentionBaseKey: String {
            switch self {
            case .week:  return "recapWeeklyRetention"
            case .month: return "recapMonthlyRetention"
            case .year:  return "recapYearlyRetention"
            }
        }

        /// Retention is a personal preference tied to whose listening history it prunes,
        /// not a device-wide setting — scoped per account (`serverId` = the account's
        /// stableId) so a family sharing one server/device doesn't have one member's
        /// retention choice silently pruning another member's recaps.
        func retentionKey(serverId: String) -> String {
            "\(retentionBaseKey).\(serverId)"
        }

        var defaultRetention: Int {
            switch self {
            case .week:  return 1
            case .month: return 12
            case .year:  return 3
            }
        }
    }

    let type: PeriodType
    let start: Date
    let end: Date

    var playlistName: String {
        switch type {
        case .week:
            var cal = Calendar(identifier: .gregorian)
            cal.locale = Locale(identifier: "en_US_POSIX")
            let startYear  = cal.component(.year, from: start)
            let endYear    = cal.component(.year, from: end)
            let startMonth = cal.component(.month, from: start)
            let endMonth   = cal.component(.month, from: end)

            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "d"

            let monthFmt = DateFormatter()
            monthFmt.dateFormat = "MMM"
            monthFmt.locale = Locale(identifier: "en_US_POSIX")

            let yearFmt = DateFormatter()
            yearFmt.dateFormat = "yyyy"

            let sd = dayFmt.string(from: start)
            let ed = dayFmt.string(from: end)
            let sm = monthFmt.string(from: start)
            let em = monthFmt.string(from: end)
            let sy = yearFmt.string(from: start)
            let ey = yearFmt.string(from: end)

            if startYear != endYear {
                return "\(sd). \(sm) \(sy) – \(ed). \(em) \(ey)"
            } else if startMonth == endMonth {
                return "\(sd).–\(ed). \(em) \(ey)"
            } else {
                return "\(sd). \(sm) – \(ed). \(em) \(ey)"
            }

        case .month:
            let fmt = DateFormatter()
            fmt.dateFormat = "MMMM yyyy"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            return fmt.string(from: start)

        case .year:
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy"
            return fmt.string(from: start)
        }
    }
}

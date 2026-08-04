import SwiftUI

struct RecapSettingsView: View {
    @EnvironmentObject var serverStore: ServerStore
    @EnvironmentObject var recapStore: RecapStore
    @EnvironmentObject var ckStatus: CloudKitSyncStatus
    @AppStorage("themeColor") private var themeColorName = "violet"
    @AppStorage("recapWeeklyEnabled")    private var recapWeeklyEnabled    = true
    @AppStorage("recapMonthlyEnabled")   private var recapMonthlyEnabled   = true
    @AppStorage("recapYearlyEnabled")    private var recapYearlyEnabled    = true

    @State private var showVerifySheet = false
    @State private var weekRetentionDraft:  Int = 1
    @State private var monthRetentionDraft: Int = 12
    @State private var yearRetentionDraft:  Int = 3
    @State private var pendingRetention: PendingRetentionChange?

    private struct PendingRetentionChange: Identifiable {
        let id = UUID()
        let serverId: String
        let type: RecapPeriod.PeriodType
        let newValue: Int
        let excess: Int
    }

    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    var body: some View {
        List {
            // MARK: Perioden
            Section(String(localized: "periods")) {
                recapPeriodRow(
                    title: String(localized: "weekly"),
                    icon: "calendar",
                    enabled: $recapWeeklyEnabled,
                    retention: $weekRetentionDraft,
                    retentionRange: 1...52,
                    type: .week
                )
                recapPeriodRow(
                    title: String(localized: "monthly"),
                    icon: "calendar.badge.clock",
                    enabled: $recapMonthlyEnabled,
                    retention: $monthRetentionDraft,
                    retentionRange: 1...24,
                    type: .month
                )
                recapPeriodRow(
                    title: String(localized: "yearly"),
                    icon: "calendar.badge.checkmark",
                    enabled: $recapYearlyEnabled,
                    retention: $yearRetentionDraft,
                    retentionRange: 1...10,
                    type: .year
                )
            }

            // MARK: Logs
            if let sid = serverStore.activeServer?.stableId {
                Section(String(localized: "logs")) {
                    NavigationLink(destination:
                        RecapRegistryView(serverId: sid)
                            .environmentObject(recapStore)
                    ) {
                        Label { Text(String(localized: "registry")) } icon: {
                            Image(systemName: "square.stack.3d.up").foregroundStyle(accentColor)
                        }
                    }
                    NavigationLink(destination:
                        RecapCreationLogView()
                            .environmentObject(ckStatus)
                    ) {
                        Label { Text(String(localized: "recap_log")) } icon: {
                            Image(systemName: "sparkles.rectangle.stack").foregroundStyle(accentColor)
                        }
                    }
                    NavigationLink(destination: RecapMarkersLogView(serverId: sid)) {
                        Label { Text(String(localized: "autogen_markers")) } icon: {
                            Image(systemName: "checkmark.circle.badge.questionmark").foregroundStyle(accentColor)
                        }
                    }
                }

                // MARK: Actions
                Section(String(localized: "actions")) {
                    Button {
                        showVerifySheet = true
                    } label: {
                        Label { Text(String(localized: "sync_with_navidrome")) } icon: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(accentColor)
                        }
                    }
                    NavigationLink(destination:
                        RecapAdvancedView(serverId: sid)
                            .environmentObject(recapStore)
                    ) {
                        Label { Text(String(localized: "advanced")) } icon: {
                            Image(systemName: "slider.horizontal.2.square").foregroundStyle(accentColor)
                        }
                    }
                }
            }

            PlayerBottomSpacer()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
        .tint(accentColor)
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
        .navigationTitle(String(localized: "recap_settings"))
        .sheet(isPresented: $showVerifySheet) {
            if let sid = serverStore.activeServer?.stableId {
                RecapVerifyView(serverId: sid)
                    .environmentObject(recapStore)
            }
        }
        .alert(
            pendingRetention.map {
                String(format: String(localized: "delete_count_period_format"), $0.excess, periodTypeName($0.type))
            } ?? "",
            isPresented: Binding(
                get: { pendingRetention != nil },
                set: { if !$0 { pendingRetention = nil } }
            ),
            presenting: pendingRetention
        ) { pending in
            Button(String(localized: "delete"), role: .destructive) {
                // Bewusst der Account, der beim Anstoßen der Änderung aktiv war (`pending.serverId`),
                // nicht `serverStore.activeServer` neu abgefragt — sonst könnte ein Account-Wechsel
                // während des `await` die Buchhaltung auf den falschen Account schreiben lassen.
                let sid = pending.serverId
                let type = pending.type
                let newValue = pending.newValue
                Task {
                    await recapStore.applyRetention(
                        periodType: type, limit: newValue, serverId: sid
                    )
                    setStoredRetention(type, newValue, serverId: sid)
                }
                pendingRetention = nil
            }
            Button(String(localized: "cancel"), role: .cancel) {
                setDraft(pending.type, storedRetention(for: pending.type, serverId: pending.serverId))
                pendingRetention = nil
            }
        } message: { _ in
            Text(String(localized: "these_playlists_will_be_permanently_deleted_from_n"))
        }
        // `id:` sorgt dafür, dass beim Account-Wechsel (z.B. über ein anderes Fenster,
        // während dieses Settings-Fenster offen bleibt) die Drafts neu für den jetzt
        // aktiven Account geladen werden, statt die Werte des vorigen Accounts zu zeigen.
        .task(id: serverStore.activeServer?.stableId) {
            let sid = serverStore.activeServer?.stableId
            weekRetentionDraft  = storedRetention(for: .week, serverId: sid)
            monthRetentionDraft = storedRetention(for: .month, serverId: sid)
            yearRetentionDraft  = storedRetention(for: .year, serverId: sid)
        }
    }

    // MARK: - Period Row

    @ViewBuilder
    private func recapPeriodRow(
        title: String, icon: String,
        enabled: Binding<Bool>,
        retention: Binding<Int>,
        retentionRange: ClosedRange<Int>,
        type: RecapPeriod.PeriodType
    ) -> some View {
        Toggle(isOn: enabled) {
            Label { Text(title) } icon: {
                Image(systemName: icon).foregroundStyle(accentColor)
            }
        }
        .tint(accentColor)

        if enabled.wrappedValue {
            Stepper(value: retention, in: retentionRange) {
                HStack {
                    Text(String(localized: "keep")).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(retention.wrappedValue)").foregroundStyle(.secondary).monospacedDigit()
                }
            }
            .padding(.leading, 36)
            .onChange(of: retention.wrappedValue) { _, newValue in
                handleRetentionChange(type: type, newValue: newValue)
            }
        }
    }

    // Retention ist personenbezogen (bestimmt, wessen Recaps gelöscht werden), deshalb
    // bewusst kein `@AppStorage` mit fixem Key, sondern pro Account (`stableId`) gescoped
    // — sonst würde ein Familienmitglied mit seiner Einstellung die eines anderen
    // Accounts auf demselben Server/Gerät überschreiben.
    private func storedRetention(for type: RecapPeriod.PeriodType, serverId: String?) -> Int {
        guard let serverId else { return type.defaultRetention }
        let raw = UserDefaults.standard.integer(forKey: type.retentionKey(serverId: serverId))
        return raw > 0 ? raw : type.defaultRetention
    }

    private func setStoredRetention(_ type: RecapPeriod.PeriodType, _ value: Int, serverId: String) {
        UserDefaults.standard.set(value, forKey: type.retentionKey(serverId: serverId))
        // Geteilte Wahrheit: Änderung in iCloud spiegeln, damit andere Geräte desselben
        // Accounts sie vor ihrer nächsten Retention-Durchsetzung übernehmen.
        Task { await CloudKitSyncService.shared.recordRetentionChange(serverId: serverId) }
    }

    private func setDraft(_ type: RecapPeriod.PeriodType, _ value: Int) {
        switch type {
        case .week:  weekRetentionDraft = value
        case .month: monthRetentionDraft = value
        case .year:  yearRetentionDraft = value
        }
    }

    private func handleRetentionChange(type: RecapPeriod.PeriodType, newValue: Int) {
        // Account einmal jetzt einfangen und für den ganzen Vorgang (inkl. der async
        // Bestätigung) verwenden — nicht erneut abfragen, sonst könnte ein Account-Wechsel
        // währenddessen die Änderung am falschen Account landen lassen.
        guard let sid = serverStore.activeServer?.stableId else {
            setDraft(type, storedRetention(for: type, serverId: nil))
            return
        }
        let current = storedRetention(for: type, serverId: sid)
        guard newValue != current else { return }
        guard newValue < current else {
            setStoredRetention(type, newValue, serverId: sid)
            return
        }
        Task {
            let excess = await recapStore.excessRetentionCount(
                periodType: type, limit: newValue, serverId: sid
            )
            if excess > 0 {
                pendingRetention = PendingRetentionChange(serverId: sid, type: type, newValue: newValue, excess: excess)
            } else {
                setStoredRetention(type, newValue, serverId: sid)
            }
        }
    }

    private func periodTypeName(_ type: RecapPeriod.PeriodType) -> String {
        switch type {
        case .week:  return String(localized: "weekly_recaps")
        case .month: return String(localized: "monthly_recaps")
        case .year:  return String(localized: "yearly_recaps")
        }
    }
}

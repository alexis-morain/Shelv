import AppIntents
import Intents
import SwiftUI

struct SiriShortcutsSettingsView: View {
    @AppStorage("themeColor") private var themeColorName = "violet"
    @State private var authorizationStatus = INPreferences.siriAuthorizationStatus()

    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    var body: some View {
        List {
            // Spoken playback goes through SiriKit, which stays silent until
            // access is granted. Surfacing the state here is the only way to
            // tell "Siri can't play that" apart from a missing permission.
            if authorizationStatus != .authorized {
                Section {
                    Label {
                        Text(String(localized: authorizationStatus == .notDetermined
                            ? "siri_permission_needed"
                            : "siri_permission_denied"))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    if authorizationStatus == .notDetermined {
                        Button(String(localized: "siri_permission_allow")) {
                            INPreferences.requestSiriAuthorization { status in
                                Task { @MainActor in authorizationStatus = status }
                            }
                        }
                    } else if let settings = URL(string: UIApplication.openSettingsURLString) {
                        Link(String(localized: "siri_permission_open_settings"), destination: settings)
                    }
                }
            }

            Section {
                Text(String(localized: "siri_shortcuts_intro"))
                    .foregroundStyle(.secondary)

                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
            }

            Section(String(localized: "siri_shortcuts_actions")) {
                capability("play.fill", "siri_shortcuts_action_music")
                capability("shuffle", "siri_shortcuts_action_mixes")
                capability("arrow.down.circle.fill", "siri_shortcuts_action_downloads")
                capability("dot.radiowaves.left.and.right", "siri_shortcuts_action_radio")
                capability("playpause.fill", "siri_shortcuts_action_controls")
                // Editing the library by voice arrives with the iOS 27 audio
                // schema, so it is only advertised where it actually works.
                if #available(iOS 27.0, *) {
                    capability("star.fill", "siri_shortcuts_action_favorites")
                    capability("text.badge.plus", "siri_shortcuts_action_playlist_add")
                }
            }

            Section {
                instruction(number: 1, key: "siri_shortcuts_carplay_step_1")
                instruction(number: 2, key: "siri_shortcuts_carplay_step_2")
                instruction(number: 3, key: "siri_shortcuts_carplay_step_3")
                instruction(number: 4, key: "siri_shortcuts_carplay_step_4")
            } header: {
                Text(String(localized: "siri_shortcuts_carplay_title"))
            } footer: {
                Text(String(localized: "siri_shortcuts_carplay_footer"))
            }
        }
        .navigationTitle(String(localized: "siri_shortcuts"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { authorizationStatus = INPreferences.siriAuthorizationStatus() }
    }

    private func capability(_ systemImage: String, _ key: LocalizedStringResource) -> some View {
        Label {
            Text(String(localized: key))
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(accentColor)
        }
    }

    private func instruction(number: Int, key: LocalizedStringResource) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(accentColor, in: Circle())
            Text(String(localized: key))
        }
        .padding(.vertical, 2)
    }
}

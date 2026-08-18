import SwiftUI

struct InfinityMixPanel: View {
    @AppStorage("infinityMixAheadCount") private var infinityMixAheadCount = 1
    @AppStorage("infinityMixSeededEnabled") private var infinityMixSeededEnabled = true
    @Environment(\.themeColor) private var themeColor
    private let infinityMixAheadOptions = Array(1...10)

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "infinity_mix_ahead_count"), selection: $infinityMixAheadCount) {
                    ForEach(infinityMixAheadOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .tint(themeColor)
                .onChange(of: infinityMixAheadCount) { _, _ in
                    AudioPlayerService.shared.refreshInfinityMixWindow()
                }
                Toggle(String(localized: "infinity_mix_seeded"), isOn: $infinityMixSeededEnabled)
                    .tint(themeColor)
                    .onChange(of: infinityMixSeededEnabled) { _, _ in
                        AudioPlayerService.shared.refreshInfinityMixWindow()
                    }
            } footer: {
                Text(String(localized: "infinity_mix_seeded_footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

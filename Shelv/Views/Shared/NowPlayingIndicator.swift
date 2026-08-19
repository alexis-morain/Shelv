import SwiftUI

/// Isolierter Now-Playing-Indikator — nur dieses View beobachtet den Player,
/// damit die umgebende Row nicht alle 0.5s re-rendert.
struct NowPlayingIndicator: View {
    let songId: String
    let fallbackIndex: Int
    let accentColor: Color
    var width: CGFloat = 28
    var alignment: Alignment = .trailing

    @ObservedObject private var player = AudioPlayerService.shared

    var body: some View {
        if player.currentSong?.id == songId {
            Image(systemName: "waveform")
                .font(.subheadline)
                .foregroundStyle(accentColor)
                .frame(width: width, alignment: alignment)
                .symbolEffect(.variableColor.iterative.reversing, isActive: player.isPlaying)
        } else {
            Text("\(fallbackIndex)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: width, alignment: alignment)
        }
    }
}

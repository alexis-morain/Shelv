import SwiftUI

/// A ranked row of the artist top-songs section. The rank is what separates
/// this list from every other track list in the app, so it stays visible
/// instead of relying on position alone.
struct ArtistTopSongRow: View {
    let rank: Int
    let song: Song

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
            LibraryStarredSongRow(song: song)
        }
        .contentShape(Rectangle())
    }
}

/// Expands the top-songs section from the collapsed five rows to the full list.
struct ArtistTopSongsToggle: View {
    @Binding var isExpanded: Bool
    let accentColor: Color

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            Text(isExpanded
                 ? String(localized: "show_less")
                 : String(localized: "show_more"))
                .font(.subheadline).bold()
                .foregroundStyle(accentColor)
        }
        .buttonStyle(.plain)
    }
}

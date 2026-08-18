import SwiftUI

extension ArtistReleaseGroup {
    /// Localised in each UI target, the way the other sort and filter enums are.
    var label: String {
        switch self {
        case .all: String(localized: "release_group_all")
        case .albums: String(localized: "albums")
        case .singlesAndEPs: String(localized: "release_group_singles_eps")
        }
    }
}

/// Album / singles filter of the discography section. Only shown when the
/// artist has both kinds of release.
struct ArtistReleaseGroupPicker: View {
    @Binding var selection: ArtistReleaseGroup
    let groups: [ArtistReleaseGroup]

    var body: some View {
        Picker(String(localized: "discography"), selection: $selection) {
            ForEach(groups, id: \.rawValue) { group in
                Text(group.label).tag(group)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

/// Related artists, as the server reports them. Circular covers match the
/// artist rows used everywhere else in the library.
struct ArtistSimilarArtistsRow: View {
    let artists: [Artist]

    private let itemWidth: CGFloat = 104

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(artists) { artist in
                    NavigationLink(destination: ArtistDetailView(artist: artist)) {
                        VStack(spacing: 8) {
                            AlbumArtView(coverArtId: artist.coverArt, size: 300, isCircle: true)
                                .frame(width: itemWidth, height: itemWidth)
                            Text(artist.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: itemWidth)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }
}

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

/// Full-width artist photo behind the name and the playback actions.
///
/// Servers hand out square artist images (Navidrome caps them at 1000 px), so
/// the square is cropped to a band around its centre, where portraits keep the
/// face. Pages whose artist has no image keep the compact header instead.
struct ArtistBannerHeader<Actions: View>: View {
    let artist: Artist
    let subtitle: String?
    /// Public figures from outside the server, when the user asked for them.
    let footnote: String?
    let accentColor: Color
    @ViewBuilder let actions: Actions

    private let height: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { geo in
                AlbumArtView(coverArtId: artist.coverArt, size: 1000, cornerRadius: 0)
                    .frame(width: geo.size.width, height: geo.size.width)
                    .offset(y: -(geo.size.width - height) / 2)
            }
            .frame(height: height)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.clear, Color(UIColor.systemBackground)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.name)
                        .font(.largeTitle).bold()
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let footnote {
                        Text(footnote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }

            actions
                .padding(.horizontal)
        }
    }
}

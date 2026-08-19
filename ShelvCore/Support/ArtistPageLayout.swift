import Foundation

/// Sizing shared by the artist pages of every platform.
nonisolated enum ArtistPageLayout {
    /// Related artists requested from the server for the "fans also like" row.
    /// `getArtistInfo2` returns none at all when this is zero.
    static let similarArtistCount = 12
}

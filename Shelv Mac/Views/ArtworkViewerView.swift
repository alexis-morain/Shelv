import SwiftUI

/// Full-size artwork, opened by clicking a cover or an artist photo.
///
/// Loading goes through `CoverArtView` so the viewer inherits the memory and disk
/// cache, the retry policy and the offline fallback rather than fetching its own copy.
struct ArtworkViewerView: View {
    let coverArtId: String?
    let title: String

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = ArtworkZoomGeometry.minScale
    @State private var offset: CGSize = .zero
    @State private var gestureOffset: CGSize = .zero

    private static let side: CGFloat = 640

    private var viewport: CGSize { CGSize(width: Self.side, height: Self.side) }

    private var liveOffset: CGSize {
        ArtworkZoomGeometry.clampOffset(
            CGSize(
                width: offset.width + gestureOffset.width,
                height: offset.height + gestureOffset.height
            ),
            scale: scale,
            viewport: viewport
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            CoverArtView(
                coverArtID: coverArtId,
                requestSize: 1000,
                size: Self.side,
                cornerRadius: 0
            )
            .scaleEffect(scale)
            .offset(liveOffset)
            .frame(width: Self.side, height: Self.side)
            .clipped()
            .contentShape(Rectangle())
            .gesture(pan)
            .onTapGesture(count: 2) { toggleZoom() }
            .accessibilityLabel(title)

            HStack {
                Spacer()
                Button(String(localized: "done")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .background(Color.black)
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > ArtworkZoomGeometry.minScale else { return }
                gestureOffset = value.translation
            }
            .onEnded { _ in
                offset = liveOffset
                gestureOffset = .zero
            }
    }

    private func toggleZoom() {
        withAnimation(.snappy(duration: 0.25)) {
            scale = ArtworkZoomGeometry.scaleAfterDoubleTap(current: scale)
            offset = ArtworkZoomGeometry.clampOffset(.zero, scale: scale, viewport: viewport)
        }
    }
}

import SwiftUI

/// Full-screen artwork, opened by tapping a cover or an artist photo.
///
/// Loading goes through `AlbumArtView` so the viewer inherits the memory and disk
/// cache, the retry policy and the offline fallback rather than fetching its own copy.
struct ArtworkViewerView: View {
    let coverArtId: String?
    let title: String

    @Environment(\.dismiss) private var dismiss

    /// Committed after each gesture; the in-flight gesture value is layered on top.
    @State private var scale: CGFloat = ArtworkZoomGeometry.minScale
    @State private var gestureScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var gestureOffset: CGSize = .zero
    @State private var viewport: CGSize = .zero

    private var liveScale: CGFloat {
        ArtworkZoomGeometry.clampScale(scale * gestureScale)
    }

    private var liveOffset: CGSize {
        ArtworkZoomGeometry.clampOffset(
            CGSize(
                width: offset.width + gestureOffset.width,
                height: offset.height + gestureOffset.height
            ),
            scale: liveScale,
            viewport: viewport
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                AlbumArtView(coverArtId: coverArtId, size: 1000, cornerRadius: 0)
                    .frame(
                        width: min(proxy.size.width, proxy.size.height),
                        height: min(proxy.size.width, proxy.size.height)
                    )
                    .scaleEffect(liveScale)
                    .offset(liveOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(magnification)
                    .simultaneousGesture(pan)
                    .onTapGesture(count: 2) { toggleZoom() }
            }
            .onAppear { viewport = proxy.size }
            .onChange(of: proxy.size) { _, newValue in
                viewport = newValue
                offset = ArtworkZoomGeometry.clampOffset(offset, scale: scale, viewport: newValue)
            }
        }
        .statusBarHidden()
        .overlay(alignment: .topTrailing) { closeButton }
        .accessibilityLabel(title)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
        .accessibilityLabel(String(localized: "done"))
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { gestureScale = $0.magnification }
            .onEnded { _ in
                scale = liveScale
                offset = liveOffset
                gestureScale = 1
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                // While the artwork fits, a drag is a dismiss gesture, not a pan.
                guard scale > ArtworkZoomGeometry.minScale else { return }
                gestureOffset = value.translation
            }
            .onEnded { value in
                if ArtworkZoomGeometry.shouldDismiss(
                    verticalDrag: value.translation.height,
                    scale: scale
                ) {
                    dismiss()
                    return
                }
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

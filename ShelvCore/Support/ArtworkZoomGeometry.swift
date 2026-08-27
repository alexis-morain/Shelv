import Foundation

/// Geometry for the full-screen artwork viewer, shared by every platform that
/// can open a cover: pinch to zoom, drag to pan, swipe down to close.
///
/// Covers are square and shown aspect-fit, so at the fit scale the artwork is
/// `min(viewport.width, viewport.height)` on a side and never overflows.
nonisolated enum ArtworkZoomGeometry {
    /// The artwork fits the viewport; panning is pointless and swipe-down closes.
    static let minScale: CGFloat = 1
    /// Past this a 1000px cover is mostly interpolation, so there is nothing to gain.
    static let maxScale: CGFloat = 4
    /// Where a double tap lands, chosen so a square cover fills the short side twice over.
    static let doubleTapScale: CGFloat = 2.5
    /// How far the artwork has to travel down before the viewer closes.
    static let dismissDragDistance: CGFloat = 120

    static func clampScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minScale), maxScale)
    }

    /// How far the artwork can travel on each axis before its edge shows.
    static func maxOffset(scale: CGFloat, viewport: CGSize) -> CGSize {
        let side = min(viewport.width, viewport.height) * clampScale(scale)
        return CGSize(
            width: max(0, (side - viewport.width) / 2),
            height: max(0, (side - viewport.height) / 2)
        )
    }

    static func clampOffset(_ offset: CGSize, scale: CGFloat, viewport: CGSize) -> CGSize {
        let limit = maxOffset(scale: scale, viewport: viewport)
        return CGSize(
            width: min(max(offset.width, -limit.width), limit.width),
            height: min(max(offset.height, -limit.height), limit.height)
        )
    }

    /// A double tap zooms in from the fit scale and collapses back from anywhere else,
    /// so it is always a way out of an accidental pinch.
    static func scaleAfterDoubleTap(current: CGFloat) -> CGFloat {
        current > minScale ? minScale : doubleTapScale
    }

    /// Once zoomed in, a downward drag pans the artwork rather than closing the viewer.
    static func shouldDismiss(verticalDrag: CGFloat, scale: CGFloat) -> Bool {
        scale <= minScale && verticalDrag >= dismissDragDistance
    }
}

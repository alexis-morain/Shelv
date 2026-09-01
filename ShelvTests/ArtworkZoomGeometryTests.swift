import XCTest

final class ArtworkZoomGeometryTests: XCTestCase {
    private let viewport = CGSize(width: 400, height: 800)

    func testScaleIsClampedBetweenFitAndMaximum() {
        XCTAssertEqual(ArtworkZoomGeometry.clampScale(0.2), ArtworkZoomGeometry.minScale)
        XCTAssertEqual(ArtworkZoomGeometry.clampScale(99), ArtworkZoomGeometry.maxScale)
        XCTAssertEqual(ArtworkZoomGeometry.clampScale(2), 2)
    }

    func testArtworkThatFitsTheViewportCannotBePanned() {
        // A square cover in a 400x800 viewport is 400 wide: nothing overflows.
        let offset = ArtworkZoomGeometry.clampOffset(
            CGSize(width: 250, height: -400),
            scale: 1,
            viewport: viewport
        )

        XCTAssertEqual(offset, .zero)
    }

    func testPanningStopsAtTheArtworkEdges() {
        // At 2x the cover is 800x800: 200pt of horizontal overflow on each side,
        // and nothing vertically because the viewport is already 800 tall.
        let limit = ArtworkZoomGeometry.maxOffset(scale: 2, viewport: viewport)
        XCTAssertEqual(limit.width, 200)
        XCTAssertEqual(limit.height, 0)

        let offset = ArtworkZoomGeometry.clampOffset(
            CGSize(width: 900, height: 900),
            scale: 2,
            viewport: viewport
        )
        XCTAssertEqual(offset, CGSize(width: 200, height: 0))
    }

    func testDoubleTapTogglesBetweenFitAndZoom() {
        XCTAssertEqual(ArtworkZoomGeometry.scaleAfterDoubleTap(current: 1), ArtworkZoomGeometry.doubleTapScale)
        XCTAssertEqual(ArtworkZoomGeometry.scaleAfterDoubleTap(current: 2.5), ArtworkZoomGeometry.minScale)
        // Anything above the fit scale collapses back, however it got there.
        XCTAssertEqual(ArtworkZoomGeometry.scaleAfterDoubleTap(current: 1.2), ArtworkZoomGeometry.minScale)
    }

    func testSwipeDownDismissesOnlyWhileTheArtworkFitsTheViewport() {
        XCTAssertTrue(ArtworkZoomGeometry.shouldDismiss(verticalDrag: 200, scale: 1))
        XCTAssertFalse(ArtworkZoomGeometry.shouldDismiss(verticalDrag: 20, scale: 1))
        // Zoomed in, a downward drag pans the artwork instead of closing it.
        XCTAssertFalse(ArtworkZoomGeometry.shouldDismiss(verticalDrag: 400, scale: 2))
        // Dragging upwards never dismisses.
        XCTAssertFalse(ArtworkZoomGeometry.shouldDismiss(verticalDrag: -400, scale: 1))
    }
}

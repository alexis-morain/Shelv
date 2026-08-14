import AppKit
import SwiftUI

/// Presents the standard macOS share sheet (`NSSharingServicePicker`) for a URL once
/// it's set, anchored to this view. Unlike `ShareLink`, this lets the URL be produced
/// asynchronously (e.g. after an API call) while still opening on the same click that
/// triggered the fetch, instead of requiring a second click once the item is ready.
private struct SharingServicePickerAnchor: NSViewRepresentable {
    @Binding var url: URL?

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let url else { return }
        DispatchQueue.main.async {
            context.coordinator.show(url: url, relativeTo: nsView)
            self.url = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Holds the picker strongly for its lifetime — `NSSharingServicePicker` doesn't
    /// retain itself, so a bare local variable would let ARC free it right after
    /// `.show()` returns, closing the popover before the user can interact with it.
    final class Coordinator: NSObject, NSSharingServicePickerDelegate {
        private var picker: NSSharingServicePicker?

        func show(url: URL, relativeTo nsView: NSView) {
            let picker = NSSharingServicePicker(items: [url])
            picker.delegate = self
            self.picker = picker
            picker.show(relativeTo: nsView.bounds, of: nsView, preferredEdge: .minY)
        }

        func sharingServicePicker(
            _ sharingServicePicker: NSSharingServicePicker,
            didChoose service: NSSharingService?
        ) {
            sharingServicePicker.delegate = nil
            DispatchQueue.main.async { [weak self] in self?.picker = nil }
        }
    }
}

extension View {
    func sharingServicePicker(url: Binding<URL?>) -> some View {
        background(SharingServicePickerAnchor(url: url))
    }
}

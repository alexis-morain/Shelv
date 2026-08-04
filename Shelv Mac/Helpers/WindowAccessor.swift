import SwiftUI
import AppKit

private struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { callback(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { callback(nsView.window) }
    }
}

private struct HidesTitlebarSeparatorModifier: ViewModifier {
    @State private var hostWindow: NSWindow?

    func body(content: Content) -> some View {
        content
            .background(WindowAccessor { window in
                hostWindow = window
                window?.titlebarSeparatorStyle = .none
            })
            .onDisappear {
                hostWindow?.titlebarSeparatorStyle = .automatic
            }
    }
}

extension View {
    // Detail screens with `.searchable()` keep the native titlebar separator
    // permanently visible instead of the usual scroll-adaptive behavior.
    // Suppress it here; restored to `.automatic` once the view disappears.
    func hidesTitlebarSeparator() -> some View {
        modifier(HidesTitlebarSeparatorModifier())
    }
}

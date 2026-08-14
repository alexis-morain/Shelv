import SwiftUI

/// Wraps a `URL` so it can drive a `.sheet(item:)` presentation.
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// The standard iOS share sheet, used to share a Navidrome share link.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

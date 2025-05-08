import SwiftUI
import AppKit

// A helper view that accesses the underlying NSWindow and sets its delegate.
struct WindowAccessor: NSViewRepresentable {
    // The delegate instance we want to assign.
    var delegate: NSWindowDelegate

    // Creates the underlying NSView (we use a dummy view).
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Set the delegate shortly after the view appears and the window is available.
        DispatchQueue.main.async {
            // Access the window through the view's hierarchy.
            if let window = view.window {
                print("Setting window delegate")
                window.delegate = delegate
            } else {
                print("Warning: Could not find window to set delegate.")
            }
        }
        return view
    }

    // Updates the NSView (not needed for this purpose).
    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-assign the delegate if the view updates, ensuring it stays set.
         DispatchQueue.main.async {
            if nsView.window?.delegate !== delegate { // Check if delegate changed
                 print("Re-setting window delegate on update")
                 nsView.window?.delegate = delegate
            }
         }
    }
}

import SwiftUI
import AppKit // Required for NSWindowDelegate

// This class acts as the delegate for our application window.
class WindowDelegate: NSObject, NSWindowDelegate {
    // A reference to the shared AppState to check for unsaved changes.
    var appState: AppState?

    // This delegate method is called *before* the window closes.
    // We return 'true' to allow the close, 'false' to prevent it.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let appState = appState else {
            // If appState isn't set, allow closing by default.
            return true
        }

        // Check if there's unsaved work.
        if !appState.isWorkSaved && !appState.userText.isEmpty {
            // If unsaved, trigger the quit confirmation dialog via AppState.
            // This dialog will handle the actual quitting or cancelling.
            appState.requestQuitWithUnsavedChanges()
            // Return 'false' *now* to prevent the window from closing immediately.
            // The dialog's actions will handle closing/quitting later if needed.
            return false
        } else {
            // If work is saved (or text is empty), allow the window to close.
            // Since applicationShouldTerminateAfterLastWindowClosed is false,
            // the app won't quit automatically here.
            return true
        }
    }
    
    // Optional: Handle window losing focus if needed
    // func windowDidResignKey(_ notification: Notification) {
    //     print("Window lost key focus")
    // }

    // Optional: Handle window gaining focus
    // func windowDidBecomeKey(_ notification: Notification) {
    //     print("Window gained key focus")
    // }
}

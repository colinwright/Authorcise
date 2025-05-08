import SwiftUI
import AppKit // Required for NSApplicationDelegate

// Create an Application Delegate class
class AppDelegate: NSObject, NSApplicationDelegate {
    // Allow the app to quit automatically when the last window is closed,
    // *unless* our window delegate specifically prevents the close due to unsaved changes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        print("ApplicationDelegate: Allowing termination after last window closed (unless delegate intervenes).")
        return true // Change this back to true
    }
}

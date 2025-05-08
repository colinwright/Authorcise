import SwiftUI
import AppKit // Required for NSWindowController, NSWindow, NSHostingController, NSApplication

// This class is an NSWindowController that hosts the SwiftUI SettingsView.
// It's responsible for creating, showing, and managing the settings window.
class SettingsViewHostingController: NSWindowController {
    // Static property to keep track of the shared settings window.
    // This helps ensure only one settings window is open at a time (singleton pattern).
    private static var sharedSettingsWindow: NSWindow?
    // To properly retain the window controller instance itself.
    private static var activeController: SettingsViewHostingController?


    // Convenience initializer to set up the window with the SwiftUI SettingsView.
    convenience init() {
        let settingsView = SettingsView() // Create an instance of your SwiftUI SettingsView
        let hostingController = NSHostingController(rootView: settingsView) // Host it within an NSHostingController
        
        // Create the window that will contain the hosting controller's view.
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Authorcise Settings" // Set the window title
        // Define an initial size for the window. SettingsView's .frame modifier will ultimately control its content size.
        // This initial size is for the window itself.
        window.setContentSize(NSSize(width: 550, height: 400)) // Match ideal/preview size from SettingsView
        // Optional: Prevent resizing if you want a fixed-size settings window.
        // window.styleMask.remove(.resizable)
        window.center() // Center the window on the screen upon first appearance.
        
        self.init(window: window)
        // Set the window's delegate to self to handle events like window closing.
        // This is important for clearing the sharedSettingsWindow reference and posting notifications.
        self.window?.delegate = self
    }

    // Static function to show the settings window.
    // This is the function that will be called from your app's menu item.
    static func show() {
        // If there's no existing shared settings window or if it's not visible, create a new one.
        if sharedSettingsWindow == nil || !sharedSettingsWindow!.isVisible {
            let windowController = SettingsViewHostingController()
            sharedSettingsWindow = windowController.window
            activeController = windowController // Retain the controller instance
            
            print("SettingsViewHostingController: New settings window created.")
        }
        
        sharedSettingsWindow?.makeKeyAndOrderFront(nil) // Bring the window to the front and make it the key window.
        NSApp.activate(ignoringOtherApps: true) // Ensure the application is active.
        
        // Post notification that the settings window has been opened/shown
        // Ensure Notification.Name.settingsWindowOpened is defined (e.g., in ContentView or a global Notifications file)
        print("SettingsViewHostingController: Posting .settingsWindowOpened notification.")
        NotificationCenter.default.post(name: .settingsWindowOpened, object: nil)
    }
}

// Extend SettingsViewHostingController to conform to NSWindowDelegate.
// This allows us to respond to window events, such as when the window is about to close.
extension SettingsViewHostingController: NSWindowDelegate {
    // This delegate method is called when the window is about to close.
    func windowWillClose(_ notification: Notification) {
        // Check if the window that's closing is indeed our shared settings window.
        if notification.object as? NSWindow == SettingsViewHostingController.sharedSettingsWindow {
            // If it is, clear our static reference to it.
            // This allows a new settings window to be created if the user opens settings again.
            SettingsViewHostingController.sharedSettingsWindow = nil
            SettingsViewHostingController.activeController = nil // Release the controller instance
            print("SettingsViewHostingController: Settings window closed and shared references cleared.")
            
            // Post notification that the settings window has been closed
            // Ensure Notification.Name.settingsWindowClosed is defined (though not actively used by ContentView currently)
            print("SettingsViewHostingController: Posting .settingsWindowClosed notification.")
            NotificationCenter.default.post(name: .settingsWindowClosed, object: nil)
        }
    }

    // The following delegate methods could also be used to post notifications
    // if you need more fine-grained control (e.g., pausing timer when window loses focus,
    // not just when it's explicitly shown via the menu).

    // func windowDidBecomeKey(_ notification: Notification) {
    //     if notification.object as? NSWindow == SettingsViewHostingController.sharedSettingsWindow {
    //         print("SettingsViewHostingController: Window became key, posting .settingsWindowOpened.")
    //         NotificationCenter.default.post(name: .settingsWindowOpened, object: nil)
    //     }
    // }

    // func windowDidResignKey(_ notification: Notification) {
    //     if notification.object as? NSWindow == SettingsViewHostingController.sharedSettingsWindow {
    //         print("SettingsViewHostingController: Window resigned key, posting .settingsWindowClosed.")
    //         NotificationCenter.default.post(name: .settingsWindowClosed, object: nil)
    //     }
    // }
}

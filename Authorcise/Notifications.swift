import Foundation

// This file centralizes custom Notification.Name definitions for the Authorcise app.
// Using a unique reverse domain style string for your app helps avoid naming collisions.
// Replace "com.yourcompany.authorcise" with your actual bundle identifier or a unique string.
// For example, if your bundle ID is "com.colinwright.Authorcise", you can use that.

extension Notification.Name {
    /// Posted when the settings window has been opened or brought to the front.
    /// Observers can listen for this to react, e.g., pause ongoing activities.
    static let settingsWindowOpened = Notification.Name("com.colinwright.Authorcise.settingsWindowOpened")

    /// Posted when the settings window is about to close.
    /// Observers can listen for this if they need to perform cleanup or react to the window closing.
    static let settingsWindowClosed = Notification.Name("com.colinwright.Authorcise.settingsWindowClosed")

    // Add any other custom app-wide notifications here in the future.
    // For example:
    // static let writingSessionStarted = Notification.Name("com.colinwright.Authorcise.writingSessionStarted")
    // static let writingSessionEnded = Notification.Name("com.colinwright.Authorcise.writingSessionEnded")
}

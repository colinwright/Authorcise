import SwiftUI

// Ensure other necessary files like AppState, SettingsViewHostingController,
// ContentView, AppDelegate, etc., are correctly defined in your project.

@main
struct AuthorciseApp: App {
    // Connect to the App Delegate defined in AppDelegate.swift
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("isDarkModeEnabled") var isDarkModeEnabled: Bool = false
    // Create the shared state object for the entire app
    @StateObject private var appState = AppState() // Ensure AppState.swift is in your project

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the state object into the environment so ContentView can access it
                .environmentObject(appState)
                .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 750, height: 850)
        .commands {
            // Add "Settings..." to the main application menu.
            // Using CommandGroup(after: .appInfo) places it after the "About Authorcise" item.
            // This is a common placement for settings/preferences.
            CommandGroup(after: .appInfo) {
                Button("Settings...") {
                    // Action to open the settings window
                    // Ensure SettingsViewHostingController.swift is in your project and its show() method is accessible
                    SettingsViewHostingController.show()
                }
                .keyboardShortcut(",", modifiers: .command) // Standard macOS shortcut for Preferences/Settings
            }

            // Your existing command to replace the standard Quit command
            CommandGroup(replacing: .appTermination) {
                Button("Quit Authorcise") {
                    // Check app state for unsaved work before deciding how to quit
                    if !appState.isWorkSaved && !appState.userText.isEmpty {
                        // Trigger the confirmation dialog via AppState
                        appState.requestQuitWithUnsavedChanges()
                    } else {
                        // No unsaved work, terminate immediately
                        print("Quitting directly (no unsaved changes).")
                        NSApplication.shared.terminate(nil)
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

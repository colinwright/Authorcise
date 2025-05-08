import SwiftUI

// Note: The 'AppDelegate' class definition should be in its own file (AppDelegate.swift),
// NOT here in AuthorciseApp.swift.

@main
struct AuthorciseApp: App {
    // Connect to the App Delegate defined in AppDelegate.swift
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("isDarkModeEnabled") var isDarkModeEnabled: Bool = false
    // Create the shared state object for the entire app
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the state object into the environment so ContentView can access it
                .environmentObject(appState)
                .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 750, height: 850)
        // Add custom commands to override default behaviors
        .commands {
            // Replace the standard Quit command
            CommandGroup(replacing: .appTermination) {
                Button("Quit Authorcise") {
                    // Check app state for unsaved work before deciding how to quit
                    // Use the userText from appState now
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

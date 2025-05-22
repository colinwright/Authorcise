import SwiftUI

// Ensure other necessary files like AppState, SettingsViewHostingController,
// ContentView, AppDelegate, AboutView etc., are correctly defined in your project.

@main
struct AuthorciseApp: App {
    // Connect to the App Delegate defined in AppDelegate.swift
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("isDarkModeEnabled") var isDarkModeEnabled: Bool = false
    // Create the shared state object for the entire app
    @StateObject private var appState = AppState() // Ensure AppState.swift is in your project

    // Environment value to open a new window
    @Environment(\.openWindow) private var openWindow

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
            // CommandGroup for "About Authorcise"
            // This replaces the default "About" menu item.
            CommandGroup(replacing: .appInfo) {
                Button("About Authorcise") {
                    // Action to open the custom About window
                    openWindow(id: "about-authorcise")
                }
            }

            // CommandGroup for "Settings..."
            // Using .appSettings placement for the settings/preferences item.
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsViewHostingController.show()
                }
                .keyboardShortcut(",", modifiers: .command) // Standard shortcut for Preferences/Settings
            }
            
            // CommandGroup for the Divider, placed after the .appSettings group.
            // This should insert a divider before the "Services" menu.
            CommandGroup(after: .appSettings) {
                Divider()
            }

            // Your existing command to replace the standard Quit command
            CommandGroup(replacing: .appTermination) {
                Button("Quit Authorcise") {
                    if !appState.isWorkSaved && !appState.userText.isEmpty {
                        appState.requestQuitWithUnsavedChanges()
                    } else {
                        print("Quitting directly (no unsaved changes).")
                        NSApplication.shared.terminate(nil)
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }

        // Define the custom "About" window scene
        Window("About Authorcise", id: "about-authorcise") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultSize(width: 400, height: 560)
    }
}

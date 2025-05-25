import SwiftUI

// Ensure other necessary files like AppState, SettingsViewHostingController,
// ContentView, AppDelegate, AboutView etc., are correctly defined in your project.

@main
struct AuthorciseApp: App {
    // Connect to the App Delegate defined in AppDelegate.swift
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // AppStorage for dark mode preference
    @AppStorage("isDarkModeEnabled") var isDarkModeEnabled: Bool = false
    
    // Create the shared state object for the entire app
    @StateObject private var appState = AppState() // Ensure AppState.swift is in your project

    // Environment value to open a new window (used for "About" window)
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the state object into the environment so ContentView and its children can access it
                .environmentObject(appState)
                .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        }
        .windowStyle(.hiddenTitleBar) // Keeps the custom window style
        .defaultSize(width: 750, height: 850) // Default window size
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
                    SettingsViewHostingController.show() // Shows the settings window
                }
                .keyboardShortcut(",", modifiers: .command) // Standard shortcut for Preferences/Settings
            }
            
            // CommandGroup for the Divider, placed after the .appSettings group.
            // This should insert a divider before the "Services" menu.
            CommandGroup(after: .appSettings) {
                Divider()
            }

            // Custom Quit command
            // This replaces the standard Quit command to allow for unsaved changes check.
            CommandGroup(replacing: .appTermination) {
                Button("Quit Authorcise") {
                    // Check for unsaved changes before quitting.
                    // AppState.userText is the source of truth for current text.
                    // AppState.isWorkSaved indicates if that text has been saved.
                    if !appState.isWorkSaved && !appState.userText.isEmpty {
                        // If there's unsaved text, request confirmation via AppState.
                        appState.requestQuitWithUnsavedChanges()
                    } else {
                        // If no unsaved changes (or text is empty), quit directly.
                        print("AuthorciseApp: Quitting directly (no unsaved changes or text is empty).")
                        NSApplication.shared.terminate(nil)
                    }
                }
                .keyboardShortcut("q", modifiers: .command) // Standard quit shortcut
            }
        }

        // Define the custom "About" window scene
        Window("About Authorcise", id: "about-authorcise") {
            AboutView()
        }
        .windowResizability(.contentSize) // Allow window to resize based on AboutView content
        .defaultPosition(.center) // Center the About window
        .defaultSize(width: 400, height: 560) // Default size for About window
    }
}

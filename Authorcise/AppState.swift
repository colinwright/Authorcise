import SwiftUI
import Combine
import AppKit // Required for NSApplication.shared.terminate

// Observable class to hold shared application state
class AppState: ObservableObject {

    // Static flag to hold the current session state, accessible by SettingsView
    // This flag is updated by ContentView when a session starts or stops.
    static var isCurrentSessionActive: Bool = false

    // Published properties will trigger view updates when changed
    @Published var userText: String = "" {
        didSet {
            // Mark work as unsaved whenever text changes, unless it becomes empty
            if !userText.isEmpty {
                isWorkSaved = false
            } else {
                // If text becomes empty, consider it "saved" or nothing to save.
                isWorkSaved = true
            }
        }
    }

    // Tracks if the current userText matches the last successfully appended state
    // or if userText is empty.
    @Published var isWorkSaved: Bool = true

    // Flag to trigger the quit confirmation dialog in ContentView
    @Published var showQuitConfirmation: Bool = false
    
    // Stores the current prompt word, to be passed to the save function
    @Published var currentPromptForSaving: String = "Unknown"
    
    // To notify ContentView if Mandala Mode prevents a save, so it can show a message.
    @Published var mandalaModeSaveAttemptMessage: String? = nil


    // Marks the current work as saved (e.g., after a successful append operation)
    func workSuccessfullySaved() {
        isWorkSaved = true
    }

    // Called when user attempts to quit with unsaved changes
    func requestQuitWithUnsavedChanges() {
        showQuitConfirmation = true
    }

    // Called when user clicks "Save and Quit" in the confirmation dialog
    func handleSaveAndQuit() {
        // Check if Mandala Mode is active
        let mandalaModeActive = UserDefaults.standard.bool(forKey: UserDefaultKeys.mandalaModeEnabled)
        if mandalaModeActive {
            print("AppState: Mandala Mode is active. Save and Quit will not save. Quitting directly.")
            NSApplication.shared.terminate(nil)
            return
        }

        guard !userText.isEmpty else {
            print("AppState: No text to save. Quitting directly.")
            NSApplication.shared.terminate(nil)
            return
        }

        print("AppState: Attempting to save (append) to Writing Journal and quit.")
        appendToWritingJournal(text: self.userText, currentPrompt: self.currentPromptForSaving) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let path):
                    print("AppState: Save successful to \(path) before quitting. Quitting now.")
                    self.workSuccessfullySaved()
                    NSApplication.shared.terminate(nil)
                case .failure(let error):
                    print("AppState: Save failed during quit attempt: \(error.localizedDescription).")
                    // Error handling: Keep dialog open or show an error.
                    // For simplicity, we don't quit and rely on ContentView to manage the UI.
                }
            }
        }
    }

    // Cancels the quit process initiated via the dialog
    func cancelQuitAttempt() {
        showQuitConfirmation = false
    }
}

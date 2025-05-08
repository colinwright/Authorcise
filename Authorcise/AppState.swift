import SwiftUI
import Combine
import AppKit // Required for NSApplication.shared.terminate

// Observable class to hold shared application state
class AppState: ObservableObject {
    
    // Published properties will trigger view updates when changed
    
    // Holds the user's current writing text
    @Published var userText: String = "" {
        didSet {
            // Mark work as unsaved whenever text changes, unless it becomes empty
            if !userText.isEmpty {
                isWorkSaved = false
            } else {
                isWorkSaved = true // Empty text is considered "saved" or nothing to save
            }
        }
    }
    
    // Tracks if the current userText matches the last saved state
    @Published var isWorkSaved: Bool = true
    
    // Controls the visibility of the file save panel (.fileExporter)
    @Published var showFileExporter: Bool = false
    
    // Holds the document content prepared for saving (used by .fileExporter)
    @Published var documentToSave: TextFile = TextFile() // Ensure TextFile.swift is in your project
    
    // Flag to trigger the quit confirmation dialog in ContentView
    @Published var showQuitConfirmation: Bool = false
    
    // Flag to track if the save operation was initiated from the quit dialog
    @Published var isQuittingAfterSave: Bool = false

    // Helper function to generate filename based on settings (used for auto-save on quit)
    // Mirrors logic from ContentView but uses a generic placeholder instead of the current prompt.
    private func generateQuitSaveFileName() -> String {
        // Read preferences from UserDefaults
        let defaults = UserDefaults.standard
        let useDefaultStructure = defaults.object(forKey: UserDefaultKeys.filenameUseDefaultStructure) as? Bool ?? true
        
        var nameParts: [String] = []
        let now = Date()
        let safePromptPlaceholder = "QuitSave" // Use a generic placeholder for quit saves

        if useDefaultStructure {
            // Use the fixed default structure: Authorcise_QuitSave_DateTime
            let defaultFormatter = DateFormatter()
            defaultFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            nameParts.append("Authorcise")
            nameParts.append(safePromptPlaceholder)
            nameParts.append(defaultFormatter.string(from: now))
        } else {
            // Use custom structure based on stored order and toggles
            
            // Load component order (provide default if loading fails)
            let componentOrder: [FilenameComponent]
            if let data = defaults.data(forKey: UserDefaultKeys.filenameComponentOrder),
               let decodedOrder = try? JSONDecoder().decode([FilenameComponent].self, from: data) {
                componentOrder = decodedOrder
            } else {
                componentOrder = FilenameComponent.allCases // Default order
            }

            // Load inclusion toggles and custom prefix string
            let includePrefix = defaults.object(forKey: UserDefaultKeys.filenameIncludeAuthorcisePrefix) as? Bool ?? true
            // let includePrompt = defaults.object(forKey: UserDefaultKeys.filenameIncludePrompt) as? Bool ?? true // Not using prompt for quit-save
            let includeDate = defaults.object(forKey: UserDefaultKeys.filenameIncludeDate) as? Bool ?? true
            let includeTime = defaults.object(forKey: UserDefaultKeys.filenameIncludeTime) as? Bool ?? true
            let includeCustomPrefix = defaults.object(forKey: UserDefaultKeys.filenameIncludeCustomPrefix) as? Bool ?? false
            let customPrefixString = defaults.string(forKey: UserDefaultKeys.filenameCustomPrefixString) ?? ""
            
            // Sanitize custom prefix
            let safeCustomPrefix = customPrefixString
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)

            // Prepare date/time string based on toggles (only if needed)
            var dateTimeString = ""
            if includeDate || includeTime {
                 let formatter = DateFormatter()
                 if includeDate && includeTime {
                     formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                 } else if includeDate {
                     formatter.dateFormat = "yyyy-MM-dd"
                 } else { // Only includeTime
                     formatter.dateFormat = "HH-mm-ss"
                 }
                 dateTimeString = formatter.string(from: now)
            }
            
            // Iterate through the stored order and append parts if included
            for component in componentOrder {
                switch component {
                case .authorcisePrefix:
                    if includePrefix { nameParts.append("Authorcise") }
                case .customPrefix:
                    if includeCustomPrefix && !safeCustomPrefix.isEmpty { nameParts.append(safeCustomPrefix) }
                case .prompt:
                     // Intentionally skip prompt for quit-save filename
                     break
                case .date, .time:
                    // Add the combined date/time string only once, when the first relevant component appears
                    if !dateTimeString.isEmpty && !nameParts.contains(dateTimeString) {
                         if (component == .date && includeDate) || (component == .time && includeTime) {
                              nameParts.append(dateTimeString)
                         }
                    }
                }
            }
        }
        
        // Join the parts, ensuring no leading/trailing underscores if parts are missing
        let baseName = nameParts.filter { !$0.isEmpty }.joined(separator: "_")
        
        // Ensure a base name exists even if all components are off
        // Return filename WITHOUT extension
        return (baseName.isEmpty ? "Authorcise_QuitSave" : baseName)
    }


    // Prepares the document object with the current text for saving via .fileExporter
    func prepareDocumentForSave() {
        documentToSave = TextFile(initialText: userText)
    }
    
    // Marks the current work as saved (e.g., after a successful save operation)
    func workSaved() {
        isWorkSaved = true
    }

    // Called when user attempts to quit with unsaved changes (e.g., from WindowDelegate or app menu quit)
    func requestQuitWithUnsavedChanges() {
        isWorkSaved = false
        isQuittingAfterSave = true
        showQuitConfirmation = true
    }

    // Called when user clicks "Save and Quit" in the confirmation dialog
    func handleSaveAndQuit() {
        self.isQuittingAfterSave = true

        let shouldAlwaysShowPrompt = UserDefaults.standard.object(forKey: UserDefaultKeys.alwaysShowSavePrompt) as? Bool ?? true
        let defaultDirectoryIsAvailable = getSavedDownloadDirectoryURL(startAccessing: false) != nil

        if !shouldAlwaysShowPrompt && defaultDirectoryIsAvailable {
            // Auto-save then quit:
            print("AppState: Attempting auto-save and quit.")
            
            // Generate filename based on settings using the updated helper function
            let filenameWithoutExtension = generateQuitSaveFileName()
            
            // Call the global save function
            saveTextFile(content: self.userText, preferredFileName: filenameWithoutExtension) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let path):
                        print("AppState: Auto-save successful to \(path). Quitting.")
                        self.workSaved()
                        NSApplication.shared.terminate(nil)
                    case .failure(let error):
                        print("AppState: Auto-save failed: \(error.localizedDescription). Cancelling quit.")
                        self.cancelQuitAfterSaveAttempt()
                        // TODO: Optionally show error alert to the user from ContentView
                    }
                }
            }
        } else {
            // Show save panel via .fileExporter then quit:
            print("AppState: Showing save panel via .fileExporter for save and quit.")
            self.prepareDocumentForSave()
            self.showFileExporter = true
            // ContentView's .fileExporter completion handles quitting
        }
    }

    // Cancels the quit process initiated via the dialog (e.g., user clicks "Cancel", or save fails)
    func cancelQuitAfterSaveAttempt() {
        isQuittingAfterSave = false
        showQuitConfirmation = false
    }
}

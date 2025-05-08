import SwiftUI
import Combine

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
    
    // Holds the document content prepared for saving
    @Published var documentToSave: TextFile = TextFile()
    
    // Flag to trigger the quit confirmation dialog in ContentView
    @Published var showQuitConfirmation: Bool = false
    
    // Flag to track if the save operation was initiated from the quit dialog
    @Published var isQuittingAfterSave: Bool = false

    // Prepares the document object with the current text for saving
    func prepareDocumentForSave() {
         documentToSave = TextFile(initialText: userText)
    }
    
    // Marks the current work as saved (e.g., after a successful save operation)
    func workSaved() {
        isWorkSaved = true
        isQuittingAfterSave = false // Reset quit flag after successful save
    }

    // Marks that work needs saving and triggers the quit confirmation process
    func requestQuitWithUnsavedChanges() {
        isWorkSaved = false // Ensure it's marked unsaved
        isQuittingAfterSave = true // Set flag indicating quit intent
        showQuitConfirmation = true // Trigger the dialog in the view
    }

    // Cancels the quit process initiated via the dialog
    func cancelQuitAfterSaveAttempt() {
        isQuittingAfterSave = false
        showQuitConfirmation = false // Hide dialog if still showing
    }
}

// Notification Name for Quit Request (Optional alternative, but we use AppState flag now)
// extension Notification.Name {
//     static let requestQuitConfirmation = Notification.Name("requestQuitConfirmation")
// }

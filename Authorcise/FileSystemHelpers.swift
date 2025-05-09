import SwiftUI
import AppKit
import UniformTypeIdentifiers // Required for UTType

// It's good practice to define your UserDefaults keys in one place.
enum UserDefaultKeys {
    // Directory and Save Prompt keys
    static let defaultDownloadDirectoryBookmark = "defaultDownloadDirectoryBookmark"
    static let alwaysShowSavePrompt = "alwaysShowSavePrompt"

    // --- Add this new key for Typewriter Mode ---
    static let typewriterModeEnabled = "typewriterModeEnabled"
    // --------------------------------------------

    // Keys for filename structure components
    static let filenameUseDefaultStructure = "filenameUseDefaultStructure"
    static let filenameIncludeAuthorcisePrefix = "filenameIncludeAuthorcisePrefix"
    static let filenameIncludePrompt = "filenameIncludePrompt"
    static let filenameIncludeDate = "filenameIncludeDate"
    static let filenameIncludeTime = "filenameIncludeTime"
    static let filenameIncludeCustomPrefix = "filenameIncludeCustomPrefix"
    static let filenameCustomPrefixString = "filenameCustomPrefixString"

    // New key for storing the component order
    static let filenameComponentOrder = "filenameComponentOrder"
}

// MARK: - File System Helper Functions

// Resolves a security-scoped bookmark and optionally starts access.
func resolveBookmark(_ bookmarkData: Data, startAccessing: Bool = true) -> URL? {
    var isStale = false
    do {
        let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

        if isStale {
            print("FileSystemHelpers: Bookmark for \(url.path) is stale.")
        }

        if startAccessing {
            if !url.startAccessingSecurityScopedResource() {
                print("FileSystemHelpers: ERROR - Failed to start accessing security-scoped resource for URL: \(url.path).")
                return nil
            }
            print("FileSystemHelpers: Successfully started accessing security-scoped resource: \(url.path)")
        }
        return url
    } catch {
        print("FileSystemHelpers: ERROR resolving bookmark: \(error.localizedDescription)")
        return nil
    }
}

// Retrieves the saved download directory URL from UserDefaults (using the bookmark data).
func getSavedDownloadDirectoryURL(startAccessing: Bool = true) -> URL? {
    guard let bookmarkData = UserDefaults.standard.data(forKey: UserDefaultKeys.defaultDownloadDirectoryBookmark) else {
        print("FileSystemHelpers: No default download directory bookmark found.")
        return nil
    }
    return resolveBookmark(bookmarkData, startAccessing: startAccessing)
}

// Saves text content to a file.
// It respects the user's preference for showing a save prompt or auto-saving.
// The filename construction logic (including order) now resides in the calling functions (ContentView, AppState).
func saveTextFile(content: String, preferredFileName: String, completion: @escaping (Result<String, Error>) -> Void) {
    // Get user's preference for showing save prompt.
    let shouldAlwaysShowPrompt = UserDefaults.standard.object(forKey: UserDefaultKeys.alwaysShowSavePrompt) as? Bool ?? true

    // Try to get the saved default download directory URL.
    let directoryURL = getSavedDownloadDirectoryURL(startAccessing: true)

    // Determine if we should show the save panel or attempt direct save.
    if shouldAlwaysShowPrompt || directoryURL == nil {
        // Show NSSavePanel
        print("FileSystemHelpers: Showing NSSavePanel (alwaysShowPrompt: \(shouldAlwaysShowPrompt), directoryURL isNil: \(directoryURL == nil)).")
        let savePanel = NSSavePanel()
        savePanel.title = "Save Your Writing As..."
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [UTType.plainText]
        } else {
            savePanel.allowedFileTypes = ["txt"] // Fallback
        }

        // Use the filename passed into this function (which should be pre-constructed without extension)
        let panelFileName = preferredFileName // Assume extension is handled by appendingPathComponent or savePanel
        savePanel.nameFieldStringValue = panelFileName + ".txt" // Add extension for display in panel
        savePanel.canCreateDirectories = true

        // Set initial directory for the save panel if a default is chosen and accessible.
        if let unwrappedDirectoryURL = directoryURL {
            savePanel.directoryURL = unwrappedDirectoryURL
        }

        DispatchQueue.main.async {
            savePanel.begin { result in
                var savedToDefaultDirViaPanel = false
                if result == .OK, let savedURL = savePanel.url {
                    do {
                        // Ensure the saved URL has the correct extension (NSSavePanel usually handles this, but double-check)
                        let finalURL = savedURL.pathExtension.lowercased() == "txt" ? savedURL : savedURL.appendingPathExtension("txt")
                        try content.write(to: finalURL, atomically: true, encoding: .utf8)
                        print("FileSystemHelpers: File saved via NSSavePanel to: \(finalURL.path)")
                        if let defaultDir = directoryURL, finalURL.deletingLastPathComponent() == defaultDir {
                            savedToDefaultDirViaPanel = true
                        }
                        completion(.success(finalURL.path))
                    } catch {
                        print("FileSystemHelpers: ERROR saving file via NSSavePanel: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                } else {
                    print("FileSystemHelpers: User cancelled NSSavePanel or an error occurred.")
                    let cancelError = NSError(domain: "AuthorciseApp.SaveOperation", code: NSUserCancelledError, userInfo: [NSLocalizedDescriptionKey: "Save operation cancelled by user."])
                    completion(.failure(cancelError))
                }

                // Stop access if needed
                if let unwrappedDirectoryURL = directoryURL, !savedToDefaultDirViaPanel {
                    unwrappedDirectoryURL.stopAccessingSecurityScopedResource()
                    print("FileSystemHelpers: Stopped accessing default directory resource after NSSavePanel (not saved there or cancelled).")
                }
            }
        }
    } else if let unwrappedDirectoryURL = directoryURL {
        // Auto-save to default directory
        print("FileSystemHelpers: Attempting auto-save to default directory: \(unwrappedDirectoryURL.path)")
        // Use the filename passed into this function (which should be pre-constructed without extension)
        let fileURL = unwrappedDirectoryURL.appendingPathComponent(preferredFileName).appendingPathExtension("txt")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("FileSystemHelpers: File auto-saved to default directory: \(fileURL.path)")
            unwrappedDirectoryURL.stopAccessingSecurityScopedResource()
            print("FileSystemHelpers: Stopped accessing security-scoped resource for: \(unwrappedDirectoryURL.path)")
            completion(.success(fileURL.path))
        } catch {
            print("FileSystemHelpers: ERROR auto-saving file to default directory: \(error.localizedDescription)")
            unwrappedDirectoryURL.stopAccessingSecurityScopedResource()
            print("FileSystemHelpers: Stopped accessing security-scoped resource for (on error): \(unwrappedDirectoryURL.path)")
            completion(.failure(error))
        }
    }
}

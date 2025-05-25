import SwiftUI
import AppKit
import UniformTypeIdentifiers // Required for UTType

// MARK: - File System Helper Functions

// Resolves a security-scoped bookmark and optionally starts access.
func resolveBookmark(_ bookmarkData: Data, startAccessing: Bool = true) -> URL? {
    var isStale = false
    do {
        let url = try URL(resolvingBookmarkData: bookmarkData,
                          options: .withSecurityScope,
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale)

        if isStale {
            print("FileSystemHelpers: Bookmark for \(url.path) is stale. Re-selection might be needed.")
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


// Retrieves the URL for the Writing Journal file from UserDefaults.
func getWritingJournalURL(startAccessing: Bool = true) -> URL? {
    // Using the existing key UserDefaultKeys.masterSaveFileBookmark for compatibility
    guard let bookmarkData = UserDefaults.standard.data(forKey: UserDefaultKeys.masterSaveFileBookmark) else {
        print("FileSystemHelpers: No Writing Journal bookmark found in UserDefaults.")
        return nil
    }
    return resolveBookmark(bookmarkData, startAccessing: startAccessing)
}

// Formats the entry to be appended to the Writing Journal.
private func formatEntry(text: String, prompt: String) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let timestamp = dateFormatter.string(from: Date())

    let header = "--- Entry: \(timestamp) | Prompt: \(prompt) ---"
    // Single space after header, then the text on a new line.
    // Two newlines before the header for separation from previous entry.
    return "\n\n\(header) \n\(text)\n"
}

// Appends the given text as a new entry to the Writing Journal.
// If no journal file is set, it will prompt the user to select or create one.
func appendToWritingJournal(text: String, currentPrompt: String, completion: @escaping (Result<String, Error>) -> Void) {
    if let journalURL = getWritingJournalURL(startAccessing: true) {
        guard journalURL.isFileURL else {
            print("FileSystemHelpers: Writing Journal URL is not a file URL: \(journalURL)")
            journalURL.stopAccessingSecurityScopedResource()
            completion(.failure(NSError(domain: "AuthorciseApp.SaveOperation", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Writing Journal path."])))
            return
        }

        do {
            let entry = formatEntry(text: text, prompt: currentPrompt)
            guard let data = entry.data(using: .utf8) else {
                journalURL.stopAccessingSecurityScopedResource()
                completion(.failure(NSError(domain: "AuthorciseApp.SaveOperation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode text to UTF-8."])))
                return
            }

            if FileManager.default.fileExists(atPath: journalURL.path) {
                let fileHandle = try FileHandle(forWritingTo: journalURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try fileHandle.close()
                print("FileSystemHelpers: Successfully appended to Writing Journal: \(journalURL.path)")
            } else {
                try data.write(to: journalURL, options: .atomic)
                print("FileSystemHelpers: Successfully created and wrote initial entry to Writing Journal: \(journalURL.path)")
            }

            journalURL.stopAccessingSecurityScopedResource()
            completion(.success(journalURL.path))
        } catch {
            print("FileSystemHelpers: ERROR writing/appending to Writing Journal '\(journalURL.path)': \(error.localizedDescription)")
            journalURL.stopAccessingSecurityScopedResource()
            completion(.failure(error))
        }
    } else {
        print("FileSystemHelpers: Writing Journal not set or bookmark invalid. Prompting user.")
        promptForWritingJournalSelectionAndSave(text: text, currentPrompt: currentPrompt, completion: completion)
    }
}


// Prompts the user to select or create a Writing Journal .txt file, saves the bookmark,
// and then attempts to append the entry.
func promptForWritingJournalSelectionAndSave(text: String, currentPrompt: String, completion: @escaping (Result<String, Error>) -> Void) {
    DispatchQueue.main.async {
        let savePanel = NSSavePanel()
        savePanel.title = "Set Writing Journal File"
        savePanel.message = "Choose or create a .txt file where all your writings will be saved. New entries will be appended."
        savePanel.prompt = "Set Journal File"
        
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [UTType.plainText]
        } else {
            savePanel.allowedFileTypes = ["txt"]
        }
        
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Writing_Journal.txt" // Updated default name

        savePanel.begin { result in
            if result == .OK, let chosenURL = savePanel.url {
                do {
                    // Ensure file exists before creating bookmark (NSSavePanel should handle creation if new)
                    if !FileManager.default.fileExists(atPath: chosenURL.path) {
                         print("FileSystemHelpers: Writing Journal will be created at \(chosenURL.path) by NSSavePanel or first write.")
                         // Attempt to create an empty file if savePanel doesn't guarantee it,
                         // though for NSSavePanel, this step might be redundant if it always creates.
                         // However, explicit creation ensures it exists for bookmarking.
                        try "".write(to: chosenURL, atomically: true, encoding: .utf8)
                        print("FileSystemHelpers: Ensured empty Writing Journal exists for bookmarking.")
                    }

                    let bookmarkData = try chosenURL.bookmarkData(options: .withSecurityScope,
                                                                  includingResourceValuesForKeys: nil,
                                                                  relativeTo: nil)
                    // Using existing key UserDefaultKeys.masterSaveFileBookmark for compatibility
                    UserDefaults.standard.set(bookmarkData, forKey: UserDefaultKeys.masterSaveFileBookmark)
                    print("FileSystemHelpers: Writing Journal bookmark saved via prompt: \(chosenURL.path)")

                    appendToWritingJournal(text: text, currentPrompt: currentPrompt, completion: completion)

                } catch {
                    print("FileSystemHelpers: ERROR creating bookmark or ensuring file during prompt: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            } else {
                print("FileSystemHelpers: User cancelled Writing Journal selection prompt.")
                let cancelError = NSError(domain: "AuthorciseApp.SaveOperation", code: NSUserCancelledError, userInfo: [NSLocalizedDescriptionKey: "Writing Journal selection cancelled by user."])
                completion(.failure(cancelError))
            }
        }
    }
}

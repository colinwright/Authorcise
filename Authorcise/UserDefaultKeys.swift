import SwiftUI
import AppKit
import UniformTypeIdentifiers // Required for UTType

// It's good practice to define your UserDefaults keys in one place.
enum UserDefaultKeys {
    // --- Key for the Writing Journal File ---
    static let masterSaveFileBookmark = "masterSaveFileBookmark" // Will be renamed to writingJournalBookmark in next step if desired for clarity, but key itself can remain for compatibility.
                                                                 // For now, keeping as masterSaveFileBookmark to avoid breaking existing saved settings immediately.

    // --- Typewriter Mode Key ---
    static let typewriterModeEnabled = "typewriterModeEnabled"

    // --- Mandala Mode Key ---
    static let mandalaModeEnabled = "mandalaModeEnabled"

    // --- Old Filename Structure Keys (Likely Obsolete - Review for removal) ---
    // static let filenameUseDefaultStructure = "filenameUseDefaultStructure"
    // static let filenameIncludeAuthorcisePrefix = "filenameIncludeAuthorcisePrefix"
    // static let filenameIncludePrompt = "filenameIncludePrompt"
    // static let filenameIncludeDate = "filenameIncludeDate"
    // static let filenameIncludeTime = "filenameIncludeTime"
    // static let filenameIncludeCustomPrefix = "filenameIncludeCustomPrefix"
    // static let filenameCustomPrefixString = "filenameCustomPrefixString"
    // static let filenameComponentOrder = "filenameComponentOrder"
}

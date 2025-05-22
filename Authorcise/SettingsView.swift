import SwiftUI
import AppKit // Required for NSOpenPanel

// Define the components that can make up a filename
enum FilenameComponent: String, Codable, CaseIterable, Identifiable, Hashable {
    case authorcisePrefix = "Authorcise Prefix"
    case customPrefix = "Custom Prefix"
    case prompt = "Prompt Word"
    case date = "Date"
    case time = "Time"

    var id: String { self.rawValue }
}

// This is the SwiftUI View for the Settings panel.
struct SettingsView: View {
    // Environment variable to detect color scheme
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Directory Settings State
    @State private var selectedDirectoryDisplayPath: String = "No directory selected"
    @AppStorage(UserDefaultKeys.defaultDownloadDirectoryBookmark) var defaultDownloadDirectoryBookmarkData: Data?

    // MARK: - Save Behavior State
    @AppStorage(UserDefaultKeys.alwaysShowSavePrompt) var alwaysShowSavePrompt: Bool = true

    // MARK: - Filename Structure State
    @AppStorage(UserDefaultKeys.filenameUseDefaultStructure) var filenameUseDefaultStructure: Bool = true
    // --- Inclusion Toggles (still needed) ---
    @AppStorage(UserDefaultKeys.filenameIncludeAuthorcisePrefix) var filenameIncludeAuthorcisePrefix: Bool = true
    @AppStorage(UserDefaultKeys.filenameIncludePrompt) var filenameIncludePrompt: Bool = true
    @AppStorage(UserDefaultKeys.filenameIncludeDate) var filenameIncludeDate: Bool = true
    @AppStorage(UserDefaultKeys.filenameIncludeTime) var filenameIncludeTime: Bool = true
    @AppStorage(UserDefaultKeys.filenameIncludeCustomPrefix) var filenameIncludeCustomPrefix: Bool = false
    @AppStorage(UserDefaultKeys.filenameCustomPrefixString) var filenameCustomPrefixString: String = ""

    // --- Order State ---
    @State private var componentOrder: [FilenameComponent] = []

    // --- Preview State ---
    @State private var samplePromptForPreview: String = "promptword"

    // Define background color based on system appearance
    private var appBackgroundColor: Color {
        colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color(NSColor.textBackgroundColor)
    }

    // Date formatter for filename preview
    private func previewDateFormatter(includeDate: Bool, includeTime: Bool) -> DateFormatter {
        let formatter = DateFormatter()
        if includeDate && includeTime {
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        } else if includeDate {
            formatter.dateFormat = "yyyy-MM-dd"
        } else if includeTime {
            formatter.dateFormat = "HH-mm-ss"
        } else {
            formatter.dateFormat = ""
        }
        return formatter
    }

    // Computed property for filename preview - respects order and inclusion
    private var filenamePreview: String {
        var nameParts: [String] = []
        let now = Date()

        // Determine effective settings based on default toggle
        let useDefault = filenameUseDefaultStructure

        // Get current inclusion states from AppStorage or default
        let includePrefix = useDefault || filenameIncludeAuthorcisePrefix
        let includePrompt = useDefault || filenameIncludePrompt
        let includeDate = useDefault || filenameIncludeDate
        let includeTime = useDefault || filenameIncludeTime
        let includeCustom = !useDefault && filenameIncludeCustomPrefix

        // Get custom prefix string and sanitize
        let customPrefix = filenameCustomPrefixString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)

        // Get safe prompt string
        let safeSamplePrompt = samplePromptForPreview.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
        let finalSamplePrompt = safeSamplePrompt.isEmpty ? "Writing" : safeSamplePrompt

        // Prepare date and time strings separately based on toggles
        let dateFormatter = DateFormatter()
        var dateString = ""
        if includeDate {
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateString = dateFormatter.string(from: now)
        }

        let timeFormatter = DateFormatter()
        var timeString = ""
        if includeTime {
            timeFormatter.dateFormat = "HH-mm-ss"
            timeString = timeFormatter.string(from: now)
        }

        // Build name parts based on the ORDER stored in componentOrder
        for component in componentOrder {
            switch component {
            case .authorcisePrefix:
                if includePrefix { nameParts.append("Authorcise") }
            case .customPrefix:
                // Add custom prefix only if custom mode is active, toggle is on, and string is not empty
                if !useDefault && includeCustom && !customPrefix.isEmpty {
                    nameParts.append(customPrefix)
                }
            case .prompt:
                if includePrompt { nameParts.append(finalSamplePrompt) }
            case .date:
                // Add date string only if date is included
                if includeDate && !dateString.isEmpty {
                    nameParts.append(dateString)
                }
            case .time:
                // Add time string only if time is included
                if includeTime && !timeString.isEmpty {
                    nameParts.append(timeString)
                }
            }
        }

        // Join the parts
        let baseName = nameParts.filter { !$0.isEmpty }.joined(separator: "_")

        // Ensure a base name exists
        return (baseName.isEmpty ? "Authorcise_Save" : baseName) + ".txt"
    }


    var body: some View {
        // Use padding on the outer container to control edge spacing
        VStack(alignment: .leading, spacing: 20) { // Main spacing between sections

            // Section for Download Directory
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Download Directory")
                    .font(.headline)
                 Text("Choose a folder where your .txt files will be saved by default.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true) // Ensure wrapping
                HStack {
                     TextField("", text: .constant(selectedDirectoryDisplayPath))
                        .disabled(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(selectedDirectoryDisplayPath == "No directory selected" || selectedDirectoryDisplayPath.contains("Could not access") ? .gray : .primary)
                    Button("Choose Folder...") { selectDownloadDirectory() }
                }
                Text("Note: The app will request permission to access this folder. This is required for saving files directly to the chosen location.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true) // Ensure wrapping
            }

            // Section for Save Behavior
            VStack(alignment: .leading, spacing: 8) {
                Text("Saving Behavior")
                    .font(.headline)
                 Toggle("Always show save prompt (even with default directory)", isOn: $alwaysShowSavePrompt)
                    .toggleStyle(.checkbox)
                Text("If disabled and a default directory is set, files will save automatically (as a text file) when you choose to save your writing. Otherwise, a save dialogue will appear each time.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true) // Ensure wrapping
            }

            // Section for Filename Structure
            VStack(alignment: .leading, spacing: 8) {
                Text("Filename Structure")
                    .font(.headline)

                Toggle("Use default structure (Authorcise_Prompt_Date_Time.txt)", isOn: $filenameUseDefaultStructure)
                    .toggleStyle(.checkbox)
                    // MODIFIED .onChange for macOS 13 compatibility
                    .onChange(of: filenameUseDefaultStructure) { newValue in // Or { _ in
                        if newValue {
                            resetToDefaultStructure()
                        }
                    }

                Text("Customize components and order (if default structure is turned off):")
                    .font(.subheadline)
                    .foregroundColor(filenameUseDefaultStructure ? .gray : .primary)
                    .padding(.top, 5)

                // --- Rearrangeable Component List ---
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(componentOrder.indices, id: \.self) { index in
                        let component = componentOrder[index]
                        HStack {
                            // --- Up/Down Buttons ---
                            VStack(spacing: 2) {
                                Button { moveComponent(at: index, direction: .up) } label: { Image(systemName: "chevron.up") }
                                    .buttonStyle(.plain).font(.caption)
                                    .disabled(index == 0 || filenameUseDefaultStructure)
                                Button { moveComponent(at: index, direction: .down) } label: { Image(systemName: "chevron.down") }
                                    .buttonStyle(.plain).font(.caption)
                                    .disabled(index == componentOrder.count - 1 || filenameUseDefaultStructure)
                            }
                            .opacity(filenameUseDefaultStructure ? 0.5 : 1.0)
                            .frame(width: 20)

                            // --- Component Toggle/Input ---
                            componentRow(for: component)
                                .disabled(filenameUseDefaultStructure)
                                .opacity(filenameUseDefaultStructure ? 0.5 : 1.0)

                            Spacer()
                        }
                        .frame(height: 35)
                    }
                }
                .padding(.leading, 5)


                Text("Filename Preview:")
                    .font(.caption.weight(.semibold))
                    .padding(.top, 5)
                Text(filenamePreview)
                    .font(.caption.monospaced())
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Button Area
            HStack {
                Spacer() // Pushes button to the right
                Button("Save Settings") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 20) // Space above button

        }
        // Apply consistent padding around the entire content
        // Reduced top/bottom padding further
        .padding(.horizontal, 20) // Reduced horizontal padding slightly
        .padding(.vertical, 15) // Keep vertical padding moderate
        .frame(minWidth: 480, idealWidth: 550, minHeight: 680, idealHeight: 720, maxHeight: 780) // Adjusted height range
        .background(appBackgroundColor)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            loadComponentOrder()
            loadSavedDirectoryPreference()
            if filenameUseDefaultStructure {
                 resetComponentTogglesToDefault()
            }
        }
    }

    // Builds the specific row UI for each component type
    @ViewBuilder
    private func componentRow(for component: FilenameComponent) -> some View {
        HStack {
            switch component {
            case .authorcisePrefix:
                Toggle("Include 'Authorcise' prefix", isOn: $filenameIncludeAuthorcisePrefix)
                    .toggleStyle(.checkbox)
            case .customPrefix:
                HStack {
                     Toggle("Include Custom Prefix:", isOn: $filenameIncludeCustomPrefix)
                        .toggleStyle(.checkbox)
                        .fixedSize()
                     TextField("Enter prefix", text: $filenameCustomPrefixString)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(!filenameIncludeCustomPrefix)
                }
            case .prompt:
                Toggle("Include Prompt Word", isOn: $filenameIncludePrompt)
                    .toggleStyle(.checkbox)
            case .date:
                Toggle("Include Date (YYYY-MM-DD)", isOn: $filenameIncludeDate)
                    .toggleStyle(.checkbox)
            case .time:
                Toggle("Include Time (HH-MM-SS)", isOn: $filenameIncludeTime)
                    .toggleStyle(.checkbox)
            }
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Order Management Functions

    private func loadComponentOrder() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultKeys.filenameComponentOrder) {
            let decoder = JSONDecoder()
            if let decodedOrder = try? decoder.decode([FilenameComponent].self, from: data) {
                var currentSet = Set(decodedOrder)
                var fullOrder = decodedOrder
                for component in FilenameComponent.allCases {
                    if !currentSet.contains(component) {
                        fullOrder.append(component)
                        currentSet.insert(component)
                    }
                }
                self.componentOrder = fullOrder.filter { FilenameComponent.allCases.contains($0) }
                print("SettingsView: Loaded component order: \(self.componentOrder.map { $0.rawValue })")
                if self.componentOrder.isEmpty {
                     self.componentOrder = FilenameComponent.allCases
                     saveComponentOrder()
                }
                return
            } else {
                 print("SettingsView: Failed to decode component order.")
            }
        } else {
            print("SettingsView: No saved component order found.")
        }
        self.componentOrder = FilenameComponent.allCases
        print("SettingsView: Using default component order.")
        saveComponentOrder()
    }

    private func saveComponentOrder() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(componentOrder) {
            UserDefaults.standard.set(encoded, forKey: UserDefaultKeys.filenameComponentOrder)
            print("SettingsView: Saved component order: \(self.componentOrder.map { $0.rawValue })")
        } else {
             print("SettingsView: Failed to encode component order.")
        }
    }

    enum MoveDirection { case up, down }

    private func moveComponent(at index: Int, direction: MoveDirection) {
        guard !filenameUseDefaultStructure else { return }

        switch direction {
        case .up:
            guard index > 0 else { return }
            componentOrder.swapAt(index, index - 1)
        case .down:
            guard index < componentOrder.count - 1 else { return }
            componentOrder.swapAt(index, index + 1)
        }
        saveComponentOrder()
    }

    private func resetComponentTogglesToDefault() {
        filenameIncludeAuthorcisePrefix = true
        filenameIncludePrompt = true
        filenameIncludeDate = true
        filenameIncludeTime = true
        filenameIncludeCustomPrefix = false
        // filenameCustomPrefixString remains as is, user might want to keep it
    }

    private func resetToDefaultStructure() {
         resetComponentTogglesToDefault()
         self.componentOrder = FilenameComponent.allCases // Reset order to default
         saveComponentOrder()
    }


    // MARK: - Directory Management Functions (Unchanged)

    func loadSavedDirectoryPreference() {
        guard let bookmarkData = defaultDownloadDirectoryBookmarkData else {
            selectedDirectoryDisplayPath = "No directory selected"
            print("SettingsView: No saved directory preference found.")
            return
        }

        if let url = resolveBookmark(bookmarkData, startAccessing: true) {
            selectedDirectoryDisplayPath = url.path
            print("SettingsView: Loaded and verified saved directory: \(url.path)")
            // It's important to stop accessing the resource once done with it,
            // especially if it was only for display/verification.
            // The actual save operation will re-acquire access.
            url.stopAccessingSecurityScopedResource()
        } else {
            selectedDirectoryDisplayPath = "Could not access previously selected directory. Please choose again."
            print("SettingsView: Failed to resolve or access bookmarked directory.")
            // Optionally, clear the bad bookmark data
            // defaultDownloadDirectoryBookmarkData = nil
        }
    }

    func selectDownloadDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Default Download Directory"
        openPanel.message = "Select a folder to save your files by default."
        openPanel.prompt = "Choose Folder"
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true

        openPanel.begin { (result) -> Void in
            if result == .OK, let chosenURL = openPanel.url {
                print("SettingsView: User selected directory URL: \(chosenURL.path)")
                do {
                    // Create a security-scoped bookmark.
                    let bookmarkData = try chosenURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    self.defaultDownloadDirectoryBookmarkData = bookmarkData
                    self.selectedDirectoryDisplayPath = chosenURL.path // Update display
                    print("SettingsView: Successfully created and saved security-scoped bookmark.")

                    // Test access immediately after creating the bookmark
                    if chosenURL.startAccessingSecurityScopedResource() {
                        print("SettingsView: Successfully started accessing security-scoped resource for initial verification: \(chosenURL.path)")
                        chosenURL.stopAccessingSecurityScopedResource() // Release after verification
                        print("SettingsView: Stopped accessing security-scoped resource after verification.")
                    } else {
                        print("SettingsView: ERROR - Failed to start accessing security-scoped resource after selection.")
                        self.selectedDirectoryDisplayPath = "Error: Could not secure access to folder."
                         // Clear the potentially bad bookmark if access fails
                        self.defaultDownloadDirectoryBookmarkData = nil
                    }
                } catch {
                    print("SettingsView: ERROR creating or saving bookmark data: \(error.localizedDescription)")
                    self.selectedDirectoryDisplayPath = "Error saving selection. See console."
                }
            } else {
                print("SettingsView: User cancelled the NSOpenPanel or an error occurred.")
            }
        }
    }
}

// Preview Provider for SettingsView
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(\.colorScheme, .light)
            .frame(width: 550, height: 720) // Adjusted for preview
        SettingsView()
            .environment(\.colorScheme, .dark)
            .frame(width: 550, height: 720) // Adjusted for preview
    }
}

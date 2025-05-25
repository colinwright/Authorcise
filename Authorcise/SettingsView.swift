import SwiftUI
import AppKit // Required for NSOpenPanel, NSApplication
import UniformTypeIdentifiers // Required for UTType
import Combine // Required for NotificationCenter publishers

// This is the SwiftUI View for the Settings panel.
struct SettingsView: View {
    // Environment variable to detect color scheme
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Writing Journal File State
    @State private var writingJournalDisplayPath: String = "No Writing Journal selected"
    // AppStorage for the bookmark data of the Writing Journal file
    @AppStorage(UserDefaultKeys.masterSaveFileBookmark) var writingJournalBookmarkData: Data?

    // MARK: - Mandala Mode State
    @AppStorage(UserDefaultKeys.mandalaModeEnabled) var mandalaModeEnabled: Bool = false
    
    // MARK: - Session State
    @State private var isWritingSessionActive: Bool = false
    @State private var cancellables = Set<AnyCancellable>()


    // Define background color based on system appearance
    private var appBackgroundColor: Color {
        colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color(NSColor.textBackgroundColor)
    }
    
    // Define Mandala Mode color to match ContentView
    private let mandalaModeColor = Color(hex: "#B22222").opacity(0.85) // Dull red (Firebrick with opacity)


    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Writing Journal File")
                    .font(.headline)
                Text("Choose a single .txt file where all your writings will be saved. New entries will be appended to this file.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    TextField("", text: .constant(writingJournalDisplayPath))
                        .disabled(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(writingJournalDisplayPath == "No Writing Journal selected" || writingJournalDisplayPath.contains("Could not access") ? .gray : .primary)
                    Button("Choose File...") {
                        selectWritingJournalFile()
                    }
                }
                Text("This is your main journal. If no file is selected, you will be prompted to choose or create one when you first save. To start a new journal, simply type a new name in the file dialog that appears, and a new .txt document will be created for you. Ensure the file is a plain text (.txt) file.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Mandala Mode")
                    .font(.headline)
                Toggle("Enable Mandala Mode", isOn: $mandalaModeEnabled)
                    .toggleStyle(.checkbox)
                    .disabled(isWritingSessionActive)
                    .opacity(isWritingSessionActive ? 0.5 : 1.0)
                
                Text(isWritingSessionActive ? "Mandala Mode cannot be changed while a writing session is active. Please finish or reset your current session first." : "When Mandala Mode is active, your writing sessions are ephemeral and cannot be saved. This encourages focusing on the process of writing without attachment to the outcome.")
                    .font(.caption)
                    // Use mandalaModeColor when the session is active and text indicates it cannot be changed
                    .foregroundColor(isWritingSessionActive ? mandalaModeColor : .gray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 10)

        }
        .padding(.horizontal, 25)
        .padding(.vertical, 20)
        .frame(minWidth: 480, idealWidth: 520, maxWidth: 650,
               minHeight: 340, idealHeight: 380, maxHeight: 520)
        .background(appBackgroundColor)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            print("SettingsView: onAppear. Current AppState.isCurrentSessionActive = \(AppState.isCurrentSessionActive)")
            self.isWritingSessionActive = AppState.isCurrentSessionActive
            loadWritingJournalPreference()
            setupNotificationObservers()
        }
        .onDisappear {
            print("SettingsView: onDisappear, cancelling observers")
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
        }
    }

    // MARK: - Notification Handling
    private func setupNotificationObservers() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        print("SettingsView: Setting up notification observers.")

        NotificationCenter.default.publisher(for: .writingSessionDidStart)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                print("SettingsView: Received .writingSessionDidStart notification. Setting isWritingSessionActive = true")
                self.isWritingSessionActive = true
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .writingSessionDidStop)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                print("SettingsView: Received .writingSessionDidStop notification. Setting isWritingSessionActive = false")
                self.isWritingSessionActive = false
            }
            .store(in: &cancellables)
    }


    // MARK: - Writing Journal File Management Functions
    func loadWritingJournalPreference() {
        guard let bookmarkData = writingJournalBookmarkData else {
            writingJournalDisplayPath = "No Writing Journal selected"
            return
        }
        if let url = resolveBookmark(bookmarkData, startAccessing: true) {
            writingJournalDisplayPath = url.path
            url.stopAccessingSecurityScopedResource()
        } else {
            writingJournalDisplayPath = "Could not access previously selected journal. Please choose again."
        }
    }

    func selectWritingJournalFile() {
        let savePanel = NSSavePanel()
        savePanel.title = "Choose or Create Writing Journal"
        savePanel.message = "Select an existing .txt file or specify a new name for your Writing Journal."
        savePanel.prompt = "Set Journal File"
        
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [UTType.plainText]
        } else {
            savePanel.allowedFileTypes = ["txt"]
        }
        
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Writing_Journal.txt"

        savePanel.begin { (result) -> Void in
            if result == .OK, let chosenURL = savePanel.url {
                do {
                    if !FileManager.default.fileExists(atPath: chosenURL.path) {
                        try "".write(to: chosenURL, atomically: true, encoding: .utf8)
                    }
                    let bookmarkData = try chosenURL.bookmarkData(options: .withSecurityScope,
                                                                  includingResourceValuesForKeys: nil,
                                                                  relativeTo: nil)
                    self.writingJournalBookmarkData = bookmarkData
                    self.writingJournalDisplayPath = chosenURL.path
                    if chosenURL.startAccessingSecurityScopedResource() {
                        chosenURL.stopAccessingSecurityScopedResource()
                    }
                } catch {
                    self.writingJournalDisplayPath = "Error setting journal file. See console."
                    print("SettingsView: ERROR processing Writing Journal selection: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Bookmark Resolution Helper
    private func resolveBookmark(_ bookmarkData: Data, startAccessing: Bool = true) -> URL? {
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            if isStale { print("SettingsView: Bookmark for \(url.path) is stale.") }
            if startAccessing {
                guard url.startAccessingSecurityScopedResource() else { return nil }
            }
            return url
        } catch {
            print("SettingsView: ERROR resolving bookmark: \(error.localizedDescription)")
            return nil
        }
    }
}

// Preview Provider for SettingsView
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(\.colorScheme, .light)
            .previewDisplayName("Light Mode - Session Inactive")
            .frame(width: 520, height: 380)

        SettingsView()
            .environment(\.colorScheme, .dark)
            .previewDisplayName("Dark Mode - Session Inactive")
            .frame(width: 520, height: 380)
    }
}

import SwiftUI
import UniformTypeIdentifiers // Required for TextFile

// Note: The Notification.Name extensions for .settingsWindowOpened and .settingsWindowClosed
// should now be solely in your AppNotifications.swift file.

// Helper extension to initialize Color from hex string (Keep this)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// The main view of the application.
struct ContentView: View {
    // Environment variables
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState // Use the shared AppState

    // Local State variables (View-specific UI state)
    @State private var currentPrompt: String = ""
    @State private var selectedDurationInSeconds: Int = 120
    @State private var timeRemaining: Int = 120
    @State private var timer: Timer?
    @State private var isTimerActive: Bool = false
    @State private var isSessionEverStarted: Bool = false
    @State private var showPostTimerAlert: Bool = false
    @State private var showStartOverAlert: Bool = false
    @State private var forceViewUpdateForFullscreen: Bool = false
    @State private var saveStatusMessage: String = "" // For displaying save feedback

    // Focus state for the TextEditor
    @FocusState private var editorHasFocus: Bool

    // AppStorage for dark mode state
    @AppStorage("isDarkModeEnabled") var isDarkModeEnabled: Bool = false

    // Hover states for minimalist buttons
    @State private var mainButtonHover: Bool = false
    @State private var saveButtonHover: Bool = false
    @State private var durationMenuHover: Bool = false
    @State private var appearanceButtonHover: Bool = false
    @State private var fullscreenButtonHover: Bool = false
    @State private var resetButtonHover: Bool = false

    // Create an instance of our custom window delegate
    @State private var windowDelegate = WindowDelegate() // Ensure WindowDelegate is defined

    // --- Style Constants ---
    private let appBackgroundColorLight = Color(NSColor.textBackgroundColor)
    private let appBackgroundColorDark = Color(NSColor.textBackgroundColor)
    private var primaryTextColor: Color { colorScheme == .dark ? Color(red: 0.95, green: 0.95, blue: 0.95) : Color(NSColor.textColor) }
    private var secondaryTextColor: Color { colorScheme == .dark ? Color(red: 0.65, green: 0.65, blue: 0.65) : Color(NSColor.secondaryLabelColor) }
    private var controlBarHoverColor: Color { colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.7) }
    private let editorFont = Font.custom("Lato-Regular", size: 18)
    private let editorLineSpacing: CGFloat = 9
    private let editorMaxWidth: CGFloat = 750
    private let textEditorInternalHorizontalPadding: CGFloat = 35
    private let textEditorInternalVerticalPadding: CGFloat = 25
    private let mainContentHorizontalPadding: CGFloat = 40
    private let mainContentVerticalPadding: CGFloat = 30
    private let controlBarPaddingBottom: CGFloat = 20
    private let accentColorLight = Color(hex: "#A1CDF4")
    private let accentColorDark = Color(hex: "#C1DDF7")
    private var currentAccentColor: Color { colorScheme == .dark ? accentColorDark : accentColorLight }
    let timerDurations: [Int] = [60, 120, 300, 600, 900, 1800]

    var body: some View {
        let _ = forceViewUpdateForFullscreen

        VStack(spacing: 25) {
            // Top section for prompt and timer
            HStack(spacing: 4) {
                if isSessionEverStarted {
                    Text("Prompt:")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryTextColor)
                    Text(currentPrompt)
                        .font(.system(size: 13))
                        .foregroundColor(currentAccentColor)
                    Text(" / ")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryTextColor)
                    Text("Time:")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryTextColor)
                    Text(formatTime(seconds: timeRemaining))
                        .font(.system(size: 13))
                        .foregroundColor(isTimerActive ? currentAccentColor : secondaryTextColor)
                        .frame(minWidth: 45, alignment: .leading)
                } else {
                    Text("Select duration, then click 'Start Writing'.")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryTextColor)
                }
            }
            .padding(.top, mainContentVerticalPadding)
            .frame(minHeight: 30)
            .frame(maxWidth: editorMaxWidth)
            .padding(.horizontal, mainContentHorizontalPadding)

            VStack {
                if isSessionEverStarted {
                    TextEditor(text: $appState.userText)
                        .font(editorFont)
                        .foregroundColor(primaryTextColor)
                        .lineSpacing(editorLineSpacing)
                        .padding(.horizontal, textEditorInternalHorizontalPadding)
                        .padding(.vertical, textEditorInternalVerticalPadding)
                        .frame(maxHeight: .infinity)
                        .focused($editorHasFocus)
                        .disabled(!isTimerActive)
                        .opacity(isTimerActive ? 1.0 : 0.6)
                        .scrollContentBackground(.hidden)
                        .background(colorScheme == .dark ? appBackgroundColorDark : appBackgroundColorLight)
                } else {
                    Rectangle()
                        .fill(colorScheme == .dark ? appBackgroundColorDark : appBackgroundColorLight)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, textEditorInternalHorizontalPadding)
                        .padding(.vertical, textEditorInternalVerticalPadding)
                }
            }
            .frame(maxWidth: editorMaxWidth)
            .padding(.horizontal, mainContentHorizontalPadding)
            
            if !saveStatusMessage.isEmpty {
                Text(saveStatusMessage)
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
                    .padding(.horizontal, mainContentHorizontalPadding)
                    .frame(maxWidth: editorMaxWidth, alignment: .leading)
                    .onTapGesture {
                        saveStatusMessage = ""
                    }
            }

            HStack(spacing: 15) {
                Button { handleMainButtonAction() } label: {
                    Text(mainButtonText())
                        .font(.system(size: 13))
                        .foregroundColor(mainButtonHover ? controlBarHoverColor : secondaryTextColor)
                }
                .buttonStyle(.plain)
                .onHover { mainButtonHover = $0 }
                .keyboardShortcut(.space, modifiers: [])

                if isSessionEverStarted && !appState.userText.isEmpty {
                    Button { callSaveTextFile() } label: {
                        Text("Save Work")
                            .font(.system(size: 13))
                            .foregroundColor(saveButtonHover ? controlBarHoverColor : secondaryTextColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { saveButtonHover = $0 }
                    .keyboardShortcut("s", modifiers: .command)
                }

                Spacer()

                Menu {
                    ForEach(timerDurations, id: \.self) { duration in
                        Button {
                            selectedDurationInSeconds = duration
                            if !isSessionEverStarted {
                                timeRemaining = duration
                            }
                        } label: {
                            Text("\(formatTime(seconds: duration))\(duration == selectedDurationInSeconds ? " *" : "")")
                        }
                    }
                } label: {
                     Text(formatTime(seconds: selectedDurationInSeconds))
                        .font(.system(size: 13))
                        .foregroundColor(durationMenuHover ? controlBarHoverColor : secondaryTextColor)
                        .frame(minWidth: 45, alignment: .leading)
                }
                .buttonStyle(.plain)
                .onHover { durationMenuHover = $0 }
                .disabled(isSessionEverStarted)
                .opacity(isSessionEverStarted ? 0.4 : 1.0)

                Button { toggleAppearance() } label: {
                    Image(systemName: isDarkModeEnabled ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 14))
                        .foregroundColor(appearanceButtonHover ? controlBarHoverColor : secondaryTextColor)
                }
                .buttonStyle(.plain)
                .onHover { appearanceButtonHover = $0 }

                Button { toggleFullscreen() } label: {
                    Image(systemName: isFullscreen() ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundColor(fullscreenButtonHover ? controlBarHoverColor : secondaryTextColor)
                }
                .buttonStyle(.plain)
                .onHover { fullscreenButtonHover = $0 }

                Button {
                    if isTimerActive {
                        stopActiveTimer()
                        editorHasFocus = false
                    }
                    showStartOverAlert = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                        .foregroundColor(resetButtonHover ? controlBarHoverColor : secondaryTextColor)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!isSessionEverStarted)
                .opacity(!isSessionEverStarted ? 0.4 : 1.0)
                .onHover { resetButtonHover = $0 }

            }
            .frame(maxWidth: editorMaxWidth)
            .padding(.horizontal, mainContentHorizontalPadding)
            .padding(.bottom, controlBarPaddingBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? appBackgroundColorDark : appBackgroundColorLight)
        .edgesIgnoringSafeArea(.all)
        .background(WindowAccessor(delegate: windowDelegate))
        .alert("Time's up!", isPresented: $showPostTimerAlert) {
            Button("Keep Writing") { alertActionKeepWritingSamePromptNewTimer() }
            Button("Save my Work") { callSaveTextFile() }
            Button("New Prompt (Discards Current Text)") { alertActionNewPromptDiscardText() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your time is up. What would you like to do next?") }
        .alert("Start Over?", isPresented: $showStartOverAlert) {
            Button("Save and Start Over", role: .destructive) {
                callSaveTextFile()
                actionResetApp()
            }
            Button("Discard and Start Over", role: .destructive) {
                actionResetApp()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Starting over will end your current writing session. Do you want to save your work first?") }

        .confirmationDialog(
             "Quit Authorcise?",
             isPresented: $appState.showQuitConfirmation,
             titleVisibility: .visible
        ) {
             Button("Save and Quit", role: .destructive) {
                 appState.handleSaveAndQuit()
             }
             Button("Discard and Quit", role: .destructive) {
                 NSApplication.shared.terminate(nil)
             }
             Button("Cancel", role: .cancel) {
                 appState.cancelQuitAfterSaveAttempt()
             }
        } message: {
             Text("You have unsaved changes. Do you want to save before quitting?")
        }

        .fileExporter(
            isPresented: $appState.showFileExporter,
            document: appState.documentToSave,
            contentType: .plainText,
            // Use helper function to generate filename based on settings
            // Pass current prompt for potential inclusion
            defaultFilename: generateFileName(forPrompt: currentPrompt, includeExtension: true) // Add extension for fileExporter
        ) { result in
            let wasQuitting = appState.isQuittingAfterSave

            switch result {
            case .success(let url):
                print("ContentView: .fileExporter saved to: \(url.path)")
                appState.workSaved()
                if wasQuitting {
                     NSApplication.shared.terminate(nil)
                }
            case .failure(let error):
                print("ContentView: .fileExporter save failed: \(error.localizedDescription)")
                let nsError = error as NSError
                if !(nsError.domain == "AuthorciseApp.SaveOperation" && nsError.code == NSUserCancelledError) &&
                   !(nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError) {
                    saveStatusMessage = "Save failed: \(error.localizedDescription)"
                } else {
                    saveStatusMessage = ""
                }
                 if wasQuitting {
                     print("ContentView: Save via .fileExporter failed, cancelling termination.")
                     appState.cancelQuitAfterSaveAttempt()
                 }
            }
             if appState.showFileExporter {
                 appState.showFileExporter = false
             }
        }
        .onAppear {
            windowDelegate.appState = appState
            if !isSessionEverStarted {
                timeRemaining = selectedDurationInSeconds
            }
            NotificationCenter.default.addObserver(forName: .settingsWindowOpened, object: nil, queue: .main) { _ in
                if self.isTimerActive {
                    print("ContentView: Settings window opened, pausing timer.")
                    self.actionPauseTimer()
                }
            }
        }
    }

    // MARK: - Helper Functions & Actions

    func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    func mainButtonText() -> String {
        if !isSessionEverStarted { return "Start Writing" }
        if isTimerActive { return "Pause Writing" }
        if timeRemaining > 0 { return "Resume Writing" }
        return "Start New Writing"
    }

    func handleMainButtonAction() {
        if !isSessionEverStarted {
            actionStartFirstSession()
        } else if isTimerActive {
            actionPauseTimer()
        } else {
            if timeRemaining > 0 { actionResumeTimer() }
            else { actionStartNewSprintWithNewPrompt() }
        }
        if !saveStatusMessage.starts(with: "Saved to:") {
             saveStatusMessage = ""
        }
    }

    func actionStartFirstSession() {
        isSessionEverStarted = true
        currentPrompt = Prompts.words.randomElement() ?? "inspiration"
        timeRemaining = selectedDurationInSeconds
        startActiveTimer()
        focusEditor()
        saveStatusMessage = ""
    }

    func actionPauseTimer() {
        stopActiveTimer()
        editorHasFocus = false
    }

    func actionResumeTimer() {
        startActiveTimer()
        focusEditor()
    }

    func actionStartNewSprintWithNewPrompt() {
        currentPrompt = Prompts.words.randomElement() ?? "next chapter"
        timeRemaining = selectedDurationInSeconds
        startActiveTimer()
        focusEditor()
        saveStatusMessage = ""
    }

    func actionResetApp() {
        stopActiveTimer()
        isSessionEverStarted = false
        isTimerActive = false
        currentPrompt = ""
        appState.userText = ""
        timeRemaining = selectedDurationInSeconds
        editorHasFocus = false
        saveStatusMessage = ""
    }

    func startActiveTimer() {
        if isTimerActive { return }
        isTimerActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.stopActiveTimer()
                self.editorHasFocus = false
                self.showPostTimerAlert = true
            }
        }
    }

    func stopActiveTimer() {
        timer?.invalidate()
        timer = nil
        isTimerActive = false
    }

    // MARK: - Alert Button Actions

    func alertActionKeepWritingSamePromptNewTimer() {
        timeRemaining = selectedDurationInSeconds
        startActiveTimer()
        focusEditor()
        saveStatusMessage = ""
    }

    func alertActionNewPromptDiscardText() {
        stopActiveTimer()
        editorHasFocus = false
        appState.userText = ""
        currentPrompt = Prompts.words.randomElement() ?? "fresh start"
        timeRemaining = selectedDurationInSeconds
        saveStatusMessage = ""
    }

    // MARK: - Filename Generation Helper
    
    // Updated helper function to correctly handle date/time separation based on order
    func generateFileName(forPrompt prompt: String, includeExtension: Bool = false) -> String {
        let defaults = UserDefaults.standard
        let useDefaultStructure = defaults.object(forKey: UserDefaultKeys.filenameUseDefaultStructure) as? Bool ?? true
        
        var nameParts: [String] = []
        let now = Date()
        
        // Sanitize the prompt for use in filename
        let promptSanitized = prompt.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
        let safePrompt = promptSanitized.isEmpty || promptSanitized == "_" ? "Writing" : promptSanitized

        if useDefaultStructure {
            // Use the fixed default structure
            let defaultFormatter = DateFormatter()
            defaultFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            nameParts.append("Authorcise")
            nameParts.append(safePrompt)
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
            let includePrompt = defaults.object(forKey: UserDefaultKeys.filenameIncludePrompt) as? Bool ?? true
            let includeDate = defaults.object(forKey: UserDefaultKeys.filenameIncludeDate) as? Bool ?? true
            let includeTime = defaults.object(forKey: UserDefaultKeys.filenameIncludeTime) as? Bool ?? true
            let includeCustomPrefix = defaults.object(forKey: UserDefaultKeys.filenameIncludeCustomPrefix) as? Bool ?? false
            let customPrefixString = defaults.string(forKey: UserDefaultKeys.filenameCustomPrefixString) ?? ""
            
            // Sanitize custom prefix
            let safeCustomPrefix = customPrefixString
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)

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
            
            // Iterate through the stored order and append parts if included
            for component in componentOrder {
                switch component {
                case .authorcisePrefix:
                    if includePrefix { nameParts.append("Authorcise") }
                case .customPrefix:
                    if includeCustomPrefix && !safeCustomPrefix.isEmpty { nameParts.append(safeCustomPrefix) }
                case .prompt:
                    if includePrompt { nameParts.append(safePrompt) }
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
        }
        
        // Join the parts, ensuring no leading/trailing underscores if parts are missing
        let baseName = nameParts.filter { !$0.isEmpty }.joined(separator: "_")
        
        // Ensure a base name exists even if all components are off
        let finalBaseName = baseName.isEmpty ? "Authorcise_Save" : baseName
        
        // Return filename WITH or WITHOUT extension based on parameter
        return includeExtension ? finalBaseName + ".txt" : finalBaseName
    }


    // MARK: - File Operations

    func callSaveTextFile() {
        if isTimerActive {
            stopActiveTimer()
            editorHasFocus = false
        }

        let contentToSave = appState.userText
        // Generate filename using the updated helper function (without extension)
        let fileNameWithoutExtension = generateFileName(forPrompt: currentPrompt, includeExtension: false)

        // Pass the generated name (without extension) to the global save function
        saveTextFile(content: contentToSave, preferredFileName: fileNameWithoutExtension) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let path):
                    print("ContentView: Successfully saved to: \(path)")
                    self.saveStatusMessage = "Saved to: \(path)"
                    appState.workSaved()
                case .failure(let error):
                    print("ContentView: Save failed: \(error.localizedDescription)")
                    let nsError = error as NSError
                    if nsError.domain == "AuthorciseApp.SaveOperation" && nsError.code == NSUserCancelledError {
                        self.saveStatusMessage = ""
                    } else if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                         self.saveStatusMessage = ""
                    }
                    else {
                        self.saveStatusMessage = "Save failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func focusEditor() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.editorHasFocus = true
        }
    }

    // --- Appearance and Fullscreen Actions ---

    func toggleAppearance() {
        isDarkModeEnabled.toggle()
    }

    func toggleFullscreen() {
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            window.toggleFullScreen(nil)
            forceViewUpdateForFullscreen.toggle()
        }
    }

    func isFullscreen() -> Bool {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return false }
        return window.styleMask.contains(.fullScreen)
    }
}

// Preview provider needs EnvironmentObject
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environment(\.colorScheme, .light)
        ContentView()
            .environmentObject(AppState())
            .environment(\.colorScheme, .dark)
    }
}

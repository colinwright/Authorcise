import SwiftUI
import UniformTypeIdentifiers // Required for TextFile

// Note: The Notification.Name extensions for .settingsWindowOpened and .settingsWindowClosed
// should now be solely in your AppNotifications.swift file.

// Helper extension to initialize Color from hex string (Keep this)
// --- ENSURE THIS EXTENSION IS DEFINED ONLY ONCE ---
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
// --- END OF COLOR EXTENSION ---

// The main view of the application.
// --- ENSURE THIS STRUCT IS DEFINED ONLY ONCE ---
struct ContentView: View {
    // Environment variables
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    // Local State variables
    @State private var currentPrompt: String = ""
    @State private var selectedDurationInSeconds: Int = 120
    @State private var timeRemaining: Int = 120
    @State private var timer: Timer?
    @State private var isTimerActive: Bool = false
    @State private var isSessionEverStarted: Bool = false
    @State private var showPostTimerAlert: Bool = false
    @State private var showStartOverAlert: Bool = false
    @State private var forceViewUpdateForFullscreen: Bool = false
    @State private var saveStatusMessage: String = ""

    // Focus state for the TextEditor
    @FocusState private var editorHasFocus: Bool

    // AppStorage for preferences
    @AppStorage("isDarkModeEnabled") var isDarkModeEnabled: Bool = false
    @AppStorage(UserDefaultKeys.typewriterModeEnabled) private var typewriterModeEnabled: Bool = false // Default OFF

    // Hover states
    @State private var mainButtonHover: Bool = false
    @State private var saveButtonHover: Bool = false
    @State private var durationMenuHover: Bool = false
    @State private var appearanceButtonHover: Bool = false
    @State private var fullscreenButtonHover: Bool = false
    @State private var resetButtonHover: Bool = false
    @State private var typewriterModeButtonHover: Bool = false

    @State private var windowDelegate = WindowDelegate()

    // --- Style Constants ---
    private var appBackgroundColor: Color { colorScheme == .dark ? Color(NSColor.textBackgroundColor) : Color(NSColor.textBackgroundColor) }
    private var primaryTextColorSwiftUI: Color { colorScheme == .dark ? .white.opacity(0.95) : .black }
    private var secondaryTextColorSwiftUI: Color { colorScheme == .dark ? .gray.opacity(0.8) : .gray }
    private var controlBarHoverColorSwiftUI: Color { colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.7) }
    
    private let editorFontSwiftUI = Font.custom("Lato-Regular", size: 18)
    private let editorLineSpacing: CGFloat = 9
    private let editorMaxWidth: CGFloat = 750
    // Padding for the TextEditor content area itself
    private let textEditorContentHorizontalPadding: CGFloat = 5
    private let textEditorContentVerticalPadding: CGFloat = 10

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
            topInfoBar
            editorSection
            
            if !saveStatusMessage.isEmpty {
                saveStatusTextView
            }
            
            bottomControlBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appBackgroundColor)
        .edgesIgnoringSafeArea(.all)
        .background(WindowAccessor(delegate: windowDelegate))
        .alert("Time's up!", isPresented: $showPostTimerAlert) {
            Button("Keep Writing") { alertActionKeepWritingSamePromptNewTimer() }
            Button("Save My Work") { callSaveTextFile() }
            Button("New Prompt (Don't Save)") { alertActionNewPromptDiscardText() }
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
            defaultFilename: generateFileName(forPrompt: currentPrompt, includeExtension: true)
        ) { result in
            handleFileExporterResult(result)
        }
        .onAppear {
            handleOnAppear()
        }
    }

    private var topInfoBar: some View {
        HStack(spacing: 4) {
            if isSessionEverStarted {
                Text("Prompt:")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColorSwiftUI)
                Text(currentPrompt)
                    .font(.system(size: 13))
                    .foregroundColor(currentAccentColor)
                Text(" / ")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColorSwiftUI)
                Text("Time:")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColorSwiftUI)
                Text(formatTime(seconds: timeRemaining))
                    .font(.system(size: 13))
                    .foregroundColor(isTimerActive ? currentAccentColor : secondaryTextColorSwiftUI)
                    .frame(minWidth: 45, alignment: .leading)
            } else {
                Text("Select duration, then click 'Start Writing'. \(typewriterModeEnabled ? "(Typewriter Mode On)" : "")")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColorSwiftUI)
            }
        }
        .padding(.top, mainContentVerticalPadding)
        .frame(minHeight: 30)
        .frame(maxWidth: editorMaxWidth)
        .padding(.horizontal, mainContentHorizontalPadding)
    }

    private var editorSection: some View {
        VStack {
            if isSessionEverStarted {
                if typewriterModeEnabled {
                    GeometryReader { geometry in
                        ScrollViewReader { scrollProxy in
                            ScrollView(.vertical, showsIndicators: false) { // Scrollbar explicitly hidden
                                TextEditor(text: $appState.userText)
                                    .font(editorFontSwiftUI)
                                    .foregroundColor(primaryTextColorSwiftUI)
                                    .lineSpacing(editorLineSpacing)
                                    // Internal padding for the actual text content
                                    .padding(.horizontal, textEditorContentHorizontalPadding)
                                    .padding(.vertical, textEditorContentVerticalPadding)
                                    // Frame the TextEditor to fill width and apply large vertical padding
                                    // for the typewriter effect.
                                    .frame(width: geometry.size.width)
                                    .padding(.top, geometry.size.height * 0.25) // Eye-level offset
                                    .padding(.bottom, geometry.size.height * 0.70) // Scroll room
                                    .focused($editorHasFocus)
                                    .disabled(!isTimerActive)
                                    .opacity(isTimerActive ? 1.0 : 0.6)
                                    .background(appBackgroundColor) // Match app background
                                    .id("paddedTextEditor") // ID for scrolling
                                    .scrollDisabled(true) // Attempt to disable TextEditor's internal scrolling
                            }
                            .onChange(of: appState.userText) {
                                // --- MODIFICATION: Removed withAnimation for diagnostics ---
                                print("Typewriter mode: Scrolling paddedTextEditor to bottom (no animation).")
                                scrollProxy.scrollTo("paddedTextEditor", anchor: .bottom)
                                // --- END OF MODIFICATION ---
                            }
                            .onAppear {
                                // Initial scroll if there's existing text when mode is activated
                                if !appState.userText.isEmpty {
                                    DispatchQueue.main.async {
                                        scrollProxy.scrollTo("paddedTextEditor", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Standard SwiftUI TextEditor (Non-Typewriter Mode)
                    TextEditor(text: $appState.userText)
                        .font(editorFontSwiftUI)
                        .foregroundColor(primaryTextColorSwiftUI)
                        .lineSpacing(editorLineSpacing)
                        .padding(.horizontal, textEditorContentHorizontalPadding) // Use consistent padding
                        .padding(.vertical, textEditorContentVerticalPadding)
                        .frame(maxHeight: .infinity)
                        .focused($editorHasFocus)
                        .disabled(!isTimerActive)
                        .opacity(isTimerActive ? 1.0 : 0.6)
                        .scrollContentBackground(.hidden)
                        .background(appBackgroundColor)
                }
            } else {
                // Placeholder view when session hasn't started
                Rectangle()
                    .fill(appBackgroundColor)
                    .frame(maxHeight: .infinity)
                    // Use consistent padding for placeholder area
                    .padding(.horizontal, mainContentHorizontalPadding + textEditorContentHorizontalPadding)
                    .padding(.vertical, mainContentVerticalPadding + textEditorContentVerticalPadding)
                    .overlay(
                        Text(typewriterModeEnabled ? "Typewriter Mode is ON" : "Typewriter Mode is OFF")
                            .font(.caption)
                            .foregroundColor(secondaryTextColorSwiftUI)
                            .padding(.bottom, 20),
                        alignment: .bottom
                    )
            }
        }
        .frame(maxWidth: editorMaxWidth)
        .padding(.horizontal, mainContentHorizontalPadding)
    }
    
    private var saveStatusTextView: some View {
         Text(saveStatusMessage)
            .font(.caption)
            .foregroundColor(secondaryTextColorSwiftUI)
            .padding(.horizontal, mainContentHorizontalPadding)
            .frame(maxWidth: editorMaxWidth, alignment: .leading)
            .onTapGesture {
                saveStatusMessage = ""
            }
    }

    private var bottomControlBar: some View {
        HStack(spacing: 15) {
            Button { handleMainButtonAction() } label: {
                Text(mainButtonText())
                    .font(.system(size: 13))
                    .foregroundColor(mainButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI)
            }
            .buttonStyle(.plain)
            .onHover { mainButtonHover = $0 }
            .keyboardShortcut(.space, modifiers: [])

            if isSessionEverStarted && !appState.userText.isEmpty {
                Button { callSaveTextFile() } label: {
                    Text("Save Work")
                        .font(.system(size: 13))
                        .foregroundColor(saveButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI)
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
                    .foregroundColor(durationMenuHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI)
                    .frame(minWidth: 45, alignment: .leading)
            }
            .buttonStyle(.plain)
            .onHover { durationMenuHover = $0 }
            .disabled(isSessionEverStarted)
            .opacity(isSessionEverStarted ? 0.4 : 1.0)

            Button {
                typewriterModeEnabled.toggle()
                if !saveStatusMessage.starts(with: "Saved to:") {
                     saveStatusMessage = ""
                }
            } label: {
                Image(systemName: typewriterModeEnabled ? "character.cursor.ibeam" : "text.aligncenter")
                    .font(.system(size: 14))
                    .foregroundColor(typewriterModeButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI)
            }
            .buttonStyle(.plain)
            .onHover { typewriterModeButtonHover = $0 }
            .disabled(isSessionEverStarted)
            .opacity(isSessionEverStarted ? 0.4 : 1.0)

            Button { toggleAppearance() } label: {
                Image(systemName: isDarkModeEnabled ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 14))
                    .foregroundColor(appearanceButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI)
            }
            .buttonStyle(.plain)
            .onHover { appearanceButtonHover = $0 }

            Button { toggleFullscreen() } label: {
                Image(systemName: isFullscreen() ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14))
                    .foregroundColor(fullscreenButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI)
            }
            .buttonStyle(.plain)
            .onHover { fullscreenButtonHover = $0 }

            Button {
                if isTimerActive {
                    stopActiveTimer()
                }
                showStartOverAlert = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14))
                    .foregroundColor(resetButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI)
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
        saveStatusMessage = ""
    }

    func actionPauseTimer() {
        stopActiveTimer()
    }

    func actionResumeTimer() {
        startActiveTimer()
    }

    func actionStartNewSprintWithNewPrompt() {
        currentPrompt = Prompts.words.randomElement() ?? "next chapter"
        timeRemaining = selectedDurationInSeconds
        appState.userText = ""
        appState.isWorkSaved = true
        startActiveTimer()
        saveStatusMessage = ""
    }

    func actionResetApp() {
        stopActiveTimer()
        isSessionEverStarted = false
        currentPrompt = ""
        appState.userText = ""
        appState.isWorkSaved = true
        timeRemaining = selectedDurationInSeconds
        saveStatusMessage = ""
    }

    func startActiveTimer() {
        if isTimerActive { return }
        
        isTimerActive = true
        print("ContentView: startActiveTimer - isTimerActive set to true.")
        
        // Set focus when timer starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // Slight delay for UI to update
            print("ContentView: startActiveTimer (delayed) - Setting editorHasFocus = true")
            self.editorHasFocus = true
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.stopActiveTimer()
                self.showPostTimerAlert = true
            }
        }
    }

    func stopActiveTimer() {
        timer?.invalidate()
        timer = nil
        
        let wasActive = isTimerActive
        
        if wasActive {
            print("ContentView: stopActiveTimer - Setting editorHasFocus = false")
            self.editorHasFocus = false
        }
        
        isTimerActive = false
        print("ContentView: stopActiveTimer - isTimerActive set to false.")
    }

    func alertActionKeepWritingSamePromptNewTimer() {
        timeRemaining = selectedDurationInSeconds
        startActiveTimer()
        saveStatusMessage = ""
    }

    func alertActionNewPromptDiscardText() {
        stopActiveTimer()
        appState.userText = ""
        appState.isWorkSaved = true
        currentPrompt = Prompts.words.randomElement() ?? "fresh start"
        timeRemaining = selectedDurationInSeconds
        saveStatusMessage = ""
    }
    
    func generateFileName(forPrompt prompt: String, includeExtension: Bool = false) -> String {
        let defaults = UserDefaults.standard
        let useDefaultStructure = defaults.object(forKey: UserDefaultKeys.filenameUseDefaultStructure) as? Bool ?? true
        
        var nameParts: [String] = []
        let now = Date()
        
        let promptSanitized = prompt.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
        let safePrompt = promptSanitized.isEmpty || promptSanitized == "_" ? "Writing" : promptSanitized

        if useDefaultStructure {
            let defaultFormatter = DateFormatter()
            defaultFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            nameParts.append("Authorcise")
            nameParts.append(safePrompt)
            nameParts.append(defaultFormatter.string(from: now))
        } else {
            let componentOrder: [FilenameComponent]
            if let data = defaults.data(forKey: UserDefaultKeys.filenameComponentOrder),
               let decodedOrder = try? JSONDecoder().decode([FilenameComponent].self, from: data) {
                componentOrder = decodedOrder
            } else {
                componentOrder = FilenameComponent.allCases
            }

            let includePrefix = defaults.object(forKey: UserDefaultKeys.filenameIncludeAuthorcisePrefix) as? Bool ?? true
            let includePromptFlag = defaults.object(forKey: UserDefaultKeys.filenameIncludePrompt) as? Bool ?? true
            let includeDateFlag = defaults.object(forKey: UserDefaultKeys.filenameIncludeDate) as? Bool ?? true
            let includeTimeFlag = defaults.object(forKey: UserDefaultKeys.filenameIncludeTime) as? Bool ?? true
            let includeCustomPrefix = defaults.object(forKey: UserDefaultKeys.filenameIncludeCustomPrefix) as? Bool ?? false
            let customPrefixString = defaults.string(forKey: UserDefaultKeys.filenameCustomPrefixString) ?? ""
            
            let safeCustomPrefix = customPrefixString
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)

            let dateFormatter = DateFormatter()
            var dateString = ""
            if includeDateFlag {
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateString = dateFormatter.string(from: now)
            }

            let timeFormatter = DateFormatter()
            var timeString = ""
            if includeTimeFlag {
                timeFormatter.dateFormat = "HH-mm-ss"
                timeString = timeFormatter.string(from: now)
            }
            
            for component in componentOrder {
                switch component {
                case .authorcisePrefix:
                    if includePrefix { nameParts.append("Authorcise") }
                case .customPrefix:
                    if includeCustomPrefix && !safeCustomPrefix.isEmpty { nameParts.append(safeCustomPrefix) }
                case .prompt:
                    if includePromptFlag { nameParts.append(safePrompt) }
                case .date:
                    if includeDateFlag && !dateString.isEmpty {
                        nameParts.append(dateString)
                    }
                case .time:
                    if includeTimeFlag && !timeString.isEmpty {
                        nameParts.append(timeString)
                    }
                }
            }
        }
        
        let baseName = nameParts.filter { !$0.isEmpty }.joined(separator: "_")
        let finalBaseName = baseName.isEmpty ? "Authorcise_Save" : baseName
        return includeExtension ? finalBaseName + ".txt" : finalBaseName
    }

    func callSaveTextFile() {
        if isTimerActive {
            actionPauseTimer()
        }

        let contentToSave = appState.userText
        let fileNameWithoutExtension = generateFileName(forPrompt: currentPrompt, includeExtension: false)

        saveTextFile(content: contentToSave, preferredFileName: fileNameWithoutExtension) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let path):
                    print("ContentView: Successfully saved to: \(path)")
                    self.saveStatusMessage = "Saved to: \(path.truncatingPath())"
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
    
    private func handleFileExporterResult(_ result: Result<URL, Error>) {
         let wasQuitting = appState.isQuittingAfterSave

            switch result {
            case .success(let url):
                print("ContentView: .fileExporter saved to: \(url.path)")
                appState.workSaved()
                saveStatusMessage = "Saved to: \(url.path.truncatingPath())"
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
                     print("ContentView: Save via .fileExporter failed during quit, cancelling termination.")
                     appState.cancelQuitAfterSaveAttempt()
                 }
            }
             if appState.showFileExporter {
                 appState.showFileExporter = false
             }
             if wasQuitting && !appState.showFileExporter {
                if appState.isQuittingAfterSave {
                    appState.isQuittingAfterSave = false
                }
             }
    }
    
    private func handleOnAppear() {
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
    
    func toggleAppearance() {
        isDarkModeEnabled.toggle()
        if !saveStatusMessage.starts(with: "Saved to:") { saveStatusMessage = "" }
    }

    func toggleFullscreen() {
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            window.toggleFullScreen(nil)
            forceViewUpdateForFullscreen.toggle()
        }
        if !saveStatusMessage.starts(with: "Saved to:") { saveStatusMessage = "" }
    }

    func isFullscreen() -> Bool {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return false }
        return window.styleMask.contains(.fullScreen)
    }
}
// --- END OF CONTENTVIEW STRUCT ---

// --- ENSURE THIS EXTENSION IS DEFINED ONLY ONCE (IF NOT ALREADY PART OF ANOTHER FILE) ---
// Helper extension to truncate file paths for display (moved here for clarity if it was duplicated)
extension String {
    func truncatingPath(maxLength: Int = 50) -> String {
        if self.count > maxLength {
            return "..." + self.suffix(maxLength - 3)
        }
        return self
    }
}
// --- END OF STRING EXTENSION ---

// Preview provider needs EnvironmentObject
// --- ENSURE THIS STRUCT IS DEFINED ONLY ONCE ---
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()

        ContentView()
            .environmentObject(appState)
            .environment(\.colorScheme, .light)
            .previewDisplayName("Light Mode")

        ContentView()
            .environmentObject(appState)
            .environment(\.colorScheme, .dark)
            .previewDisplayName("Dark Mode")

        ContentView()
            .environmentObject(appState)
            .environment(\.colorScheme, .light)
            .onAppear {
                UserDefaults.standard.set(true, forKey: UserDefaultKeys.typewriterModeEnabled)
            }
            .previewDisplayName("Typewriter ON (Light)")
        
        ContentView()
            .environmentObject(appState)
            .environment(\.colorScheme, .dark)
            .onAppear {
                UserDefaults.standard.set(true, forKey: UserDefaultKeys.typewriterModeEnabled)
            }
            .previewDisplayName("Typewriter ON - Session (Dark)")
    }
}
// --- END OF CONTENTVIEW_PREVIEWS STRUCT ---

import SwiftUI
import UniformTypeIdentifiers

// Notification names for session state
extension Notification.Name {
    static let writingSessionDidStart = Notification.Name("com.authorcise.writingSessionDidStart")
    static let writingSessionDidStop = Notification.Name("com.authorcise.writingSessionDidStop")
}

// Helper extension to initialize Color from hex string
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

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var currentPrompt: String = "" {
        didSet {
            appState.currentPromptForSaving = currentPrompt
        }
    }
    @State private var selectedDurationInSeconds: Int = 120
    @State private var timeRemaining: Int = 120
    @State private var timer: Timer?
    @State private var isTimerActive: Bool = false
    @State private var isSessionEverStarted: Bool = false {
        didSet {
            if oldValue != isSessionEverStarted {
                if isSessionEverStarted {
                    print("ContentView: Posting .writingSessionDidStart & setting AppState.isCurrentSessionActive = true")
                    NotificationCenter.default.post(name: .writingSessionDidStart, object: nil)
                    AppState.isCurrentSessionActive = true
                } else {
                    print("ContentView: Posting .writingSessionDidStop & setting AppState.isCurrentSessionActive = false")
                    NotificationCenter.default.post(name: .writingSessionDidStop, object: nil)
                    AppState.isCurrentSessionActive = false
                }
            }
        }
    }
    @State private var showPostTimerAlert: Bool = false
    @State private var showStartOverAlert: Bool = false
    @State private var forceViewUpdateForFullscreen: Bool = false
    @State private var saveStatusMessage: String = ""

    @FocusState private var editorHasFocus: Bool

    @AppStorage("isDarkModeEnabled") var isDarkModeEnabled: Bool = false
    @AppStorage(UserDefaultKeys.typewriterModeEnabled) private var typewriterModeEnabled: Bool = false
    @AppStorage(UserDefaultKeys.mandalaModeEnabled) private var mandalaModeEnabled: Bool = false

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
    private let mandalaModeColor = Color(hex: "#B22222").opacity(0.85)
    
    private let editorFontSwiftUI = Font.custom("Lato-Regular", size: 18)
    private let editorLineSpacing: CGFloat = 9
    private let editorMaxWidth: CGFloat = 750
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

        VStack(spacing: 0) {
            topInfoBar
                .padding(.bottom, 25) // << --- INCREASED PADDING HERE from 15 to 25

            editorSection

            modeStatusFooter
                .padding(.bottom, 8)
            
            statusMessageArea
                .padding(.bottom, 8)
            
            bottomControlBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appBackgroundColor)
        .edgesIgnoringSafeArea(.all)
        .background(WindowAccessor(delegate: windowDelegate))
        .alert("Time's up!", isPresented: $showPostTimerAlert) {
            Button("Keep Writing (New Timer)") { alertActionKeepWritingSamePromptNewTimer() }
            if !mandalaModeEnabled {
                Button("Save My Work") { callAppendToWritingJournalAndContinue() }
            }
            Button("New Prompt (Don't Save)") { alertActionNewPromptDiscardText() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(mandalaModeEnabled ? "Your time is up. Mandala Mode is active (saving disabled)." : "Your time is up. What would you like to do next?") }
        .alert("Start Over?", isPresented: $showStartOverAlert) {
            if !mandalaModeEnabled && !appState.userText.isEmpty {
                Button("Save and Start Over", role: .destructive) {
                    callAppendToWritingJournalThenReset()
                }
            }
            Button("Discard and Start Over", role: .destructive) {
                actionResetApp(clearText: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text(mandalaModeEnabled ? "Starting over will end your current writing session (Mandala Mode active, saving disabled)." : "Starting over will end your current writing session. Do you want to save your work first?") }
        .confirmationDialog(
             "Quit Authorcise?",
             isPresented: $appState.showQuitConfirmation,
             titleVisibility: .visible
        ) {
             if !mandalaModeEnabled && !appState.userText.isEmpty {
                 Button("Save and Quit", role: .destructive) {
                     appState.handleSaveAndQuit()
                 }
             }
             Button("Discard and Quit", role: .destructive) {
                 NSApplication.shared.terminate(nil)
             }
             Button("Cancel", role: .cancel) {
                 appState.cancelQuitAttempt()
             }
        } message: {
             Text(mandalaModeEnabled && !appState.userText.isEmpty ? "You have unsaved changes. Mandala Mode is active (saving disabled). Quit anyway?" : "You have unsaved changes. Do you want to save before quitting?")
        }
        .onAppear {
            handleOnAppear()
        }
        .onChange(of: appState.mandalaModeSaveAttemptMessage) { newMessage in
            if let msg = newMessage {
                saveStatusMessage = msg
                appState.mandalaModeSaveAttemptMessage = nil
            }
        }
    }

    // MARK: - UI Components

    private var topInfoBar: some View {
        HStack(spacing: 0) {
            Spacer()
            if isSessionEverStarted {
                Text("Prompt:")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColorSwiftUI)
                Text(" \(currentPrompt)")
                    .font(.system(size: 13))
                    .foregroundColor(currentAccentColor)
                
                Text(" / ")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColorSwiftUI)
                
                Text("Time:")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColorSwiftUI)
                Text(" \(formatTime(seconds: timeRemaining))")
                    .font(.system(size: 13))
                    .foregroundColor(isTimerActive ? currentAccentColor : secondaryTextColorSwiftUI)
                    .frame(minWidth: 45, alignment: .leading)
            } else {
                Text("Select duration, then click 'Start Writing'.")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColorSwiftUI)
            }
            Spacer()
        }
        .padding(.top, mainContentVerticalPadding)
        .frame(height: 30)
        .frame(maxWidth: editorMaxWidth)
        .padding(.horizontal, mainContentHorizontalPadding)
    }

    private var editorSection: some View {
        VStack {
            if isSessionEverStarted {
                if typewriterModeEnabled {
                    GeometryReader { geometry in
                        ScrollViewReader { scrollProxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                TextEditor(text: $appState.userText)
                                    .font(editorFontSwiftUI)
                                    .foregroundColor(primaryTextColorSwiftUI)
                                    .lineSpacing(editorLineSpacing)
                                    .padding(.horizontal, textEditorContentHorizontalPadding)
                                    .padding(.vertical, textEditorContentVerticalPadding)
                                    .frame(width: geometry.size.width)
                                    .padding(.top, geometry.size.height * 0.25)
                                    .padding(.bottom, geometry.size.height * 0.70)
                                    .focused($editorHasFocus)
                                    .disabled(!isTimerActive)
                                    .opacity(isTimerActive ? 1.0 : 0.6)
                                    .background(appBackgroundColor)
                                    .id("paddedTextEditor")
                                    .scrollDisabled(true)
                            }
                            .onChange(of: appState.userText) { _ in
                                scrollProxy.scrollTo("paddedTextEditor", anchor: .bottom)
                            }
                            .onAppear {
                                if !appState.userText.isEmpty {
                                    DispatchQueue.main.async {
                                        scrollProxy.scrollTo("paddedTextEditor", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    TextEditor(text: $appState.userText)
                        .font(editorFontSwiftUI)
                        .foregroundColor(primaryTextColorSwiftUI)
                        .lineSpacing(editorLineSpacing)
                        .padding(.horizontal, textEditorContentHorizontalPadding)
                        .padding(.vertical, textEditorContentVerticalPadding)
                        .frame(maxHeight: .infinity)
                        .focused($editorHasFocus)
                        .disabled(!isTimerActive)
                        .opacity(isTimerActive ? 1.0 : 0.6)
                        .scrollContentBackground(.hidden)
                        .background(appBackgroundColor)
                }
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: editorMaxWidth)
        .padding(.horizontal, mainContentHorizontalPadding)
    }
    
    private var modeStatusFooter: some View {
        HStack(spacing: 10) {
            Spacer()
            
            Text("Typewriter Mode: \(typewriterModeEnabled ? "ON" : "OFF")")
                .font(.caption)
                .foregroundColor(secondaryTextColorSwiftUI)
            
            Text("|")
                .font(.caption)
                .foregroundColor(secondaryTextColorSwiftUI.opacity(0.5))
            
            Text("Mandala Mode: \(mandalaModeEnabled ? (isSessionEverStarted ? "ON (Saving Disabled)" : "ON") : "OFF")")
                .font(.caption)
                .foregroundColor(mandalaModeEnabled ? mandalaModeColor : secondaryTextColorSwiftUI)
            
            Spacer()
        }
        .frame(maxWidth: editorMaxWidth)
        .padding(.horizontal, mainContentHorizontalPadding)
        .frame(height: 20)
    }
    
    private var statusMessageArea: some View {
        VStack(alignment: .leading) {
            Text(saveStatusMessage)
                .font(.caption)
                .foregroundColor(saveStatusMessage.contains("Mandala Mode") ? mandalaModeColor : (saveStatusMessage.contains("failed") || saveStatusMessage.contains("cancelled") ? .red : secondaryTextColorSwiftUI))
                .opacity(saveStatusMessage.isEmpty ? 0 : 1)
        }
        .padding(.horizontal, mainContentHorizontalPadding)
        .frame(maxWidth: editorMaxWidth, minHeight: 20, alignment: .leading)
        .onTapGesture {
            saveStatusMessage = ""
        }
        .onAppear {
            if !saveStatusMessage.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                    if !saveStatusMessage.isEmpty {
                       saveStatusMessage = ""
                    }
                }
            }
        }
        .onChange(of: saveStatusMessage) { newValue in
            if !newValue.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                     if saveStatusMessage == newValue {
                        saveStatusMessage = ""
                     }
                }
            }
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

            if isSessionEverStarted && !appState.userText.isEmpty && !mandalaModeEnabled {
                Button { callAppendToWritingJournalAndContinue() } label: {
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
                        Text("\(formatTime(seconds: duration))\(duration == selectedDurationInSeconds ? " ✔" : "")")
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
                if !saveStatusMessage.starts(with: "Saved to:") && !saveStatusMessage.contains("Mandala") {
                     saveStatusMessage = ""
                }
            } label: {
                Image(systemName: typewriterModeEnabled ? "character.cursor.ibeam" : "text.aligncenter")
                    .font(.system(size: 14))
                    .foregroundColor(typewriterModeButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI)
            }
            .buttonStyle(.plain)
            .onHover { typewriterModeButtonHover = $0 }

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
                if !appState.userText.isEmpty || mandalaModeEnabled {
                    showStartOverAlert = true
                } else {
                    actionResetApp(clearText: true)
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14))
                    .foregroundColor(resetButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: .command)
            .disabled(!isSessionEverStarted && appState.userText.isEmpty && !mandalaModeEnabled)
            .opacity((!isSessionEverStarted && appState.userText.isEmpty && !mandalaModeEnabled) ? 0.4 : 1.0)
            .onHover { resetButtonHover = $0 }
        }
        .frame(maxWidth: editorMaxWidth)
        .padding(.horizontal, mainContentHorizontalPadding)
        .padding(.bottom, controlBarPaddingBottom)
    }

    // MARK: - Helper Functions
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

    func isFullscreen() -> Bool {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return false }
        return window.styleMask.contains(.fullScreen)
    }

    // MARK: - Action Handlers
    func handleMainButtonAction() {
        if !isSessionEverStarted {
            actionStartFirstSession()
        } else if isTimerActive {
            actionPauseTimer()
        } else {
            if timeRemaining > 0 { actionResumeTimer() }
            else { actionStartNewSprintWithNewPrompt(clearExistingText: true) }
        }
        if !saveStatusMessage.starts(with: "Saved to:") && !saveStatusMessage.contains("Mandala") {
             saveStatusMessage = ""
        }
    }

    func actionStartFirstSession() {
        isSessionEverStarted = true
        currentPrompt = Prompts.words.randomElement() ?? "inspiration"
        appState.currentPromptForSaving = currentPrompt
        timeRemaining = selectedDurationInSeconds
        startActiveTimer()
        saveStatusMessage = ""
    }

    func actionPauseTimer() {
        stopActiveTimer()
        editorHasFocus = false
    }
    func actionResumeTimer() {
        startActiveTimer()
    }

    func actionStartNewSprintWithNewPrompt(clearExistingText: Bool) {
        isSessionEverStarted = true
        currentPrompt = Prompts.words.randomElement() ?? "next chapter"
        appState.currentPromptForSaving = currentPrompt
        timeRemaining = selectedDurationInSeconds
        if clearExistingText { appState.userText = "" }
        appState.isWorkSaved = true
        startActiveTimer()
        saveStatusMessage = ""
    }

    func actionResetApp(clearText: Bool) {
        stopActiveTimer()
        isSessionEverStarted = false
        currentPrompt = ""
        appState.currentPromptForSaving = ""
        if clearText { appState.userText = "" }
        appState.isWorkSaved = true
        timeRemaining = selectedDurationInSeconds
        saveStatusMessage = ""
        showStartOverAlert = false
        editorHasFocus = false
    }

    func startActiveTimer() {
        if isTimerActive { return }
        isTimerActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
        isTimerActive = false
        editorHasFocus = false
    }

    // MARK: - Alert Action Handlers
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
        appState.currentPromptForSaving = currentPrompt
        timeRemaining = selectedDurationInSeconds
        startActiveTimer()
        isSessionEverStarted = true
        saveStatusMessage = ""
    }

    // MARK: - Save Operation
    func callAppendToWritingJournalAndContinue() {
        if mandalaModeEnabled {
            saveStatusMessage = "Mandala Mode: Saving is disabled."
            return
        }
        if isTimerActive { actionPauseTimer() }
        guard !appState.userText.isEmpty else {
            saveStatusMessage = "Nothing to save."
            return
        }
        appendToWritingJournal(text: appState.userText, currentPrompt: self.currentPrompt) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let path):
                    self.saveStatusMessage = "Saved to: \(URL(fileURLWithPath: path).lastPathComponent)"
                    appState.workSuccessfullySaved()
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.domain == "AuthorciseApp.SaveOperation" && nsError.code == NSUserCancelledError {
                        self.saveStatusMessage = "Save cancelled."
                    } else {
                        self.saveStatusMessage = "Save failed: \(error.localizedDescription.prefix(100))"
                    }
                }
            }
        }
    }

    func callAppendToWritingJournalThenReset() {
        if mandalaModeEnabled {
            saveStatusMessage = "Mandala Mode: Saving is disabled. Work will be discarded."
            actionResetApp(clearText: true)
            return
        }
        if isTimerActive { actionPauseTimer() }
        guard !appState.userText.isEmpty else {
            actionResetApp(clearText: true)
            return
        }
        appendToWritingJournal(text: appState.userText, currentPrompt: self.currentPrompt) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let path):
                    self.saveStatusMessage = "Saved to: \(URL(fileURLWithPath: path).lastPathComponent)"
                    appState.workSuccessfullySaved()
                    self.actionResetApp(clearText: true)
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.domain == "AuthorciseApp.SaveOperation" && nsError.code == NSUserCancelledError {
                        self.saveStatusMessage = "Save cancelled. Not starting over."
                    } else {
                        self.saveStatusMessage = "Save failed: \(error.localizedDescription.prefix(100)). Not starting over."
                    }
                    self.showStartOverAlert = false
                }
            }
        }
    }
    
    // MARK: - Lifecycle and System Event Handlers
    private func handleOnAppear() {
         windowDelegate.appState = appState
            if !isSessionEverStarted {
                NotificationCenter.default.post(name: .writingSessionDidStop, object: nil)
                AppState.isCurrentSessionActive = false
                timeRemaining = selectedDurationInSeconds
            } else {
                NotificationCenter.default.post(name: .writingSessionDidStart, object: nil)
                AppState.isCurrentSessionActive = true
            }
            appState.currentPromptForSaving = currentPrompt
            NotificationCenter.default.addObserver(forName: .settingsWindowOpened, object: nil, queue: .main) { _ in
                if self.isTimerActive {
                    self.actionPauseTimer()
                }
            }
    }
    
    func toggleAppearance() {
        isDarkModeEnabled.toggle()
        if !saveStatusMessage.starts(with: "Saved to:") && !saveStatusMessage.contains("Mandala") { saveStatusMessage = "" }
    }

    func toggleFullscreen() {
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            window.toggleFullScreen(nil)
            forceViewUpdateForFullscreen.toggle()
        }
        if !saveStatusMessage.starts(with: "Saved to:") && !saveStatusMessage.contains("Mandala") { saveStatusMessage = "" }
    }
}

// String extension for truncating path
extension String {
    func truncatingPath(maxLength: Int = 50) -> String {
        if self.count > maxLength {
            return "..." + self.suffix(maxLength - 3)
        }
        return self
    }
}

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
    }
}

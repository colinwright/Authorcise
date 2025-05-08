import SwiftUI
import UniformTypeIdentifiers // Required for TextFile

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
    @State private var windowDelegate = WindowDelegate()

    // Date formatter for filenames
    private let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

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

            // Text editor container - Constrained width
            VStack {
                if isSessionEverStarted {
                    // Bind TextEditor to appState.userText
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


            // Bottom control bar - Also constrained width
            HStack(spacing: 15) {
                // Main action button
                Button { handleMainButtonAction() } label: {
                    Text(mainButtonText())
                        .font(.system(size: 13))
                        .foregroundColor(mainButtonHover ? controlBarHoverColor : secondaryTextColor)
                }
                .buttonStyle(.plain)
                .onHover { mainButtonHover = $0 }
                .keyboardShortcut(.space, modifiers: [])

                // Save button - Check appState.userText
                if isSessionEverStarted && !appState.userText.isEmpty {
                    Button { prepareAndShowFileExporter() } label: {
                        Text("Save Work")
                            .font(.system(size: 13))
                            .foregroundColor(saveButtonHover ? controlBarHoverColor : secondaryTextColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { saveButtonHover = $0 }
                    .keyboardShortcut("s", modifiers: .command)
                }

                Spacer()

                // Timer duration picker
                Menu {
                    ForEach(timerDurations, id: \.self) { duration in
                        Button {
                            let oldValue = selectedDurationInSeconds
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


                // Night Mode Toggle Button
                Button { toggleAppearance() } label: {
                    Image(systemName: isDarkModeEnabled ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 14))
                        .foregroundColor(appearanceButtonHover ? controlBarHoverColor : secondaryTextColor)
                }
                .buttonStyle(.plain)
                .onHover { appearanceButtonHover = $0 }

                // Fullscreen Toggle Button
                Button { toggleFullscreen() } label: {
                    Image(systemName: isFullscreen() ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundColor(fullscreenButtonHover ? controlBarHoverColor : secondaryTextColor)
                }
                .buttonStyle(.plain)
                .onHover { fullscreenButtonHover = $0 }

                // Start Over Button
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
        // Add the WindowAccessor as a background element to set the delegate
        .background(WindowAccessor(delegate: windowDelegate))
        // Alert for when timer runs out
        .alert("Time's up!", isPresented: $showPostTimerAlert) {
            Button("Keep Writing") { alertActionKeepWritingSamePromptNewTimer() }
            Button("Save my Work") { prepareAndShowFileExporter() }
            Button("New Prompt (Discards Current Text)") { alertActionNewPromptDiscardText() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your time is up. What would you like to do next?") }
        // Alert for starting over
        .alert("Start Over?", isPresented: $showStartOverAlert) {
            Button("Save and Start Over", role: .destructive) {
                prepareAndShowFileExporter()
                actionResetApp()
            }
            Button("Discard and Start Over", role: .destructive) {
                actionResetApp()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Starting over will end your current writing session. Do you want to save your work first?") }

        // Confirmation Dialog for Quitting (Bound to AppState)
        .confirmationDialog(
             "Quit Authorcise?",
             isPresented: $appState.showQuitConfirmation, // Triggered by AppState
             titleVisibility: .visible
        ) {
             Button("Save and Quit", role: .destructive) {
                 appState.isQuittingAfterSave = true
                 appState.prepareDocumentForSave()
                 appState.showFileExporter = true
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

        // File exporter sheet - Now uses AppState properties and handles quit logic
        .fileExporter(
            isPresented: $appState.showFileExporter, // Bind to AppState
            document: appState.documentToSave,      // Use document from AppState
            contentType: .plainText,
            defaultFilename: "Authorcise_\(fileNameDateFormatter.string(from: Date())).txt"
        ) { result in
            let wasQuitting = appState.isQuittingAfterSave

            switch result {
            case .success:
                print("Successfully saved.")
                appState.workSaved()
                if wasQuitting {
                     NSApplication.shared.terminate(nil)
                }
            case .failure(let error):
                print("Save failed: \(error.localizedDescription)")
                 if wasQuitting {
                     print("Save failed, cancelling termination.")
                     appState.cancelQuitAfterSaveAttempt()
                 }
                 // Optionally show user an error alert here
            }
             if appState.showFileExporter {
                 appState.showFileExporter = false
             }
        }
        .onAppear {
            // Pass the appState to the delegate when the view appears
            windowDelegate.appState = appState
            if !isSessionEverStarted {
                timeRemaining = selectedDurationInSeconds
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
        // Changed button text
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
    }

    func actionStartFirstSession() {
        isSessionEverStarted = true
        currentPrompt = Prompts.words.randomElement() ?? "inspiration"
        timeRemaining = selectedDurationInSeconds
        startActiveTimer()
        focusEditor()
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
        // appState.userText = "" // Keep text unless user chooses discard option
        startActiveTimer()
        focusEditor()
    }

    // Reset function now uses AppState
    func actionResetApp() {
        stopActiveTimer()
        isSessionEverStarted = false
        isTimerActive = false
        currentPrompt = ""
        appState.userText = "" // Reset text in AppState
        timeRemaining = selectedDurationInSeconds
        editorHasFocus = false
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
    }

    func alertActionNewPromptDiscardText() {
        stopActiveTimer()
        editorHasFocus = false
        appState.userText = "" // Reset text in AppState
        currentPrompt = Prompts.words.randomElement() ?? "fresh start"
        timeRemaining = selectedDurationInSeconds
        isTimerActive = false
    }

    // MARK: - File Operations

    // Updated to use AppState
    func prepareAndShowFileExporter() {
        if isTimerActive {
            stopActiveTimer()
            editorHasFocus = false
        }
        // Prepare document in AppState
        appState.prepareDocumentForSave()
        // Trigger exporter via AppState
        appState.showFileExporter = true
    }

    func focusEditor() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.editorHasFocus = true
        }
    }

    // --- New Feature Actions ---

    // Simplified toggle function
    func toggleAppearance() {
        isDarkModeEnabled.toggle()
    }

    // Updated toggleFullscreen to trigger view update
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
            .environmentObject(AppState()) // Provide dummy state for preview
            .environment(\.colorScheme, .light)
        ContentView()
            .environmentObject(AppState()) // Provide dummy state for preview
            .environment(\.colorScheme, .dark)
    }
}

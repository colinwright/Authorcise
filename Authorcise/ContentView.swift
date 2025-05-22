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
    @AppStorage(UserDefaultKeys.typewriterModeEnabled) private var typewriterModeEnabled: Bool = false // Default OFF [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

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
    private var appBackgroundColor: Color { colorScheme == .dark ? Color(NSColor.textBackgroundColor) : Color(NSColor.textBackgroundColor) } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private var primaryTextColorSwiftUI: Color { colorScheme == .dark ? .white.opacity(0.95) : .black } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private var secondaryTextColorSwiftUI: Color { colorScheme == .dark ? .gray.opacity(0.8) : .gray } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private var controlBarHoverColorSwiftUI: Color { colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.7) } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    
    private let editorFontSwiftUI = Font.custom("Lato-Regular", size: 18) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private let editorLineSpacing: CGFloat = 9 // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private let editorMaxWidth: CGFloat = 750 // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    // Padding for the TextEditor content area itself
    private let textEditorContentHorizontalPadding: CGFloat = 5 // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private let textEditorContentVerticalPadding: CGFloat = 10 // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

    private let mainContentHorizontalPadding: CGFloat = 40 // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private let mainContentVerticalPadding: CGFloat = 30 // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private let controlBarPaddingBottom: CGFloat = 20 // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private let accentColorLight = Color(hex: "#A1CDF4") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private let accentColorDark = Color(hex: "#C1DDF7") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    private var currentAccentColor: Color { colorScheme == .dark ? accentColorDark : accentColorLight } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    let timerDurations: [Int] = [60, 120, 300, 600, 900, 1800] // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    
    var body: some View {
        let _ = forceViewUpdateForFullscreen // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

        VStack(spacing: 25) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            topInfoBar // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            editorSection // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            
            if !saveStatusMessage.isEmpty { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                saveStatusTextView // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            
            bottomControlBar // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .background(appBackgroundColor) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .edgesIgnoringSafeArea(.all) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .background(WindowAccessor(delegate: windowDelegate)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .alert("Time's up!", isPresented: $showPostTimerAlert) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            Button("Keep Writing") { alertActionKeepWritingSamePromptNewTimer() } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            Button("Save My Work") { callSaveTextFile() } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            Button("New Prompt (Don't Save)") { alertActionNewPromptDiscardText() } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            Button("Cancel", role: .cancel) {} // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        } message: { Text("Your time is up. What would you like to do next?") } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .alert("Start Over?", isPresented: $showStartOverAlert) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            Button("Save and Start Over", role: .destructive) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                callSaveTextFile() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                actionResetApp() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            Button("Discard and Start Over", role: .destructive) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                actionResetApp() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            Button("Cancel", role: .cancel) {} // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        } message: { Text("Starting over will end your current writing session. Do you want to save your work first?") } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .confirmationDialog( // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
             "Quit Authorcise?", // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
             isPresented: $appState.showQuitConfirmation, // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
             titleVisibility: .visible // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        ) {
             Button("Save and Quit", role: .destructive) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                 appState.handleSaveAndQuit() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
             }
             Button("Discard and Quit", role: .destructive) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                 NSApplication.shared.terminate(nil) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
             }
             Button("Cancel", role: .cancel) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                 appState.cancelQuitAfterSaveAttempt() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
             }
        } message: { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
             Text("You have unsaved changes. Do you want to save before quitting?") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }
        .fileExporter( // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            isPresented: $appState.showFileExporter, // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            document: appState.documentToSave, // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            contentType: .plainText, // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            defaultFilename: generateFileName(forPrompt: currentPrompt, includeExtension: true) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        ) { result in
            handleFileExporterResult(result) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }
        .onAppear { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            handleOnAppear() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }
    }

    private var topInfoBar: some View {
        HStack(spacing: 4) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            if isSessionEverStarted { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Text("Prompt:") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 13)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Text(currentPrompt) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 13)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(currentAccentColor) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Text(" / ") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 13)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Text("Time:") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 13)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Text(formatTime(seconds: timeRemaining)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 13)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(isTimerActive ? currentAccentColor : secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .frame(minWidth: 45, alignment: .leading) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            } else {
                Text("Select duration, then click 'Start Writing'.") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 13)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
        }
        .padding(.top, mainContentVerticalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .frame(minHeight: 30) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .frame(maxWidth: editorMaxWidth) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .padding(.horizontal, mainContentHorizontalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    private var editorSection: some View {
        VStack { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            if isSessionEverStarted { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                if typewriterModeEnabled { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    GeometryReader { geometry in // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        ScrollViewReader { scrollProxy in // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                            ScrollView(.vertical, showsIndicators: false) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                TextEditor(text: $appState.userText) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .font(editorFontSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .foregroundColor(primaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .lineSpacing(editorLineSpacing) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .padding(.horizontal, textEditorContentHorizontalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .padding(.vertical, textEditorContentVerticalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .frame(width: geometry.size.width) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .padding(.top, geometry.size.height * 0.25) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .padding(.bottom, geometry.size.height * 0.70) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .focused($editorHasFocus) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .disabled(!isTimerActive) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .opacity(isTimerActive ? 1.0 : 0.6) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .background(appBackgroundColor) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .id("paddedTextEditor") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    .scrollDisabled(true) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                            }
                            // MODIFIED .onChange to ensure macOS 13 compatibility
                            .onChange(of: appState.userText) { _ in // Use `_ in` or `newText in`
                                print("Typewriter mode: Scrolling paddedTextEditor to bottom (onChange).") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                scrollProxy.scrollTo("paddedTextEditor", anchor: .bottom) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                            }
                            .onAppear { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                if !appState.userText.isEmpty { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    DispatchQueue.main.async { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                        print("Typewriter mode: Scrolling paddedTextEditor to bottom (onAppear).")
                                        scrollProxy.scrollTo("paddedTextEditor", anchor: .bottom) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Standard SwiftUI TextEditor (Non-Typewriter Mode)
                    TextEditor(text: $appState.userText) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .font(editorFontSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .foregroundColor(primaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .lineSpacing(editorLineSpacing) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .padding(.horizontal, textEditorContentHorizontalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .padding(.vertical, textEditorContentVerticalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .frame(maxHeight: .infinity) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .focused($editorHasFocus) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .disabled(!isTimerActive) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .opacity(isTimerActive ? 1.0 : 0.6) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .scrollContentBackground(.hidden) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .background(appBackgroundColor) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                }
            } else {
                // Placeholder view when session hasn't started
                Rectangle() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .fill(appBackgroundColor) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .frame(maxHeight: .infinity) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .padding(.horizontal, mainContentHorizontalPadding + textEditorContentHorizontalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .padding(.vertical, mainContentVerticalPadding + textEditorContentVerticalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .overlay( // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        Text(typewriterModeEnabled ? "Typewriter Mode is ON" : "Typewriter Mode is OFF") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                            .font(.caption) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                            .foregroundColor(secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                            .padding(.bottom, 20), // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        alignment: .bottom // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    )
            }
        }
        .frame(maxWidth: editorMaxWidth) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .padding(.horizontal, mainContentHorizontalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }
    
    private var saveStatusTextView: some View {
         Text(saveStatusMessage) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .font(.caption) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .foregroundColor(secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .padding(.horizontal, mainContentHorizontalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .frame(maxWidth: editorMaxWidth, alignment: .leading) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .onTapGesture { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
    }

    private var bottomControlBar: some View {
        HStack(spacing: 15) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            Button { handleMainButtonAction() } label: { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Text(mainButtonText()) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 13)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(mainButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            .buttonStyle(.plain) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .onHover { mainButtonHover = $0 } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .keyboardShortcut(.space, modifiers: []) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

            if isSessionEverStarted && !appState.userText.isEmpty { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Button { callSaveTextFile() } label: { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    Text("Save Work") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .font(.system(size: 13)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        .foregroundColor(saveButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                }
                .buttonStyle(.plain) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                .onHover { saveButtonHover = $0 } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                .keyboardShortcut("s", modifiers: .command) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }

            Spacer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

            Menu { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                ForEach(timerDurations, id: \.self) { duration in // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    Button { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        selectedDurationInSeconds = duration // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        if !isSessionEverStarted { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                            timeRemaining = duration // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        }
                    } label: { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        Text("\(formatTime(seconds: duration))\(duration == selectedDurationInSeconds ? " *" : "")") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    }
                }
            } label: { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                 Text(formatTime(seconds: selectedDurationInSeconds)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 13)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(durationMenuHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .frame(minWidth: 45, alignment: .leading) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            .buttonStyle(.plain) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .onHover { durationMenuHover = $0 } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .disabled(isSessionEverStarted) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .opacity(isSessionEverStarted ? 0.4 : 1.0) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

            Button { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                typewriterModeEnabled.toggle() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                if !saveStatusMessage.starts(with: "Saved to:") { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                     saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                }
            } label: { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Image(systemName: typewriterModeEnabled ? "character.cursor.ibeam" : "text.aligncenter") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 14)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(typewriterModeButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            .buttonStyle(.plain) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .onHover { typewriterModeButtonHover = $0 } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .disabled(isSessionEverStarted) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .opacity(isSessionEverStarted ? 0.4 : 1.0) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

            Button { toggleAppearance() } label: { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Image(systemName: isDarkModeEnabled ? "sun.max.fill" : "moon.fill") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 14)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(appearanceButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            .buttonStyle(.plain) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .onHover { appearanceButtonHover = $0 } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

            Button { toggleFullscreen() } label: { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Image(systemName: isFullscreen() ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 14)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(fullscreenButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            .buttonStyle(.plain) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .onHover { fullscreenButtonHover = $0 } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

            Button { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                if isTimerActive { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    stopActiveTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                }
                showStartOverAlert = true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            } label: { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                Image(systemName: "arrow.counterclockwise") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .font(.system(size: 14)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    .foregroundColor(resetButtonHover ? controlBarHoverColorSwiftUI : secondaryTextColorSwiftUI) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            .buttonStyle(.plain) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .keyboardShortcut("r", modifiers: .command) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .disabled(!isSessionEverStarted) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .opacity(!isSessionEverStarted ? 0.4 : 1.0) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .onHover { resetButtonHover = $0 } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

        }
        .frame(maxWidth: editorMaxWidth) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .padding(.horizontal, mainContentHorizontalPadding) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        .padding(.bottom, controlBarPaddingBottom) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func formatTime(seconds: Int) -> String { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        let minutes = seconds / 60 // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        let remainingSeconds = seconds % 60 // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        return String(format: "%02d:%02d", minutes, remainingSeconds) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func mainButtonText() -> String { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        if !isSessionEverStarted { return "Start Writing" } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        if isTimerActive { return "Pause Writing" } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        if timeRemaining > 0 { return "Resume Writing" } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        return "Start New Writing" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func handleMainButtonAction() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        if !isSessionEverStarted { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            actionStartFirstSession() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        } else if isTimerActive { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            actionPauseTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        } else { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            if timeRemaining > 0 { actionResumeTimer() } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            else { actionStartNewSprintWithNewPrompt() } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }
        if !saveStatusMessage.starts(with: "Saved to:") { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
             saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }
    }

    func actionStartFirstSession() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        isSessionEverStarted = true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        currentPrompt = Prompts.words.randomElement() ?? "inspiration" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        timeRemaining = selectedDurationInSeconds // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        startActiveTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func actionPauseTimer() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        stopActiveTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func actionResumeTimer() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        startActiveTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func actionStartNewSprintWithNewPrompt() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        currentPrompt = Prompts.words.randomElement() ?? "next chapter" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        timeRemaining = selectedDurationInSeconds // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        appState.userText = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        appState.isWorkSaved = true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        startActiveTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func actionResetApp() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        stopActiveTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        isSessionEverStarted = false // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        currentPrompt = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        appState.userText = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        appState.isWorkSaved = true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        timeRemaining = selectedDurationInSeconds // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func startActiveTimer() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        if isTimerActive { return } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        
        isTimerActive = true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        print("ContentView: startActiveTimer - isTimerActive set to true.") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            print("ContentView: startActiveTimer (delayed) - Setting editorHasFocus = true") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            self.editorHasFocus = true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            if self.timeRemaining > 0 { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                self.timeRemaining -= 1 // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            } else { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                self.stopActiveTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                self.showPostTimerAlert = true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
        }
    }

    func stopActiveTimer() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        timer?.invalidate() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        timer = nil // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        
        let wasActive = isTimerActive // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        
        if wasActive { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            print("ContentView: stopActiveTimer - Setting editorHasFocus = false") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            self.editorHasFocus = false // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }
        
        isTimerActive = false // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        print("ContentView: stopActiveTimer - isTimerActive set to false.") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func alertActionKeepWritingSamePromptNewTimer() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        timeRemaining = selectedDurationInSeconds // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        startActiveTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func alertActionNewPromptDiscardText() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        stopActiveTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        appState.userText = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        appState.isWorkSaved = true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        currentPrompt = Prompts.words.randomElement() ?? "fresh start" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        timeRemaining = selectedDurationInSeconds // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }
    
    func generateFileName(forPrompt prompt: String, includeExtension: Bool = false) -> String { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        let defaults = UserDefaults.standard // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        let useDefaultStructure = defaults.object(forKey: UserDefaultKeys.filenameUseDefaultStructure) as? Bool ?? true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        
        var nameParts: [String] = [] // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        let now = Date() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        
        let promptSanitized = prompt.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        let safePrompt = promptSanitized.isEmpty || promptSanitized == "_" ? "Writing" : promptSanitized // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

        if useDefaultStructure { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            let defaultFormatter = DateFormatter() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            defaultFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            nameParts.append("Authorcise") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            nameParts.append(safePrompt) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            nameParts.append(defaultFormatter.string(from: now)) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        } else { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            let componentOrder: [FilenameComponent] // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            if let data = defaults.data(forKey: UserDefaultKeys.filenameComponentOrder), // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
               let decodedOrder = try? JSONDecoder().decode([FilenameComponent].self, from: data) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                componentOrder = decodedOrder // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            } else { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                componentOrder = FilenameComponent.allCases // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }

            let includePrefix = defaults.object(forKey: UserDefaultKeys.filenameIncludeAuthorcisePrefix) as? Bool ?? true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            let includePromptFlag = defaults.object(forKey: UserDefaultKeys.filenameIncludePrompt) as? Bool ?? true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            let includeDateFlag = defaults.object(forKey: UserDefaultKeys.filenameIncludeDate) as? Bool ?? true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            let includeTimeFlag = defaults.object(forKey: UserDefaultKeys.filenameIncludeTime) as? Bool ?? true // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            let includeCustomPrefix = defaults.object(forKey: UserDefaultKeys.filenameIncludeCustomPrefix) as? Bool ?? false // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            let customPrefixString = defaults.string(forKey: UserDefaultKeys.filenameCustomPrefixString) ?? "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            
            let safeCustomPrefix = customPrefixString // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                .trimmingCharacters(in: .whitespacesAndNewlines) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

            let dateFormatter = DateFormatter() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            var dateString = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            if includeDateFlag { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                dateFormatter.dateFormat = "yyyy-MM-dd" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                dateString = dateFormatter.string(from: now) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }

            let timeFormatter = DateFormatter() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            var timeString = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            if includeTimeFlag { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                timeFormatter.dateFormat = "HH-mm-ss" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                timeString = timeFormatter.string(from: now) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            
            for component in componentOrder { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                switch component { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                case .authorcisePrefix: // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    if includePrefix { nameParts.append("Authorcise") } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                case .customPrefix: // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    if includeCustomPrefix && !safeCustomPrefix.isEmpty { nameParts.append(safeCustomPrefix) } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                case .prompt: // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    if includePromptFlag { nameParts.append(safePrompt) } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                case .date: // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    if includeDateFlag && !dateString.isEmpty { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        nameParts.append(dateString) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    }
                case .time: // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    if includeTimeFlag && !timeString.isEmpty { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        nameParts.append(timeString) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    }
                }
            }
        }
        
        let baseName = nameParts.filter { !$0.isEmpty }.joined(separator: "_") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        let finalBaseName = baseName.isEmpty ? "Authorcise_Save" : baseName // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        return includeExtension ? finalBaseName + ".txt" : finalBaseName // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func callSaveTextFile() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        if isTimerActive { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            actionPauseTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }

        let contentToSave = appState.userText // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        let fileNameWithoutExtension = generateFileName(forPrompt: currentPrompt, includeExtension: false) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

        saveTextFile(content: contentToSave, preferredFileName: fileNameWithoutExtension) { result in // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            DispatchQueue.main.async { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                switch result { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                case .success(let path): // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    print("ContentView: Successfully saved to: \(path)") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    self.saveStatusMessage = "Saved to: \(path.truncatingPath())" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    appState.workSaved() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                case .failure(let error): // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    print("ContentView: Save failed: \(error.localizedDescription)") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    let nsError = error as NSError // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    if nsError.domain == "AuthorciseApp.SaveOperation" && nsError.code == NSUserCancelledError { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        self.saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    } else if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                         self.saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    }
                    else { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                        self.saveStatusMessage = "Save failed: \(error.localizedDescription)" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    }
                }
            }
        }
    }
    
    private func handleFileExporterResult(_ result: Result<URL, Error>) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
         let wasQuitting = appState.isQuittingAfterSave // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

            switch result { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            case .success(let url): // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                print("ContentView: .fileExporter saved to: \(url.path)") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                appState.workSaved() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                saveStatusMessage = "Saved to: \(url.path.truncatingPath())" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                if wasQuitting { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                     NSApplication.shared.terminate(nil) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                }
            case .failure(let error): // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                print("ContentView: .fileExporter save failed: \(error.localizedDescription)") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                let nsError = error as NSError // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                if !(nsError.domain == "AuthorciseApp.SaveOperation" && nsError.code == NSUserCancelledError) && // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                   !(nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError) { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    saveStatusMessage = "Save failed: \(error.localizedDescription)" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                } else { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    saveStatusMessage = "" // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                }
                 if wasQuitting { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                     print("ContentView: Save via .fileExporter failed during quit, cancelling termination.") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                     appState.cancelQuitAfterSaveAttempt() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                 }
            }
             if appState.showFileExporter { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                 appState.showFileExporter = false // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
             }
             if wasQuitting && !appState.showFileExporter { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                if appState.isQuittingAfterSave { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    appState.isQuittingAfterSave = false // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                }
             }
    }
    
    private func handleOnAppear() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
         windowDelegate.appState = appState // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            if !isSessionEverStarted { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                timeRemaining = selectedDurationInSeconds // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            NotificationCenter.default.addObserver(forName: .settingsWindowOpened, object: nil, queue: .main) { _ in // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                if self.isTimerActive { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    print("ContentView: Settings window opened, pausing timer.") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                    self.actionPauseTimer() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                }
            }
    }
    
    func toggleAppearance() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        isDarkModeEnabled.toggle() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        if !saveStatusMessage.starts(with: "Saved to:") { saveStatusMessage = "" } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func toggleFullscreen() { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        if let window = NSApp.keyWindow ?? NSApp.windows.first { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            window.toggleFullScreen(nil) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            forceViewUpdateForFullscreen.toggle() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }
        if !saveStatusMessage.starts(with: "Saved to:") { saveStatusMessage = "" } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }

    func isFullscreen() -> Bool { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return false } // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        return window.styleMask.contains(.fullScreen) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }
}
// --- END OF CONTENTVIEW STRUCT ---

// --- ENSURE THIS EXTENSION IS DEFINED ONLY ONCE (IF NOT ALREADY PART OF ANOTHER FILE) ---
// Helper extension to truncate file paths for display (moved here for clarity if it was duplicated)
extension String {
    func truncatingPath(maxLength: Int = 50) -> String { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        if self.count > maxLength { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            return "..." + self.suffix(maxLength - 3) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        }
        return self // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }
}
// --- END OF STRING EXTENSION ---

// Preview provider needs EnvironmentObject
// --- ENSURE THIS STRUCT IS DEFINED ONLY ONCE ---
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

        ContentView() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .environmentObject(appState) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .environment(\.colorScheme, .light) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .previewDisplayName("Light Mode") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

        ContentView() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .environmentObject(appState) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .environment(\.colorScheme, .dark) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .previewDisplayName("Dark Mode") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]

        ContentView() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .environmentObject(appState) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .environment(\.colorScheme, .light) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .onAppear { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                UserDefaults.standard.set(true, forKey: UserDefaultKeys.typewriterModeEnabled) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            .previewDisplayName("Typewriter ON (Light)") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
        
        ContentView() // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .environmentObject(appState) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .environment(\.colorScheme, .dark) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            .onAppear { // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
                UserDefaults.standard.set(true, forKey: UserDefaultKeys.typewriterModeEnabled) // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
            }
            .previewDisplayName("Typewriter ON - Session (Dark)") // [cite: colinwright/authorcise/Authorcise-23b3fce9bc82b08a123cdf6efd47070eca407d4d/Authorcise/ContentView.swift]
    }
}
// --- END OF CONTENTVIEW_PREVIEWS STRUCT ---

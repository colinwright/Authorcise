import SwiftUI
import AppKit // Required for NSApp.applicationIconImage

struct AboutView: View {
    // Environment variable to dismiss the window if needed (though typically About windows are just closed by the user)
    @Environment(\.dismiss) var dismiss

    // Attributed string for the typeface license text
    private var typefaceLicenseText: AttributedString {
        var attributedString = AttributedString("This app uses the Lato typeface, which is generously provided for free by Warsaw-based designer Łukasz Dziedzic, under the ")

        var linkString = AttributedString("SIL Open Font License")
        if let url = URL(string: "https://openfontlicense.org/") {
            linkString.link = url
            linkString.underlineStyle = .single
            linkString.foregroundColor = .blue
        }
        attributedString.append(linkString)
        attributedString.append(AttributedString("."))

        return attributedString
    }

    // Attributed string for the "About me" link
    private var aboutMeLinkText: AttributedString {
        var linkString = AttributedString("About me and my work")
        if let url = URL(string: "https://colin.io") {
            linkString.link = url
            linkString.underlineStyle = .single
            linkString.foregroundColor = .blue
        }
        // Add a period that is not part of the link
        var finalAttributedString = AttributedString()
        finalAttributedString.append(linkString)
        finalAttributedString.append(AttributedString("."))
        return finalAttributedString
    }

    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            // App Icon
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
            }

            // App Name
            Text(appName)
                .font(.largeTitle)
                .fontWeight(.bold)

            // Version and Build Number
            Text("Version \(appVersion) (Build \(appBuildNumber))")
                .font(.callout)
                .foregroundColor(.secondary)

            // Copyright Information
            Text(appCopyright)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            // Main description - split into two paragraphs with updated text
            VStack(alignment: .leading, spacing: 8) {
                // Updated first paragraph
                Text("I made Authorcise to help with the establishment and maintenance of a daily writing ritual.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Updated second paragraph
                Text("Consider using it around the same time every day and writing about whatever comes to mind (using the randomized prompt word as inspiration, if you like). While saving your work is an option, consider leaning into temporality and training your brain to think of words as cheap and disposable: they're not finite or precious, and are therefore not worth stressing over.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)

            // "About me and my work" link as AttributedString
            VStack(alignment: .leading, spacing: 8) {
                 Text(aboutMeLinkText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)

            // Typeface information and link using AttributedString
            VStack(alignment: .leading, spacing: 8) {
                Text(typefaceLicenseText)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)


            Spacer()

        }
        .padding(20)
        // Current frame size, can be adjusted if needed after text changes
        .frame(minWidth: 350, idealWidth: 400, maxWidth: 480,
               minHeight: 530, idealHeight: 560, maxHeight: 650)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // Helper computed properties to fetch bundle information
    private var appName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
               Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Authorcise"
    }

    private var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }

    private var appBuildNumber: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }

    private var appCopyright: String {
        let currentYear = Calendar.current.component(.year, from: Date())
        return "© \(currentYear) Colin Wright. All rights reserved."
    }
}

// Preview provider for AboutView
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
            .previewDisplayName("About View - Light")
            .environment(\.colorScheme, .light)

        AboutView()
            .previewDisplayName("About View - Dark")
            .environment(\.colorScheme, .dark)
    }
}

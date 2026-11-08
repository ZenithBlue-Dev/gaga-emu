import SwiftUI

/// Settings > About > Guides: short how-tos that work offline.
struct GuidesView: View {
    private struct Guide: Identifiable {
        let title: String
        let steps: [String]
        var id: String { title }
    }

    private let guides = [
        Guide(title: "Add games", steps: [
            "Open Add and choose Choose from Files. Pick a .cue together with its .bin files.",
            "You can also drop files on the Library, turn on WiFi Transfer, or read a file from the clipboard.",
            "Add only games you have the right to use. GagaEmu comes with no games."
        ]),
        Guide(title: "Network folders", steps: [
            "WebDAV: open Add, then WebDAV Server, and enter your own server. Your sign-in stays in this device's Keychain.",
            "SMB: in the Files app open the three-dot menu, choose Connect to Server and sign in. Then use Choose from Files in Add and pick the share."
        ]),
        Guide(title: "Controllers", steps: [
            "Pair the controller in iOS Settings under Bluetooth. It appears in Settings under Controls.",
            "A new controller takes the next free player. Change this in the Library's sort menu under Controllers.",
            "Controller Mapping changes what each button does, for every game or for one."
        ]),
        Guide(title: "Cheats", steps: [
            "While playing, pause and choose Cheats. Add a code, then turn it on.",
            "The system's core decides whether a code is valid. A system without cheat support says so in the pause menu."
        ]),
        Guide(title: "Touch controls and skins", steps: [
            "Go to Settings, Controls, Touch Layout. Choose a layout for each system, or Edit to move and resize its buttons.",
            "In the editor, Import reads a layout file exported from GagaEmu, or the button positions of your own .manicskin or .deltaskin file. The file's art is not used.",
            "Touch and hold a game in the Library to give that game its own skin."
        ])
    ]

    var body: some View {
        PaperSheet(title: "Guides") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(guides) { guide in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(guide.title)).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        ForEach(guide.steps, id: \.self) { step in
                            Text(LocalizedStringKey(step)).font(.footnote).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

import SwiftUI

struct SettingsView: View {
    @AppStorage("hyperKeyEnabled") private var hyperKeyEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Enable HyperKey", isOn: $hyperKeyEnabled)
                    .help("Remap Caps Lock to Hyper (Cmd+Ctrl+Opt+Shift)")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How it works")
                        .font(.headline)

                    Text("HyperKey remaps your Caps Lock key to act as a \"Hyper\" key - pressing Cmd+Ctrl+Opt+Shift simultaneously.")
                        .foregroundColor(.secondary)

                    Text("This allows you to create powerful, unique keyboard shortcuts that won't conflict with any application.")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Button("Open Accessibility Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}

#Preview {
    SettingsView()
}

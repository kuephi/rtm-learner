import SwiftUI

struct LogView: View {
    let appLog: AppLog

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Last Run Log")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    appLog.clear()
                }
            }
            .padding()

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(appLog.text.isEmpty ? "(no log yet)" : appLog.text)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("logBottom")
                }
                .onChange(of: appLog.text) { _, _ in
                    proxy.scrollTo("logBottom", anchor: .bottom)
                }
            }
        }
    }
}

import SwiftUI

struct AuthView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var sessionCookie: String = ""
    @State private var sessionStatus: String = "Unknown"
    @State private var isRefreshing = false
    @State private var refreshError: String? = nil

    var body: some View {
        Form {
            Section("Substack Account") {
                TextField("Email", text: $email)
                    .onChange(of: email) { _, v in try? KeychainHelper.save(v, for: "substack_email") }
                SecureField("Password", text: $password)
                    .onChange(of: password) { _, v in try? KeychainHelper.save(v, for: "substack_password") }
            }

            Section {
                HStack {
                    Text(sessionStatus)
                        .foregroundStyle(sessionStatus.contains("Active") ? .green : .orange)
                    Spacer()
                    Button(isRefreshing ? "Refreshing…" : "Refresh Session") {
                        Task { await refreshSession() }
                    }
                    .disabled(isRefreshing)
                }
                if let error = refreshError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Session")
            } footer: {
                Text("If automatic refresh fails (Substack may block API logins), paste your substack.sid cookie from browser DevTools below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Manual Cookie Fallback") {
                SecureField("substack.sid value", text: $sessionCookie)
                    .font(.system(.body, design: .monospaced))
                Button("Save Cookie") { saveCookieManually() }
                    .disabled(sessionCookie.isEmpty)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loadCredentials)
    }

    private func loadCredentials() {
        email    = (try? KeychainHelper.load(for: "substack_email"))    ?? ""
        password = (try? KeychainHelper.load(for: "substack_password")) ?? ""
        updateSessionStatus()
    }

    private func updateSessionStatus() {
        if let _ = try? KeychainHelper.load(for: "substack_session") {
            sessionStatus = "Active (cookie present)"
        } else {
            sessionStatus = "No session cookie — refresh or paste manually"
        }
    }

    private func refreshSession() async {
        isRefreshing = true
        refreshError = nil
        do {
            let email    = try KeychainHelper.load(for: "substack_email")
            let password = try KeychainHelper.load(for: "substack_password")
            let cookie   = try await SubstackAuth.login(email: email, password: password)
            try KeychainHelper.save(cookie, for: "substack_session")
            updateSessionStatus()
        } catch SubstackAuthError.blocked {
            refreshError = "Substack blocked the API login. Paste your substack.sid cookie manually from browser DevTools (Application → Cookies → substack.com)."
        } catch {
            refreshError = error.localizedDescription
        }
        isRefreshing = false
    }

    private func saveCookieManually() {
        try? KeychainHelper.save(sessionCookie, for: "substack_session")
        sessionCookie = ""
        updateSessionStatus()
    }
}

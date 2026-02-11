import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiToken = ""
    @State private var isLoading = false
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.xaxis.ascending")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                            .padding()
                            .background(
                                Circle()
                                    .fill(.blue.opacity(0.1))
                                    .frame(width: 120, height: 120)
                            )

                        Text("Todoist Dashboard")
                            .font(.system(size: 28, weight: .bold, design: .rounded))

                        Text("View your project progress, team workload, and productivity analytics")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)

                    // Token Input
                    VStack(alignment: .leading, spacing: 12) {
                        Label("API Token", systemImage: "key")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        SecureField("Paste your Todoist API token", text: $apiToken)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button {
                            showInfo.toggle()
                        } label: {
                            Label("Where to find your token?", systemImage: "questionmark.circle")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 24)

                    if showInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to get your API token:")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            tokenStep("1", "Open Todoist app or todoist.com")
                            tokenStep("2", "Go to Settings → Integrations → Developer")
                            tokenStep("3", "Copy your API token")
                        }
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 24)
                    }

                    // Error
                    if let error = appState.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 24)
                    }

                    // Connect Button
                    Button {
                        connect()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isLoading ? "Connecting..." : "Connect to Todoist")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(apiToken.isEmpty ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(apiToken.isEmpty || isLoading)
                    .padding(.horizontal, 24)

                    // Privacy note
                    VStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)
                        Text("Your token is stored securely in Keychain")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("All data is processed locally on your device")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func tokenStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.blue))
            Text(text)
                .font(.caption)
        }
    }

    private func connect() {
        guard !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        appState.errorMessage = nil

        Task {
            await appState.authenticate(with: apiToken.trimmingCharacters(in: .whitespacesAndNewlines))
            isLoading = false
        }
    }
}

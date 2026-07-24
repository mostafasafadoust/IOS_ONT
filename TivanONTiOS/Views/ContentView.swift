import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BootstrapperViewModel()
    @StateObject private var webSession = HuaweiWebSession()
    @State private var showAdvanced = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    statusCard
                    settingsCard
                    logCard
                    WebAutomationView(session: webSession)
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .accessibilityHidden(true)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tivan ONT")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("پاک‌سازی") {
                        viewModel.reset()
                    }
                    .disabled(viewModel.isRunning)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("کاستومایزر Huawei ONT")
                .font(.title2.weight(.bold))
            Text("نسخه iOS بر پایه منطق Windows Bootstrapper v1.0.5")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                viewModel.start(using: webSession)
            } label: {
                HStack {
                    if viewModel.isRunning {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isRunning ? "در حال اجرا" : "شروع تنظیم مودم")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isRunning)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.statusTitle)
                    .font(.headline)
                Spacer()
                statusBadge
            }
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
            Text("ONT: \(viewModel.configuration.ontHost)  |  WAN VLAN \(viewModel.configuration.vlanID)")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var statusBadge: some View {
        Group {
            if viewModel.succeeded == true {
                Text("موفق")
                    .foregroundStyle(.green)
            } else if viewModel.succeeded == false {
                Text("خطا")
                    .foregroundStyle(.red)
            } else if viewModel.isRunning {
                Text("فعال")
                    .foregroundStyle(.blue)
            } else {
                Text("آماده")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("تنظیمات")
                    .font(.headline)
                Spacer()
                Toggle("پیشرفته", isOn: $showAdvanced)
                    .labelsHidden()
            }

            textField("IP مودم", text: $viewModel.configuration.ontHost)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Toggle("فقط Telnet و ثبت hw_default_ctree.xml", isOn: $viewModel.configuration.telnetOnly)
                .disabled(viewModel.isRunning)

            if showAdvanced {
                Divider()
                textField("کاربر وب", text: $viewModel.configuration.webUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                secureField("رمز وب", text: $viewModel.configuration.webPassword)
                textField("PPPoE User", text: $viewModel.configuration.pppoeUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                secureField("PPPoE Pass", text: $viewModel.configuration.pppoePassword)
                textField("VLAN", text: $viewModel.configuration.vlanID)
                    .keyboardType(.numberPad)
                textField("ACS URL", text: $viewModel.configuration.acsURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                textField("ACS User", text: $viewModel.configuration.acsUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                secureField("ACS Pass", text: $viewModel.configuration.acsPassword)
                textField("Inform Interval", text: $viewModel.configuration.informInterval)
                    .keyboardType(.numberPad)
                textField("Telnet User", text: $viewModel.configuration.telnetUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                VStack(alignment: .leading, spacing: 6) {
                    Text("رمزهای Telnet، هر خط یک رمز")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $viewModel.configuration.telnetPasswordsText)
                        .font(.body.monospaced())
                        .frame(minHeight: 84)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Toggle("تلاش برای فعال‌سازی Telnet از پنل وب", isOn: $viewModel.configuration.enableRemoteAccessPage)
                    .disabled(viewModel.isRunning)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .disabled(viewModel.isRunning)
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("گزارش اجرا")
                .font(.headline)

            if viewModel.events.isEmpty {
                Text("هنوز عملیاتی اجرا نشده است.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(color(for: event.level))
                            .frame(width: 8, height: 8)
                            .padding(.top, 7)
                        Text(event.message)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .textSelection(.enabled)
                }
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func textField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func secureField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            SecureField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func color(for level: BootstrapEventLevel) -> Color {
        switch level {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

#Preview {
    ContentView()
}
